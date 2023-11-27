set -e

source ./prepare_aws_cluster.sh

export CPU_COUNT=100
export MEMORY_GIB=400
export CLUSTER_NAME="argo-load"


echo "Creating cluster..."
# Create cluster
eksctl create cluster -f - << EOF
---
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: ${CLUSTER_NAME}
  region: ${AWS_DEFAULT_REGION}
  version: "${KUBERNETES_VERSION}"
  tags:
    KubernetesCluster: ${CLUSTER_NAME}
    karpenter.sh/discovery: ${CLUSTER_NAME}
fargateProfiles:
  - name: karpenter
    selectors:
    - namespace: karpenter
iam:
  withOIDC: true

availabilityZones:
- us-east-1a
- us-east-1b
EOF

echo "Exporting cluster endpoint..."
export CLUSTER_ENDPOINT="$(aws eks describe-cluster --name ${CLUSTER_NAME} --query "cluster.endpoint" --output text)"

# Create supporting infra
TEMPOUT=$(mktemp)

echo "Fetching carpenter..."
curl -fsSL https://karpenter.sh/"${KARPENTER_VERSION}"/getting-started/getting-started-with-eksctl/cloudformation.yaml  > $TEMPOUT \
&& aws cloudformation deploy \
  --stack-name "Karpenter-${CLUSTER_NAME}" \
  --template-file "${TEMPOUT}" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides "ClusterName=${CLUSTER_NAME}"

echo "Creating iamidentitymapping..."
# Grant permissions
eksctl create iamidentitymapping \
  --username system:node:{{EC2PrivateDNSName}} \
  --cluster "${CLUSTER_NAME}" \
  --arn "arn:aws:iam::${AWS_ACCOUNT_ID}:role/KarpenterNodeRole-${CLUSTER_NAME}" \
  --group system:bootstrappers \
  --group system:nodes
echo "Creating iamserviceaccount..."
eksctl create iamserviceaccount \
  --cluster "${CLUSTER_NAME}" --name karpenter --namespace karpenter \
  --role-name "${CLUSTER_NAME}-karpenter" \
  --attach-policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/KarpenterControllerPolicy-${CLUSTER_NAME}" \
  --role-only \
  --approve

export KARPENTER_IAM_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${CLUSTER_NAME}-karpenter"

echo "Creating create-service-linked-role..."
aws iam create-service-linked-role --aws-service-name spot.amazonaws.com || true

echo "Updating kubeconfig..."
# Connect to cluster
aws eks update-kubeconfig --alias ${CLUSTER_NAME} --name ${CLUSTER_NAME} --region ${AWS_DEFAULT_REGION} --profile ${AWS_PROFILE}

echo "Installing Karpenter..."
# Install Karpenter
docker logout public.ecr.aws
helm upgrade --install \
    karpenter oci://public.ecr.aws/karpenter/karpenter \
    --version ${KARPENTER_VERSION} \
    --namespace karpenter \
    --create-namespace \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=${KARPENTER_IAM_ROLE_ARN} \
  --set settings.aws.clusterName=${CLUSTER_NAME} \
  --set settings.aws.clusterEndpoint=${CLUSTER_ENDPOINT} \
  --set settings.aws.defaultInstanceProfile=KarpenterNodeInstanceProfile-${CLUSTER_NAME} \
  --set controller.resources.limits.memory=2Gi \
  --set settings.aws.interruptionQueueName=${CLUSTER_NAME} \
  --wait

echo "Creating default provisioner..."
# Create default Provisioner
cat <<EOF | kubectl apply -f -
apiVersion: karpenter.sh/v1alpha5
kind: Provisioner
metadata:
  name: default
spec:
  limits:
    resources:
      cpu: "${CPU_COUNT}"
      memory: ${MEMORY_GIB}Gi
  consolidation:
    enabled: true
  ttlSecondsUntilExpired: 86400
  requirements:
  - key: kubernetes.io/arch
    operator: In
    values:
    - amd64
  - key: karpenter.sh/capacity-type
    operator: In
    values:
    #- on-demand
    - spot
  - key: karpenter.k8s.aws/instance-cpu
    operator: Gt
    values:
    - "3"
  - key: karpenter.k8s.aws/instance-memory
    operator: Gt
    values:
    - "6000"
  - key: karpenter.k8s.aws/instance-family
    operator: NotIn
    values:
    - c1
    - cc1
    - cc2
    - cg1
    - cg2
    - cr1
    - g1
    - g2
    - hi1
    - hs1
    - m1
    - m2
    - m3
    - t1
  providerRef:
    name: al2
---
apiVersion: karpenter.k8s.aws/v1alpha1
kind: AWSNodeTemplate
metadata:
  name: al2
spec:
  amiFamily: AL2
  tags:
    KubernetesCluster: ${CLUSTER_NAME}
  securityGroupSelector:
    karpenter.sh/discovery: ${CLUSTER_NAME}
  subnetSelector:
    karpenter.sh/discovery: ${CLUSTER_NAME}
EOF

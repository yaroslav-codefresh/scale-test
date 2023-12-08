set -e

source ./prepare_aws_cluster.sh

aws eks update-kubeconfig --alias ${CLUSTER_NAME} --name ${CLUSTER_NAME} --region ${AWS_DEFAULT_REGION} --profile ${AWS_PROFILE}

# Delete Karpenter-managed nodes
kubectl --context "${CLUSTER_NAME}" delete $(kubectl --context "${CLUSTER_NAME}" get provisioners -o name) | true

# Delete cluster and supporting AWS resources
aws cloudformation delete-stack --stack-name Karpenter-${CLUSTER_NAME} --region ${AWS_DEFAULT_REGION} --profile ${AWS_PROFILE}
eksctl delete cluster --name ${CLUSTER_NAME} --region ${AWS_DEFAULT_REGION} --profile ${AWS_PROFILE}

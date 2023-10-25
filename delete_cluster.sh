#set -e

source ./prepare_aws_cluster.sh

# Delete Karpenter-managed nodes
kubectl delete $(kubectl get provisioners -o name)

# Delete cluster and supporting AWS resources
aws cloudformation delete-stack --stack-name Karpenter-${CLUSTER_NAME} --region ${AWS_DEFAULT_REGION} --profile ${AWS_PROFILE}
eksctl delete cluster ${CLUSTER_NAME} --region ${AWS_DEFAULT_REGION} --profile ${AWS_PROFILE}

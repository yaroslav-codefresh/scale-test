export AWS_PROFILE="cd-team"
aws sso login --profile ${AWS_PROFILE}

export AWS_DEFAULT_REGION="us-east-1"
export AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

export KUBERNETES_VERSION=1.27
export KARPENTER_VERSION=v0.28.0
#export CLUSTER_NAME="argo-load"

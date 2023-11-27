
export HELM_REPO="${PROD_HELM_REPO}"

export VALUES_FILE="sandbox-1-values"
export CODEFRESH_TOKEN="$(codefresh_token sandbox-1)"
export RUNTIME_NAME='yarik-runtime'
export NAMESPACE="${RUNTIME_NAME}"

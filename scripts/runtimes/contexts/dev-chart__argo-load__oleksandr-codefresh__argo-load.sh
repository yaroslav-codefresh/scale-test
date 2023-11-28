
using_dev_chart "0.3.4-CR-21441-chart-68ea7ee"

export RUNTIME_NAME='argo-load'
export VALUES_FILE="${RUNTIME_NAME}"
export CODEFRESH_TOKEN="$(codefresh_token oleksandr-codefresh)"
export NAMESPACE="${RUNTIME_NAME}"
export KUBE_CONTEXT="${RUNTIME_NAME}"
export RELEASE_NAME="codefresh"

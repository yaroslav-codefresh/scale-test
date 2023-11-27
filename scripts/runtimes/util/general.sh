function validate_required_env() {
    if [ -z "$KUBE_CONTEXT" ]; then
        echo "KUBE_CONTEXT env is required"
        exit 1
    fi

    if [ -z "$NAMESPACE" ]; then
        echo "NAMESPACE env is required"
        exit 1
    fi

    if [ -z "$VALUES_FILE" ]; then
        echo "VALUES_FILE env is required"
        exit 1
    fi

    if [ -z "$CODEFRESH_TOKEN" ]; then
        echo "CODEFRESH_TOKEN env is required"
        exit 1
    fi

    if [ -z "$RUNTIME_NAME" ]; then
        echo "RUNTIME_NAME env is required"
        exit 1
    fi

    if [ -z "$HELM_REPO" ]; then
        echo "HELM_REPO env is required"
        exit 1
    fi

    if [ -z "${CHART_NAME}" ]; then
        echo "CHART_NAME env is required"
        exit 1
    fi

    if [ -z "${RELEASE_NAME}" ]; then
        echo "RELEASE_NAME env is required"
        exit 1
    fi
}

function using_context() {
  echo "Using context: $1"
  source "${CONTEXTS_PATH}/$1"
}

function import() {
    echo "Importing: $1"
    source "${ROOT_DIR}/$1"
}

function execute() {
    echo "Executing: $1.sh"
    source "${ROOT_DIR}/commands/$1.sh"
}

function codefresh_token() {
    yq -r .contexts."$1".token ~/.cfconfig
}

function using_dev_chart() {
    export CHART_NAME="${DEV_CHART_NAME}"
    export HELM_REPO="${DEV_HELM_REPO}"
    export ADDITIONAL_FLAGS="--devel --version $1"
    export CHART_VERSION="$1"
}

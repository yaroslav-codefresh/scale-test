export CHART_NAME="cf-gitops-runtime/gitops-runtime"
export RELEASE_NAME="cf-gitops-runtime"
export KUBE_CONTEXT="k3d-local-runtime"

export DEV_HELM_REPO="https://chartmuseum-dev.codefresh.io/gitops-runtime"
export DEV_CHART_NAME="oci://quay.io/codefresh/dev/gitops-runtime"
export PROD_HELM_REPO="https://chartmuseum.codefresh.io/gitops-runtime"

export CONTEXTS_PATH="${ROOT_DIR}/contexts"
export ADDITIONAL_FLAGS=""

#!/bin/bash

set -o pipefail
set -e

account="_$1"
ns="_$2"
currentContext=$(kubectl config current-context)

if [ "$account" == "_" ]; then
    echo "missing account"
    exit 1
fi

if [ "$account" == "_stop" ]; then
    echo "killing virtual-cluster port-forward"
    lsof -i :7443 | awk '{if (NR==2) print $2}' | xargs kill || true
    echo "killing argo-cd port-forward"
    lsof -i :8080 | awk '{if (NR==2) print $2}' | xargs kill || true
    exit 0
fi

getRuntimeParameters() {
    echo "getting runtime parameters..."
    runtimeSecretName=$(kubectl get secret -n$namespace | grep codefresh-token | awk '{print $1}')
    runtimeToken=$(kubectl get secret -n$namespace $runtimeSecretName -o jsonpath="{.data.token}" | base64 -d)
    runtimeIv=$(kubectl get secret -n$namespace $runtimeSecretName -o jsonpath="{.data.encryptionIV}" | base64 -d)

    argocdInitialAdminSecretName=$(kubectl get secret -n$namespace | grep argocd-initial-admin-secret | awk '{print $1}')
    argocdInitialAdminPassword=$(kubectl get secret -n$namespace $argocdInitialAdminSecretName -o jsonpath="{.data.password}" | base64 -d)
    argocdServerPodName=$(kubectl get pod -n$namespace | grep argocd-server | awk '{print $1}')
}

# hybrid

connectHybrid() {
    echo "using context: $currentContext"
    echo "using namespace: $ns"

    namespace="$ns"

    getRuntimeParameters

    echo "==="
    echo "app-proxy config should have:"
    echo "{"
    echo "  \"NAMESPACE\": \"$ns\","
    echo "  \"RUNTIME_TOKEN\": \"$runtimeToken\","
    echo "  \"RUNTIME_STORE_IV\": \"$runtimeIv\","
    echo "  \"ARGO_CD_PASSWORD\": \"$argocdInitialAdminPassword\""
    echo "}"
    echo "==="

    echo "running port-forwards..."
    kubectl port-forward --context $currentContext -n $namespace pod/$argocdServerPodName 8080:8080 1>/dev/null &
    sleep 3

    echo "ready!"
}

if [ "$account" == "_ns" ]; then
    if [ "$ns" == "_" ]; then
        echo "missing namespace"
        exit 1
    fi

    ns=$2

    connectHybrid
    exit 0
fi

# hosted

account=$1

echo "using context: $currentContext"
echo "using account name: $account"

echo ""
runtimeName=$(kubectl get managedruntimes -l codefresh.io/account-name=$account | grep $account | awk '{print $1}')
echo "found runtime: $runtimeName"

namespace=$(kubectl get namespaces | grep $runtimeName | awk '{print $1}')
echo "namespace: $namespace"

secretName="vc-$namespace"
config=$(kubectl get secret -n$namespace -o jsonpath="{.data.config}" $secretName | base64 -d)

getRuntimeParameters

echo "merging to original kubeconfig"
echo "rewriting host to 'https://$namespace.$namespace.svc' -> 'http://localhost:7443'"
config=$(echo "$config" | sed s/$namespace\.$namespace\.svc/localhost:7443/)
echo "$config" > /tmp/kubeconfig
cp ~/.kube/config ~/.kube/config.bak
KUBECONFIG=/tmp/kubeconfig:~/.kube/config kubectl config view --flatten > /tmp/config
mv /tmp/config ~/.kube/config

echo "switching current context"
kubectl config use-context Default

echo "==="
echo "app-proxy config should have:"
echo "{"
echo "  \"NAMESPACE\": \"codefresh-hosted\","
echo "  \"RUNTIME_TOKEN\": \"$runtimeToken\","
echo "  \"RUNTIME_STORE_IV\": \"$runtimeIv\","
echo "  \"ARGO_CD_PASSWORD\": \"$argocdInitialAdminPassword\""
echo "}"
echo "==="

echo "running port-forwards..."
kubectl port-forward --context $currentContext -n $namespace svc/$namespace 7443:443 1>/dev/null &
kubectl port-forward --context $currentContext -n $namespace pod/$argocdServerPodName 8080:8080 1>/dev/null &
sleep 3

echo "ready!"

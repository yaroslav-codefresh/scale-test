#!/bin/bash

# Check if both group and claim_name are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <GROUP> <CLAIM_NAME>"
    exit 1
fi

GROUP=$1
CLAIM_NAME=$2
OUTPUT_KUBECONFIG_FILE=$CLAIM_NAME-kubeconfig.yaml

cat << EOF > $OUTPUT_KUBECONFIG_FILE
apiVersion: v1
kind: Config
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: https://$CLAIM_NAME-vcluster.$GROUP-sandbox.cf-infra.com
  name: $CLAIM_NAME-vcluster
contexts:
- context:
    cluster: $CLAIM_NAME-vcluster
    user: $CLAIM_NAME-vcluster-admin
  name: kubernetes-admin@$CLAIM_NAME
preferences: {}
users:
- name: $CLAIM_NAME-vcluster-admin
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      args:
      - oidc-login
      - get-token
      - --oidc-issuer-url=https://dexidp.shared-services.cf-infra.com
      - --oidc-client-id=vcluster-login
      - --oidc-client-secret=codefreshsecret123
      - --oidc-extra-scope="email"
      - --oidc-extra-scope="groups"
      - --listen-address=127.0.0.1:18000
      command: kubectl
      interactiveMode: IfAvailable
      provideClusterInfo: false
EOF

# Backup existing kubeconfig
cp ~/.kube/config ~/.kube/config-back

# Merge kubeconfigs
export KUBECONFIG=~/.kube/config:$(pwd)/$OUTPUT_KUBECONFIG_FILE
kubectl config view --flatten > merged.conf
mv merged.conf ~/.kube/config
rm $OUTPUT_KUBECONFIG_FILE
chmod 600 ~/.kube/config
unset KUBECONFIG

echo "Kubeconfig created and merged successfully."

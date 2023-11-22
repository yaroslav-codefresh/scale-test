helm upgrade --install cf-gitops-runtime \
  --create-namespace \
  --namespace yarik \
  --set global.codefresh.accountId=6422abe703c720761a07f3e0 \
  --set global.codefresh.userToken.token=6556389122bf66c162069708.1e667a8163dfa100d418c87b566335e2 \
  --set global.runtime.name=yarik \
  --set global.codefresh.url=https://sandbox-1.codefresh.io \
  --set argo-cd.configs.cm."application.resourceTrackingMethod"=label \
  --set tunnel-client.tunnelServer.host=register-tunnels.non-prod-ue1-sandbox-1.cf-op.com \
  --set tunnel-client.tunnelServer.subdomainHost=tunnels.non-prod-ue1-sandbox-1.cf-op.com \
  --kube-context k3d-local-runtime \
  cf-gitops-runtime/gitops-runtime

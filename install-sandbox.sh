helm upgrade --install cf-gitops-runtime \
  --create-namespace \
  --debug \
  --namespace yarik \
  --values /Users/siloenix/work/codefresh/scale-test/sandbox-values.yaml \
  --kube-context k3d-local-runtime \
  cf-gitops-runtime/gitops-runtime | tee debug.log

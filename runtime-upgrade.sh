#helm repo update
RELEASE_NAME=$(helm ls -n argo-load -q)
#helm upgrade ${RELEASE_NAME} -n argo-load \
#  --dry-run --debug \
#  --set argo-events.global.image.tag=v1.8.0-cap-CR-19893 \
#  cf-gitops-runtime/gitops-runtime

helm upgrade ${RELEASE_NAME} \
  --namespace argo-load \
  --debug --wait \
  --set global.codefresh.accountId=61289cb0432d871402610bad \
  --set global.codefresh.userToken.token=65452d9eb02653207f6c7131.dc16e6f9c9903a05b7852ade58077b5a \
  --set argo-events.global.image.tag=v1.8.0-cap-CR-19893 \
  --set global.runtime.name=argo-load \
  cf-gitops-runtime/gitops-runtime

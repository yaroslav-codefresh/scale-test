NAMESPACE=argocd

kubectl -n "${NAMESPACE}" get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

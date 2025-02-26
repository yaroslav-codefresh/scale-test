helm repo add argo-cd https://argoproj.github.io/argo-helm
helm pull argo-cd/argo-cd
helm upgrade --install argocd ./argo-cd-7.8.5.tgz \
    -f /Users/siloenix/work/codefresh/scale-test/values/byoa-argocd.yaml \
    --namespace argocd \
    --debug \
    --wait


# argocd pass -- 3v5uHKC2gr3bS6dd

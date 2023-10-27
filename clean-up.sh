NS=cf-runtime
product=test-app
service=service
context=k3d-scale-test

for i in {1..1} ; do
    for j in {1..5} ; do
        kubectl --context $context -n $NS patch appset "$product-$service-$i-prod-appset-$j" -p '{"metadata":{"finalizers":null}}' --type=merge
    done
done

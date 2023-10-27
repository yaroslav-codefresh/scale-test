NS=cf-runtime
product=test-app


for i in {3..10} ; do
    for j in {1..3} ; do
        kubectl -n $NS patch appset "$product-service-$i-prod-appset-$j" -p '{"metadata":{"finalizers":null}}' --type=merge
    done
done

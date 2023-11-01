NS=argo-load
product=product-a
service=service
context=arn:aws:eks:us-east-1:882458141806:cluster/argo-load

for i in {3..3} ; do
    for j in {1..5} ; do
        kubectl --context $context -n $NS patch appset "prod-$product-$service-$i-appset-$j" -p '{"metadata":{"finalizers":null}}' --type=merge
    done
done

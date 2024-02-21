docker login quay.io -u codefresh+bot # and enter pass from 1pass

helm dependency update
helm package .
helm push --registry-config ~/.docker/config.json $PACKAGE_NAME oci://quay.io/codefresh/dev

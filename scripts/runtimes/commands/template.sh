helm template "${RELEASE_NAME}" \
  --create-namespace \
  --wait \
  --debug ${ADDITIONAL_FLAGS} \
  --namespace "${NAMESPACE}" \
  --values "${ROOT_DIR}"/../../values/"${VALUES_FILE}".yaml \
  --set global.codefresh.userToken.token="${CODEFRESH_TOKEN}" \
  --set global.runtime.name="${RUNTIME_NAME}" \
  --kube-context "${KUBE_CONTEXT}" \
  "${CHART_NAME}" | tee "${ROOT_DIR}/logs/${RUNTIME_NAME}.yaml"

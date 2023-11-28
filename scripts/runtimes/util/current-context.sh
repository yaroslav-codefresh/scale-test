# for testing new reporter
#using_context "dev-chart__local-runtime__yaroslav-codefresh__new-reporter.sh"

# for sandbox-1
#using_context "prod-chart__local-runtime__codefresh-inc__sandbox-1.sh"

# for testing agro-load
using_context "dev-chart__argo-load__oleksandr-codefresh__argo-load.sh"

validate_required_env

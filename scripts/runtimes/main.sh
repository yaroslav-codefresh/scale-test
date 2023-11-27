set -e

export ROOT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source "${ROOT_DIR}/util/general.sh"
import "util/global-vars.sh"
import "util/current-context.sh"

mkdir -p "${ROOT_DIR}/logs"

echo
echo

execute "$1" | tee "${ROOT_DIR}/logs/${RUNTIME_NAME}__$1.log"

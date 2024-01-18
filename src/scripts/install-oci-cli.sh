#!/bin/bash

set -eox pipefail

# temporary filename for the script
INSTALL_SCRIPT_PATH="mktemp"

curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh --output "${INSTALL_SCRIPT_PATH}"

# install python3.11 if the python3 version is 3.12 or newer
# https://github.com/oracle/oci-cli/issues/742
if [[ $(python3 -c "import sys; too_new = sys.version_info >= (3, 12, 0); print(1 if too_new else 0)") -eq 1 ]]; then
    sudo dnf install -y python3.11
    sudo dnf clean all
    sed -i 's/for try_python_exe in /&python3.11 /' "${INSTALL_SCRIPT_PATH}"
fi


bash "${INSTALL_SCRIPT_PATH}" --accept-all-defaults

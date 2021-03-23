#!/bin/bash

#
# This script is the default entrypoint of the `rpmrepo-snapshot` container. It
# clones the specified branch+commit of the rpmrepo repository, selects the
# specified target configuration, and creates a new RPMrepo snapshot.
#

set -eox pipefail

#
# We require 3 positional command-line arguments. The first two arguments are
# the rpmrepo repository branch+commit to use. The third argument is the name
# of the target configuration in the rpmrepo repository.
#
# The special key `auto` as target configuration makes the script automatically
# select a target as part of an array-job (indexed by AWS via the
# `AWS_BATCH_JOB_ARRAY_INDEX` environment variable).
#

if (( $# != 3 )) ; then
        echo >&2 "ERROR: exactly 3 arguments required: <branch> <commit> <target>"
        exit 1
fi

RPMREPO_BRANCH="$1"
RPMREPO_COMMIT="$2"
RPMREPO_TARGET="$3"

if [[ $RPMREPO_TARGET = "auto" ]] ; then
        if [[ -z $AWS_BATCH_JOB_ARRAY_INDEX ]] ; then
                echo >&2 "ERROR: automatic target selection specified, but not running as part of an array job"
                exit 1
        fi
fi

#
# Clone the rpmrepo repository. We do this to get access to the target
# configurations in `./repo/`. The targets are stored as JSON configuration.
#

echo "Cloning RPMrepo: ${RPMREPO_BRANCH}#${RPMREPO_COMMIT}"

git clone \
        --branch "${RPMREPO_BRANCH}" \
        "https://github.com/osbuild/rpmrepo.git" \
        "rpmrepo"
cd "./rpmrepo"
git reset --hard "${RPMREPO_COMMIT}"

#
# Select the specified target. In case an explicit target is specified, just
# verify the target configuration exists. If automatic selection is required,
# list all targets, sort them, and then index them by the requested job index.
#

echo "Selecting target: ${RPMREPO_TARGET}"

TARGET_PATH=""
if [[ $RPMREPO_TARGET = "auto" ]] ; then
        TARGET_LIST=($(ls ./repo | sort))
        if (( ${AWS_BATCH_JOB_ARRAY_INDEX} >= ${#TARGET_LIST[@]} )) ; then
                echo >&2 "WARNING: job index exceeds target list size, nothing to do"
                exit 0
        fi
        TARGET_PATH="./repo/${TARGET_LIST[${AWS_BATCH_JOB_ARRAY_INDEX}]}"
else
        if [[ ! -f "./repo/${RPMREPO_TARGET}.json" ]] ; then
                echo >&2 "ERROR: target not found: './repo/${RPMREPO_TARGET}.json'"
                exit 1
        fi
        TARGET_PATH="./repo/${RPMREPO_TARGET}.json"
fi

echo "Selected target: ${TARGET_PATH}"

TARGET_JSON=$(cat "${TARGET_PATH}")
TARGET_BASE_URL=$(jq -r  '.["base-url"]' <<< "${TARGET_JSON}" )
TARGET_PLATFORM_ID=$(jq -r  '.["platform-id"]' <<< "${TARGET_JSON}" )
TARGET_SNAPSHOT_ID=$(jq -r  '.["snapshot-id"]' <<< "${TARGET_JSON}" )
TARGET_STORAGE=$(jq -r  '.["storage"]' <<< "${TARGET_JSON}" )

TARGET_SNAPSHOT_SUFFIX="-$(date -u '+%Y%m%d%H%M')"

#
# Pull the selected target repository, index it, and then upload it to our
# persistent infrastructure.
#

mkdir -p "/var/lib/rpmrepo/cache"

python3 -m "src.ctl" \
        --cache "/var/lib/rpmrepo/cache" \
        --local "batch" \
        pull \
                --base-url "${TARGET_BASE_URL}" \
                --platform-id "${TARGET_PLATFORM_ID}"

python3 -m "src.ctl" \
        --cache "/var/lib/rpmrepo/cache" \
        --local "batch" \
        index

python3 -m "src.ctl" \
        --cache "/var/lib/rpmrepo/cache" \
        --local "batch" \
        push \
                --to \
                        "data" \
                        "${TARGET_STORAGE}" \
                        "${TARGET_PLATFORM_ID}" \
                --to \
                        "snapshot" \
                        "${TARGET_SNAPSHOT_ID}" \
                        "${TARGET_SNAPSHOT_SUFFIX}"

rm -rf "/var/lib/rpmrepo/cache"

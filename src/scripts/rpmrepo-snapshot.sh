#!/bin/bash

#
# This script is the default entrypoint of the `rpmrepo-snapshot` container. It
# clones the specified branch+commit of the rpmrepo repository, selects the
# specified target configuration, and creates a new RPMrepo snapshot.
#

set -eox pipefail

#
# We require 4 positional command-line arguments. The first two arguments are
# the rpmrepo repository branch+commit to use. The third argument is the name
# of the target configuration in the rpmrepo repository. The fourth argument
# specifies the snapshot suffix to use.
#
# The special key `auto` as target configuration makes the script automatically
# select a target as part of an array-job (indexed by AWS via the
# `AWS_BATCH_JOB_ARRAY_INDEX` environment variable).
#

if (( $# != 4 )) ; then
        echo >&2 "ERROR: exactly 4 arguments required: <branch> <commit> <target> <suffix>"
        exit 1
fi

RPMREPO_BRANCH="$1"
RPMREPO_COMMIT="$2"
RPMREPO_TARGET="$3"
RPMREPO_SUFFIX="$4"

if [[ \
        -z $RPMREPO_BRANCH || \
        -z $RPMREPO_COMMIT || \
        -z $RPMREPO_TARGET || \
        -z $RPMREPO_SUFFIX \
   ]] ; then
        echo >&2 "ERROR: empty parameters"
        exit 1
fi

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
TARGET_BASE_URL=$(jq -r  '.["base-url"] // empty' <<< "${TARGET_JSON}" )
TARGET_PLATFORM_ID=$(jq -r  '.["platform-id"] // empty' <<< "${TARGET_JSON}" )
TARGET_SINGLETON=$(jq -r  '.["singleton"] // empty' <<< "${TARGET_JSON}" )
TARGET_SNAPSHOT_ID=$(jq -r  '.["snapshot-id"] // empty' <<< "${TARGET_JSON}" )
TARGET_STORAGE=$(jq -r  '.["storage"] // empty' <<< "${TARGET_JSON}" )

if [[ \
        -z $TARGET_BASE_URL || \
        -z $TARGET_PLATFORM_ID || \
        -z $TARGET_SNAPSHOT_ID || \
        -z $TARGET_STORAGE \
   ]] ; then
        echo >&2 "ERROR: invalid target configuration"
        exit 1
fi

#
# Figure out what suffix to use for the snapshot. If the target has a fixed
# suffix, we always use that suffix (this prevents accidentally snapshotting
# singletons). Otherwise, we use the suffix as specified by the caller. If the
# caller specified the special value 'auto', a suffix is generated based on the
# current date and time.
#

if [[ ! -z $TARGET_SINGLETON ]] ; then
        TARGET_SNAPSHOT_SUFFIX="-${TARGET_SINGLETON}"
elif [[ $RPMREPO_SUFFIX == "auto" ]] ; then
        TARGET_SNAPSHOT_SUFFIX="-$(date -u '+%Y%m%d%H%M')"
else
        TARGET_SNAPSHOT_SUFFIX="-${RPMREPO_SUFFIX}"
fi

#
# Check for duplicates. Query the snapshot and if it exists bail out, as we
# do not want to override existing snapshots.
#

URL="https://rpmrepo-storage.s3.amazonaws.com/data/thread"
URL="${URL}/${TARGET_SNAPSHOT_ID}/${TARGET_SNAPSHOT_ID}${TARGET_SNAPSHOT_SUFFIX}"
R=$(curl -sw "%{http_code}" -o /dev/null -I "${URL}")

if [[ $R == 200 ]] ; then
        echo >&2 "WARNING: snapshot exists already, nothing to do"
        exit 0
elif [[ $R != 404 ]] ; then
        echo >&2 "ERROR: cannot query snapshot"
        exit 1
fi

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

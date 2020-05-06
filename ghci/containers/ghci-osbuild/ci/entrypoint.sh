#!/bin/bash

set -e

# Systemd required tmpfs on these paths, and we use `systemd-nspawn`, so we
# have to make sure this works properly.
mount -t tmpfs none /run
mount -t tmpfs none /tmp

# OSBuild still needs loop-control access, as well as access to the individual
# loop-devices. We could, in the future, just create loop-control in the
# container and create the loop-devices manually. However, that is not how the
# code currently works.
mount -t devtmpfs none /dev

# Upstream docker now has `--cgroupns private` which should have the same
# effect as this `unshare`. However, older docker versions lack this argument,
# hence we simply run through `unshare -C`.
exec unshare -C -- "$@"

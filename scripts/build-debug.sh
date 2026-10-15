#!/bin/sh
set -eu
PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
DEVECO_ROOT=${ZHIYU_DEVECO_ROOT:-/Applications/DevEco-Studio.app/Contents}
cd "$PROJECT_ROOT"
export DEVECO_SDK_HOME="$DEVECO_ROOT/sdk"
exec "$DEVECO_ROOT/tools/node/bin/node" "$DEVECO_ROOT/tools/hvigor/bin/hvigorw.js" \
  --mode module -p module=entry@default -p product=default -p buildMode=debug assembleHap --no-daemon

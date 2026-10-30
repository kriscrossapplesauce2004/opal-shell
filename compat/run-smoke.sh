#!/bin/sh
# Build the opal/src alias folder (opal/compat/gen) and run the shim smoke test offscreen.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
src="$here/../src"
gen="$here/gen"
mkdir -p "$gen"
rm -f "$gen"/*.qml "$gen/qmldir"
for f in "$src"/*.qml; do
  name=$(basename "$f")
  if [ "$name" = "Hub.qml" ]; then
    ln -sfn ../stubs/Hub.qml "$gen/Hub.qml"
  else
    ln -sfn "../../src/$name" "$gen/$name"
  fi
done
# Register only the two singletons the leaves read; a full copy of opal/src/qmldir loads every singleton.
cat > "$gen/qmldir" <<QMLDIR
singleton Theme 1.0 Theme.qml
singleton Hub 1.0 Hub.qml
QMLDIR
export QT_FORCE_STDERR_LOGGING=1
exec qml6 -platform offscreen -I "$here/fake" "$here/smoke.qml"

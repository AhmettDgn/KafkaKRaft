#!/usr/bin/env bash
# Mock Kubernetes operations; no real credentials, Secret or PVC is modified.
set -Eeuo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sandbox="$(mktemp -d)"
trap 'rm -rf -- "$sandbox"' EXIT
export CALLS="$sandbox/calls"
cat > "$sandbox/kubectl" <<'MOCK'
#!/usr/bin/env bash
set -eu
case "$1 $2" in
  'get secret') [[ "$SCENARIO" == existing ]];;
  'get pvc')
    if [[ "$SCENARIO" == denied ]]; then exit 1; fi
    if [[ "$SCENARIO" == old_pvc ]]; then echo 'persistentvolumeclaim/old-data'; fi
    ;;
  'create secret') echo created >> "$CALLS";;
  *) exit 99;;
esac
MOCK
chmod +x "$sandbox/kubectl"
export PATH="$sandbox:$PATH"
run() { bash "$root/scripts/lab/create-cluster-id.sh"; }
export SCENARIO=existing
run
[[ ! -e "$CALLS" ]]
export SCENARIO=new
run
[[ "$(wc -l < "$CALLS")" == 1 ]]
export SCENARIO=old_pvc
if run > "$sandbox/error" 2>&1; then echo 'FAIL: old PVC guard'; exit 1; fi
grep -q 'Refusing new cluster ID' "$sandbox/error"
export SCENARIO=denied
if run > "$sandbox/error" 2>&1; then echo 'FAIL: API error guard'; exit 1; fi
[[ "$(wc -l < "$CALLS")" == 1 ]]
echo 'PASS: existing ID preserved, fresh ID created, old PVC and API error refuse creation'

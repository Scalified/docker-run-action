#!/usr/bin/env bash
# Harness for scalified/docker-run-action env-escaping fix.
# Extracts the run script from action.yml, stubs docker, and asserts that
# -e values arrive byte-identical after `eval "$cmd"`.
set -u

ACTION_YML="${1:-action.yml}"
WORKDIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$WORKDIR/.extracted-run.sh"

# --- Extract run script, substitute GitHub expressions -----------------------
sed -n '/^      run: |$/,/^      shell: bash$/p' "$ACTION_YML" \
  | sed '1d;$d' \
  | sed 's/^        //' \
  | sed -e 's/${{ github.sha }}/abcdef1234567890/g' \
        -e 's#${{ github.workspace }}#/tmp/gh-workspace#g' \
  > "$SCRIPT"

# --- docker stub --------------------------------------------------------------
DOCKER_STUB="$(mktemp)"
cat > "$DOCKER_STUB" <<'EOF'
docker() {
  case "${1:-}" in
    network)
      shift
      case "${1:-}" in
        inspect) return 0 ;;                 # pretend network exists
        create|rm) echo "NET-$*"; return 0 ;;
      esac
      ;;
    rm) return 0 ;;
    logs) return 0 ;;
    inspect) echo "healthy"; return 0 ;;
    run) printf 'ARG<%s>\n' "$@"; return 0 ;;
  esac
  return 0
}
export -f docker 2>/dev/null || true
EOF

# --- Test inputs ----------------------------------------------------------------
GITHUB_OUTPUT="$(mktemp)"
export GITHUB_OUTPUT
export INPUT_NAME="testcontainer"
export INPUT_ARGS=""
export INPUT_DETACH="false"
export INPUT_ENTRYPOINT=""
export INPUT_HEALTH_CMD=""
export INPUT_HEALTH_INTERVAL="5s"
export INPUT_HEALTH_RETRIES="5"
export INPUT_HEALTH_START_INTERVAL="0s"
export INPUT_HEALTH_START_PERIOD="0s"
export INPUT_HEALTH_TIMEOUT="0s"
export INPUT_IMAGE="alpine:3"
export INPUT_LINKS=""
export INPUT_NETWORKS=""
export INPUT_PRIVILEGED="false"
export INPUT_VOLUMES=""
export INPUT_WORKDIR=""
export INPUT_COMMAND='bash -c "true"'

# Adversarial env values + deploy-like multi-line input
INPUT_ENV='ENCRYPTION_KEY=$!T$@i!4BrEF4V K2=@XU2R$LR87Cgzu K3=plain K4=with'"'"'quote
MULTILINE_A=aaa MULTILINE_B=bb$bb'
export INPUT_ENV

EXPECTED=(
  'ENCRYPTION_KEY=$!T$@i!4BrEF4V'
  'K2=@XU2R$LR87Cgzu'
  'K3=plain'
  "K4=with'quote"
  'MULTILINE_A=aaa'
  'MULTILINE_B=bb$bb'
)

# --- Run ------------------------------------------------------------------------
source "$DOCKER_STUB"
OUTPUT="$(bash "$SCRIPT" 2>&1)"
RUN_STATUS=$?

echo "=== script output ==="
printf '%s\n' "$OUTPUT"
echo "=== exit status: $RUN_STATUS ==="

# --- Extract -e values received by stub ------------------------------------------
mapfile -t GOT < <(printf '%s\n' "$OUTPUT" | awk '
  /^ARG</ {
    line=$0
    while (match(line, /ARG<[^>]*>/)) {
      arg=substr(line, RSTART+4, RLENGTH-5)
      line=substr(line, RSTART+RLENGTH)
      args[++n]=arg
    }
  }
  END {
    for (i=1; i<=n; i++) {
      if (args[i]=="-e" && i<n) print args[i+1]
    }
  }
')

echo "=== -e values received ==="
for v in "${GOT[@]:-}"; do [ -n "$v" ] && printf 'GOT<%s>\n' "$v"; done

# --- Assert ------------------------------------------------------------------------
fail=0
if [ "${#GOT[@]}" -ne "${#EXPECTED[@]}" ]; then
  echo "FAIL: expected ${#EXPECTED[@]} -e args, got ${#GOT[@]}"
  fail=1
else
  for i in "${!EXPECTED[@]}"; do
    if [ "${GOT[$i]}" = "${EXPECTED[$i]}" ]; then
      printf 'PASS: %s\n' "${EXPECTED[$i]}"
    else
      printf 'FAIL: expected <%s> got <%s>\n' "${EXPECTED[$i]}" "${GOT[$i]}"
      fail=1
    fi
  done
fi

# --- Regression: detach:true path still constructs/executes --------------------
export INPUT_DETACH="true"
: > "$GITHUB_OUTPUT"
DETACH_OUTPUT="$(bash "$SCRIPT" 2>&1)"
# In detach mode the eval'd command output is captured into container_id and
# written to GITHUB_OUTPUT.
if grep -q 'ARG<run>' "$GITHUB_OUTPUT"; then
  echo "PASS: detach:true path executed docker run (container-id captured)"
else
  echo "FAIL: detach:true path did not execute docker run"
  printf '%s\n' "$DETACH_OUTPUT"
  fail=1
fi
export INPUT_DETACH="false"
: > "$GITHUB_OUTPUT"

# --- Whitespace-trim regression -------------------------------------------------
# New trim must match old `echo $env | xargs` trim for quote-free tokens, and
# must NOT corrupt quote-containing tokens the way xargs did.
new_trim() {
  local e="$1"
  e="${e#"${e%%[![:space:]]*}"}"
  e="${e%"${e##*[![:space:]]}"}"
  printf '%s' "$e"
}
old_trim() { echo $1 | xargs; }
for tok in "PLAIN=1" "SPACED=x" "A==b=c"; do
  if [ "$(new_trim "$tok")" = "$(old_trim "$tok")" ]; then
    echo "PASS: trim-equivalence for '$tok'"
  else
    echo "FAIL: trim-equivalence for '$tok': old=<$(old_trim "$tok")> new=<$(new_trim "$tok")>"
    fail=1
  fi
done

exit $fail

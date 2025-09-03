#!/bin/bash

# Cursor-Toolhive Bridge (robust)
# - Acquires/renews Toolhive sessions
# - Sends JSON-RPC requests to messages endpoint
# - Opens a short-lived SSE on messages to capture the matching response by id
# - Prints the matched JSON to stdout for Cursor

# Avoid exiting on curl timeouts (exit 28). Keep undefined var safety and pipefail where supported.
set -u
set -o pipefail 2>/dev/null || true

# Allow override via env; default to local port-forward
PROXY_URL=${PROXY_URL:-"http://localhost:8081"}

SESSION_ID=""
TEMP_DIR="/tmp/cursor-mcp-$$"
mkdir -p "$TEMP_DIR"
 # Per-request model: no persistent reader state

cleanup() {
  rm -rf "$TEMP_DIR" 2>/dev/null || true
  # Kill any background curl started by this process
  jobs -p >/dev/null 2>&1 && kill $(jobs -p) 2>/dev/null || true
}
trap cleanup EXIT INT TERM

log() { echo "$*" >&2; }

wait_for_proxy() {
  log "Waiting for Toolhive proxy at $PROXY_URL..."
  # Try up to 20 times (~10s). Consider proxy ready if SSE yields any line.
  # Use -N for unbuffered SSE; allow timeout without failing.
  for _ in $(seq 1 20); do
    # Capture output even if curl times out (exit 28). We only care if any line arrived.
    out="$(curl -s -N --connect-timeout 1 -m 5 "$PROXY_URL/sse" 2>/dev/null | head -n 1 || true)"
    if [ -n "$out" ]; then
      return 0
    fi
    sleep 0.5
  done
  return 1
}

extract_session_from_sse() {
  # Reads from SSE and prints one session id; exits nonzero on failure
  # We only print lines that start with data: then strip prefix; then grep for session_id endpoint
  curl -s -N -m 5 "$PROXY_URL/sse" \
    | sed -n 's/^data: //p' \
    | sed -n 's#^.*/messages?session_id=##p' \
    | head -n 1
}

get_session_id() {
  log "Getting session ID..."
  local sid=""
  # Try a few times since sessions can rotate fast
  for _ in $(seq 1 3); do
    sid=$(extract_session_from_sse || true)
    if [ -n "${sid:-}" ]; then
      SESSION_ID="$sid"
      log "Session acquired: $SESSION_ID"
      return 0
    fi
    sleep 0.5
  done
  log "Failed to acquire session"
  return 1
}

 # (No persistent reader in per-request model)

extract_id_from_request() {
  # Prints the id token exactly as it appears in JSON (number or quoted string)
  # Fallback to 1 if not found
  local req="$1"
  local id
  id=$(printf '%s' "$req" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*\("[^"]\+"\|[0-9]\+\).*/\1/p' | head -n 1)
  if [ -z "${id:-}" ]; then
    echo 1
  else
    echo "$id"
  fi
}

build_id_grep_pattern() {
  # Input is id token, either number (e.g., 1) or quoted string (e.g., "abc")
  # Output a grep-safe pattern that matches "id": <id>
  local idtoken="$1"
  # Escape quotes for grep
  if printf '%s' "$idtoken" | grep -q '^"'; then
    # quoted id
    printf '\\"id\\"[[:space:]]*:[[:space:]]*%s' "$idtoken"
  else
    # numeric id
    printf '\\"id\\"[[:space:]]*:[[:space:]]*%s\b' "$idtoken"
  fi
}

post_request() {
  local req="$1"
  curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "$req" \
    "$PROXY_URL/messages?session_id=$SESSION_ID" || true
}

 # (No RESP_LOG scan in per-request model)

send_request() {
  local json_request="$1"

  # Per-request session: always acquire a fresh session
  if ! get_session_id; then
    printf '%s\n' '{"jsonrpc":"2.0","error":{"code":-1,"message":"Failed to get session"},"id":null}'
    return
  fi

  local idtoken idpat
  idtoken=$(extract_id_from_request "$json_request")
  idpat=$(build_id_grep_pattern "$idtoken")
  # Start a dedicated SSE listener for this request/session and capture to temp file
  local req_tmp="$TEMP_DIR/req_$(date +%s%3N)_$idtoken.jsonl"
  (
    curl -s -N -H "Accept: text/event-stream" "$PROXY_URL/sse" \
      | sed -n 's/^data: //p' \
      > "$req_tmp"
  ) &
  local sse_pid=$!
  # small delay to attach
  sleep 0.1

  # Send the request
  local post_resp
  post_resp=$(post_request "$json_request")
  if printf '%s' "$post_resp" | grep -q "Could not find session"; then
    log "Session invalid; renewing (but keeping single-session model)..."
    if get_session_id; then
      # Restart this request's SSE listener with renewed session, then re-post
      kill $sse_pid 2>/dev/null || true
      (
        curl -s -N -H "Accept: text/event-stream" "$PROXY_URL/sse" \
          | sed -n 's/^data: //p' \
          > "$req_tmp"
      ) &
      sse_pid=$!
      sleep 0.1
      post_resp=$(post_request "$json_request")
    fi
  fi

  # Wait up to 15s for a line matching id pattern
  local waited=0
  local out=""
  while [ $waited -lt 150 ]; do
    if out=$(grep -m 1 -E "$idpat" "$req_tmp" 2>/dev/null); then
      [ -n "$out" ] && printf '%s\n' "$out"
      kill $sse_pid 2>/dev/null || true
      rm -f "$req_tmp"
      return
    fi
    sleep 0.1
    waited=$((waited+1))
  done
  kill $sse_pid 2>/dev/null || true
  rm -f "$req_tmp"
  printf '%s\n' '{"jsonrpc":"2.0","error":{"code":-32000,"message":"No response from server"},"id":null}'
}

log "Starting Cursor-Toolhive bridge against $PROXY_URL"
if ! wait_for_proxy; then
  log "Toolhive proxy not reachable"
  printf '%s\n' '{"jsonrpc":"2.0","error":{"code":-32001,"message":"Proxy not reachable"},"id":null}'
  exit 1
fi
log "Bridge ready; processing JSON-RPC on stdin"

# Per-request model: no upfront session or reader

while IFS= read -r line; do
  [ -z "${line:-}" ] && continue
  send_request "$line"
done


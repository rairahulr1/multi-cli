#!/usr/bin/env bash
# protocol-runtime.sh — Protocol lifecycle management for multi-cli
# Sourced by multi-cli. Provides functions for stdio, http, acp, and websocket protocols.

# Find a free TCP port on the system
protocol_find_free_port() {
  local preferred="${1:-}"
  local range_start="${2:-}"
  local range_end="${3:-}"

  if [ -n "$preferred" ] && [ -z "$range_start" ]; then
    # Try preferred port first
    if ! ss -tln 2>/dev/null | grep -q ":${preferred} " && \
       ! netstat -tln 2>/dev/null | grep -q ":${preferred} "; then
      echo "$preferred"
      return 0
    fi
  fi

  if [ -n "$range_start" ] && [ -n "$range_end" ]; then
    local port
    for port in $(seq "$range_start" "$range_end"); do
      if ! ss -tln 2>/dev/null | grep -q ":${port} " && \
         ! netstat -tln 2>/dev/null | grep -q ":${port} "; then
        echo "$port"
        return 0
      fi
    done
  fi

  # Fallback: let the OS assign a port
  local tmp
  tmp=$(mktemp)
  exec 3<>"/dev/tcp/127.0.0.1/0" 2>/dev/null && {
    # This doesn't work in bash for getting the port, use python as fallback
    exec 3>&-
  }
  rm -f "$tmp"

  # Use python to find a free port
  if command -v python3 &>/dev/null; then
    python3 -c "import socket; s=socket.socket(); s.bind(('127.0.0.1',0)); print(s.getsockname()[1]); s.close()"
    return 0
  fi

  echo "0"
  return 1
}

# Wait for an HTTP endpoint to become healthy
# Usage: protocol_wait_for_http <url> <expected_status> <timeout_ms> <interval_ms>
protocol_wait_for_http() {
  local url="$1"
  local expected_status="${2:-200}"
  local timeout_ms="${3:-10000}"
  local interval_ms="${4:-200}"
  local elapsed=0

  while [ "$elapsed" -lt "$timeout_ms" ]; do
    local status
    status=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
    if [ "$status" = "$expected_status" ]; then
      return 0
    fi
    sleep "$(awk "BEGIN {print $interval_ms / 1000}")"
    elapsed=$((elapsed + interval_ms))
  done

  return 1
}

# Wait for a socket file to appear
# Usage: protocol_wait_for_socket <socket_path> <timeout_ms> <interval_ms>
protocol_wait_for_socket() {
  local socket_path="$1"
  local timeout_ms="${2:-10000}"
  local interval_ms="${3:-200}"
  local elapsed=0

  while [ "$elapsed" -lt "$timeout_ms" ]; do
    if [ -S "$socket_path" ]; then
      return 0
    fi
    sleep "$(awk "BEGIN {print $interval_ms / 1000}")"
    elapsed=$((elapsed + interval_ms))
  done

  return 1
}

# Wait for a TCP port to accept connections
# Usage: protocol_wait_for_tcp <host> <port> <timeout_ms> <interval_ms>
protocol_wait_for_tcp() {
  local host="$1"
  local port="$2"
  local timeout_ms="${3:-10000}"
  local interval_ms="${4:-200}"
  local elapsed=0

  while [ "$elapsed" -lt "$timeout_ms" ]; do
    if echo > "/dev/tcp/${host}/${port}" 2>/dev/null; then
      return 0
    fi
    sleep "$(awk "BEGIN {print $interval_ms / 1000}")"
    elapsed=$((elapsed + interval_ms))
  done

  return 1
}

# Spawn a background server process
# Usage: protocol_spawn_server <log_file> <command...>
# Sets SERVER_PID to the spawned process ID
protocol_spawn_server() {
  local log_file="$1"
  shift

  "$@" >>"$log_file" 2>&1 &
  SERVER_PID=$!
}

# Shutdown a server process gracefully
# Usage: protocol_shutdown_server <pid> <method> <timeout_ms>
protocol_shutdown_server() {
  local pid="$1"
  local method="${2:-sigterm}"
  local timeout_ms="${3:-5000}"

  if ! kill -0 "$pid" 2>/dev/null; then
    return 0
  fi

  case "$method" in
    sigterm)
      kill -TERM "$pid" 2>/dev/null
      ;;
    sigkill)
      kill -KILL "$pid" 2>/dev/null
      return 0
      ;;
    http)
      # Try graceful HTTP shutdown if URL is provided as $4
      if [ -n "${4:-}" ]; then
        curl -s -X POST "$4" 2>/dev/null
      fi
      ;;
    close)
      # For websocket, just send SIGTERM
      kill -TERM "$pid" 2>/dev/null
      ;;
  esac

  # Wait for process to exit
  local elapsed=0
  local interval=100
  while kill -0 "$pid" 2>/dev/null && [ "$elapsed" -lt "$timeout_ms" ]; do
    sleep "$(awk "BEGIN {print $interval / 1000}")"
    elapsed=$((elapsed + interval))
  done

  # Force kill if still running
  if kill -0 "$pid" 2>/dev/null; then
    kill -KILL "$pid" 2>/dev/null
  fi

  wait "$pid" 2>/dev/null
  return 0
}

# Expand placeholders in a string
# Usage: protocol_expand <string> <port> <socket_path> <server_pid> <profile_id> <runtime_root>
protocol_expand() {
  local str="$1"
  local port="${2:-}"
  local socket_path="${3:-}"
  local server_pid="${4:-}"
  local profile_id="${5:-}"
  local runtime_root="${6:-}"

  str="${str//\{port\}/$port}"
  str="${str//\{socketPath\}/$socket_path}"
  str="${str//\{serverPid\}/$server_pid}"
  str="${str//\{profileId\}/$profile_id}"
  str="${str//\{runtimeRoot\}/$runtime_root}"
  str="${str//\{binary\}/$BINARY}"

  echo "$str"
}

# Expand an array of strings with placeholders
# Usage: protocol_expand_array <result_array_name> <port> <socket_path> <server_pid> <profile_id> <runtime_root> -- <items...>
protocol_expand_array() {
  local result_name="$1"
  local port="$2"
  local socket_path="$3"
  local server_pid="$4"
  local profile_id="$5"
  local runtime_root="$6"
  shift 6

  # Skip the -- separator
  if [ "$1" = "--" ]; then
    shift
  fi

  local expanded=()
  local item
  for item in "$@"; do
    expanded+=("$(protocol_expand "$item" "$port" "$socket_path" "$server_pid" "$profile_id" "$runtime_root")")
  done

  eval "$result_name=(\"\${expanded[@]}\")"
}

# Read a JSON field from an adapter.json using python3
# Usage: protocol_json_field <json_file> <field_path>
# field_path uses dot notation: "protocol.stdio.command"
protocol_json_field() {
  local json_file="$1"
  local field_path="$2"

  python3 -c "
import json, sys
with open('$json_file') as f:
    data = json.load(f)
keys = '$field_path'.split('.')
val = data
for k in keys:
    if isinstance(val, dict) and k in val:
        val = val[k]
    else:
        sys.exit(1)
if isinstance(val, list):
    print(' '.join(str(x) for x in val))
elif isinstance(val, dict):
    print(json.dumps(val))
else:
    print(val)
" 2>/dev/null
}

# Read a JSON array from an adapter.json using python3
# Usage: protocol_json_array <result_array_name> <json_file> <field_path>
protocol_json_array() {
  local result_name="$1"
  local json_file="$2"
  local field_path="$3"

  local items
  items=$(python3 -c "
import json, sys
with open('$json_file') as f:
    data = json.load(f)
keys = '$field_path'.split('.')
val = data
for k in keys:
    if isinstance(val, dict) and k in val:
        val = val[k]
    else:
        sys.exit(1)
if isinstance(val, list):
    for item in val:
        print(item)
" 2>/dev/null)

  local arr=()
  while IFS= read -r line; do
    [ -n "$line" ] && arr+=("$line")
  done <<< "$items"

  eval "$result_name=(\"\${arr[@]}\")"
}

# Read a JSON object as key=value lines from an adapter.json
# Usage: protocol_json_env <json_file> <field_path>
# Returns lines like KEY=VALUE that can be eval'd
protocol_json_env() {
  local json_file="$1"
  local field_path="$2"

  python3 -c "
import json, sys, shlex
with open('$json_file') as f:
    data = json.load(f)
keys = '$field_path'.split('.')
val = data
for k in keys:
    if isinstance(val, dict) and k in val:
        val = val[k]
    else:
        sys.exit(1)
if isinstance(val, dict):
    for k, v in val.items():
        print(f'{k}={shlex.quote(str(v))}')
" 2>/dev/null
}

#!/usr/bin/env bash
# Shared helpers for the transport smoke tests.
#
# A smoke test scripts one transport end to end:
#   1. start a local server on an ephemeral port,
#   2. write a throwaway Adium profile with one account and one password,
#   3. launch the app, bring the account online,
#   4. prove both message directions with a scripted second peer.
#
# The app is driven through its own AppleScript interface. That needs the
# Automation permission for AdiumY on the terminal that runs this script; see
# scripts/smoke/README.md. The run refuses to start while another AdiumY is
# running, because Apple events reach the app by name, not by process.
#
# Source this file, then call smoke_begin first.

set -euo pipefail

SMOKE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SMOKE_DIR="$(cd "$SMOKE_LIB_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SMOKE_DIR/../.." && pwd)"

APP_BUNDLE="${SMOKE_APP_BUNDLE:-$REPO_ROOT/build/Release-Debug/AdiumY.app}"
APP_NAME="AdiumY"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Seconds to wait for one asynchronous step. A connect on loopback is fast; the
# values are generous so a slow machine does not report a false failure.
SMOKE_CONNECT_TIMEOUT="${SMOKE_CONNECT_TIMEOUT:-60}"
SMOKE_MESSAGE_TIMEOUT="${SMOKE_MESSAGE_TIMEOUT:-30}"

# Set SMOKE_APP_DEBUG=1 to have the app write its debug log inside the
# throwaway home. The log is the only view into the app while a run goes
# wrong: the app's standard output holds little more than its startup noise.
SMOKE_APP_DEBUG="${SMOKE_APP_DEBUG:-0}"

SMOKE_TRANSPORT=""
SMOKE_HOME=""
SMOKE_WORK=""
SMOKE_WORK_CREATED=0
SMOKE_APP_PID=""
SMOKE_APP_WAS_LAUNCHED=0
SMOKE_KEYCHAIN_SERVICE=""
SMOKE_KEYCHAIN_ACCOUNT=""
SMOKE_ACCOUNT_UID=""
SMOKE_PEER_PID=""
SMOKE_PEER_STATUS=""

# --- messages -------------------------------------------------------------

smoke_step() {
  printf 'smoke: %s\n' "$*"
}

# Report a failed step as cause and fix, then stop.
#   smoke_fail <operation> <observed> <fix>
smoke_fail() {
  local operation="$1" observed="$2" fix="$3"
  printf 'smoke: FAIL %s\n' "$operation" >&2
  printf 'smoke:   observed: %s\n' "$observed" >&2
  printf 'smoke:   fix: %s\n' "$fix" >&2
  exit 1
}

# Poll a predicate until it holds or the deadline passes. A bounded wait is the
# only way to test an asynchronous system; the interval stays small so a slow
# step is visible sooner. The predicate prints what it saw, and that text goes
# into the failure so the run reports the state, not just the timeout.
#   smoke_wait_for <seconds> <description> <command...>
smoke_wait_for() {
  local seconds="$1" description="$2"
  shift 2
  local output_file="$SMOKE_WORK/logs/last-wait.txt"
  local deadline=$((SECONDS + seconds))
  while [ "$SECONDS" -lt "$deadline" ]; do
    if "$@" >"$output_file" 2>&1; then
      return 0
    fi
    sleep 0.5
  done
  smoke_fail "wait for $description" \
    "the condition stayed false for ${seconds}s. Last check:
$(tail -n 20 "$output_file" 2>/dev/null)" \
    "run with SMOKE_KEEP=1 to keep the work directory, then read the app and server logs in it"
}

# Name the function that stops the transport's server, and the one that prints
# its log. The cleanup step and the connection check call them.
#   smoke_set_server_stop <function>
#   smoke_set_server_log <function>
smoke_set_server_stop() {
  SMOKE_STOP_SERVER="$1"
}

smoke_set_server_log() {
  SMOKE_SERVER_LOG="$1"
}

smoke_server_log() {
  [ -n "${SMOKE_SERVER_LOG:-}" ] || return 0
  "$SMOKE_SERVER_LOG"
}

# True when the server log holds the pattern. A miss prints the log tail, which
# the wait step puts into its failure message.
#   smoke_server_log_has <pattern>
smoke_server_log_has() {
  local pattern="$1" log
  log="$(smoke_server_log || true)"
  if grep -q -- "$pattern" <<<"$log"; then
    return 0
  fi
  printf 'no session matching %s yet. Server log tail:\n%s\n' \
    "$pattern" "$(tail -n 15 <<<"$log")"
  return 1
}

# True when the app shows the password prompt it opens for an account whose
# password it cannot read. The window title comes from PasswordPrompt.nib.
# A window check that fails on its own (the app is gone, or the Automation
# permission is missing) is not a prompt: its text goes into the wait report.
smoke_app_wants_password() {
  local output
  output="$(osascript -e 'with timeout of 5 seconds' \
    -e "tell application \"$APP_NAME\" to get name of every window" \
    -e 'end timeout' 2>&1)" || {
    printf 'window check failed: %s\n' "$output"
    return 1
  }
  case "$output" in
  *"Connecting Account"*) return 0 ;;
  esac
  return 1
}

# Wait until the server records the account's session. A password prompt ends
# the wait at once: the app has no password it can read, so no session can
# appear, and the full timeout would hide the reason.
#   smoke_wait_for_session <server log pattern>
smoke_wait_for_session() {
  local pattern="$1"
  local output_file="$SMOKE_WORK/logs/last-wait.txt"
  local deadline=$((SECONDS + SMOKE_CONNECT_TIMEOUT))
  while [ "$SECONDS" -lt "$deadline" ]; do
    if [ -n "$SMOKE_APP_PID" ] && ! kill -0 "$SMOKE_APP_PID" 2>/dev/null; then
      smoke_fail "the app while connecting" \
        "the app stopped before the server saw its session" \
        "read the end of $SMOKE_WORK/logs/app.stdout, and the newest $APP_NAME report in ~/Library/Logs/DiagnosticReports"
    fi
    if smoke_app_wants_password; then
      smoke_fail "account password" \
        "the app is asking for the account password instead of connecting" \
        "the keychain did not give the app the password this run wrote. Unlock the screen, allow the $APP_NAME keychain prompt, and run this script again"
    fi
    if smoke_server_log_has "$pattern" >"$output_file" 2>&1; then
      return 0
    fi
    sleep 0.5
  done
  smoke_fail "wait for the app's session on the server" \
    "the condition stayed false for ${SMOKE_CONNECT_TIMEOUT}s. Last check:
$(tail -n 20 "$output_file" 2>/dev/null)" \
    "run with SMOKE_KEEP=1 SMOKE_APP_DEBUG=1 to keep the work directory and have the app write its own log, then read them"
}

smoke_require() {
  local tool
  for tool in "$@"; do
    command -v "$tool" >/dev/null 2>&1 ||
      smoke_fail "tool check" "$tool is not on PATH" "install $tool and run this script again"
  done
}

# An ephemeral port for the server to listen on. The port is free when this
# call returns; nothing holds it until the server starts.
smoke_pick_free_port() {
  python3 -I -c 'import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()'
}

# True when the server accepts a TCP connection on the port.
#   smoke_port_is_open <port>
smoke_port_is_open() {
  python3 -I -c '
import socket, sys
s = socket.socket()
s.settimeout(1)
sys.exit(0 if s.connect_ex(("127.0.0.1", int(sys.argv[1]))) == 0 else 1)' "$1"
}

# Wait until the server accepts a connection, then report the state on failure.
#   smoke_wait_for_server <port>
smoke_wait_for_server() {
  local port="$1"
  smoke_wait_for 30 "the server on port $port to accept connections" \
    smoke_server_reports_listening "$port"
}

smoke_server_reports_listening() {
  local port="$1" log
  if smoke_port_is_open "$port"; then
    return 0
  fi
  log="$(smoke_server_log || true)"
  printf 'port %s accepts no connection yet. Server log tail:\n%s\n' \
    "$port" "$(tail -n 15 <<<"$log")"
  return 1
}

# --- profile and app ------------------------------------------------------

# Set up the work directory and the isolated home for one run.
#   smoke_begin <transport>
smoke_begin() {
  SMOKE_TRANSPORT="$1"
  # The name every transport script gives its server container.
  SMOKE_CONTAINER="adiumy-smoke-$SMOKE_TRANSPORT"
  # The work directory stays inside the repository. Docker Desktop and colima
  # share the home directory with their virtual machine, so a server config
  # under the home tree is the only path a container can mount.
  mkdir -p "$REPO_ROOT/.tmp"
  if [ -z "${SMOKE_WORK:-}" ]; then
    SMOKE_WORK="$(mktemp -d "$REPO_ROOT/.tmp/smoke-$SMOKE_TRANSPORT.XXXXXX")"
    SMOKE_WORK_CREATED=1
  fi
  SMOKE_HOME="$SMOKE_WORK/home"
  mkdir -p "$SMOKE_HOME" "$SMOKE_WORK/logs"
  trap smoke_cleanup EXIT INT TERM HUP

  [ -x "$APP_BINARY" ] || smoke_fail "app check" "no app at $APP_BUNDLE" \
    "build the app first: make adium"
  smoke_step "work directory: $SMOKE_WORK"
}

# Write the throwaway profile. Extra preferences come as "key=value" pairs.
#   smoke_profile <transport> <uid> [key=value ...]
smoke_profile() {
  local transport="$1" uid="$2"
  shift 2

  SMOKE_ACCOUNT_UID="$uid"
  local arguments=(--home "$SMOKE_HOME" --transport "$transport" --uid "$uid")
  local preference
  for preference in "$@"; do
    arguments+=(--pref "$preference")
  done
  if [ "$SMOKE_APP_DEBUG" = 1 ]; then
    arguments+=(--debug-log)
  fi

  local output
  output="$(python3 -I "$SMOKE_DIR/lib/profile.py" "${arguments[@]}")" ||
    smoke_fail "profile write" "profile.py exited non-zero" "read the message above and fix the profile arguments"

  SMOKE_KEYCHAIN_SERVICE="$(sed -n 's/^keychain-service=//p' <<<"$output")"
  SMOKE_KEYCHAIN_ACCOUNT="$(sed -n 's/^keychain-account=//p' <<<"$output")"
  [ -n "$SMOKE_KEYCHAIN_ACCOUNT" ] ||
    smoke_fail "profile write" "profile.py printed no keychain names: $output" \
      "check that profile.py supports the transport $transport"
}

# Store the account password in the login keychain. Adium reads account
# passwords from an internet-password item keyed by the service name it builds
# from the account, which profile.py computes. The item goes in through the API
# the app reads it with; see the keychain_item.py docstring for why the
# security command does not work here.
#   smoke_keychain_add <password>
smoke_keychain_add() {
  local password="$1" output status=0

  output="$(python3 -I "$SMOKE_DIR/lib/keychain_item.py" add \
    --server "$SMOKE_KEYCHAIN_SERVICE" --account "$SMOKE_KEYCHAIN_ACCOUNT" \
    --password "$password" 2>&1)" || status=$?
  [ "$status" -eq 0 ] ||
    smoke_fail "keychain write" "keychain_item.py exited $status: $output" \
      "unlock the login keychain and run this script again"
}

smoke_keychain_remove() {
  [ -n "$SMOKE_KEYCHAIN_SERVICE" ] || return 0
  local output
  if ! output="$(python3 -I "$SMOKE_DIR/lib/keychain_item.py" remove \
    --server "$SMOKE_KEYCHAIN_SERVICE" --account "$SMOKE_KEYCHAIN_ACCOUNT" 2>&1)"; then
    smoke_warn "keychain item left behind: delete it with
    python3 -I $SMOKE_DIR/lib/keychain_item.py remove \\
      --server '$SMOKE_KEYCHAIN_SERVICE' --account '$SMOKE_KEYCHAIN_ACCOUNT'
    ($output)"
  fi
}

smoke_warn() {
  printf 'smoke: warning: %s\n' "$*" >&2
}

smoke_terminal_name() {
  local pid=$$ name=""
  while [ -n "$pid" ] && [ "$pid" != "1" ]; do
    name="$(ps -o comm= -p "$pid" 2>/dev/null || true)"
    case "$name" in
    *.app/Contents/MacOS/*)
      printf '%s\n' "$(basename "${name%%.app/*}")"
      return 0
      ;;
    esac
    pid="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')"
  done
  printf 'the terminal\n'
}

# Pids of the app under test. The path names one bundle, so this finds every
# copy of it, including one that starts after this run launched the first.
# pgrep exit 1 means "no match", which is normal; any other status is a real
# failure and must not read as "no app is running".
smoke_app_processes() {
  local pids status=0
  pids="$(pgrep -f "$APP_BINARY" 2>/dev/null)" || status=$?
  if [ "$status" -gt 1 ]; then
    smoke_warn "pgrep failed with status $status while looking for $APP_NAME"
  fi
  [ -z "$pids" ] || printf '%s\n' "$pids"
}

# Apple events reach the app by name, so any other running copy answers them
# too. Refuse to run rather than drive the wrong instance.
smoke_require_no_other_app() {
  local running
  running="$(smoke_app_processes)"
  [ -z "$running" ] || smoke_fail "another instance is running" \
    "$APP_NAME is already running, pid $running" \
    "quit $APP_NAME and run this script again: Apple events reach the app by name, so the test would drive your session too"
}

# Launch the app against the throwaway home. The app writes its profile, its
# logs, and its caches inside that home only.
smoke_launch_app() {
  smoke_require_no_other_app
  [ -n "$SMOKE_ACCOUNT_UID" ] ||
    smoke_fail "app launch" "no account was written for this run" \
      "call smoke_profile before smoke_launch_app"
  local arguments=()
  if [ "$SMOKE_APP_DEBUG" = 1 ]; then
    arguments+=(-AIEnableDebugLogging YES)
  fi
  # The guard around the array keeps an empty expansion legal under set -u on
  # the bash 3.2 that macOS ships.
  CFFIXED_USER_HOME="$SMOKE_HOME" "$APP_BINARY" ${arguments[@]+"${arguments[@]}"} \
    >"$SMOKE_WORK/logs/app.stdout" 2>&1 &
  SMOKE_APP_PID=$!
  SMOKE_APP_WAS_LAUNCHED=1
  smoke_step "app started, pid $SMOKE_APP_PID"
  smoke_wait_for 15 "the app to stay up" smoke_app_is_alive
  # The app answers Apple events a moment after it starts, and it loads its
  # account list a few seconds later. Both waits cover that startup time: a
  # step that names the account before it exists fails with -1728.
  smoke_wait_for "$SMOKE_CONNECT_TIMEOUT" "the app to load $SMOKE_ACCOUNT_UID" smoke_app_has_account
}

smoke_app_is_alive() {
  if kill -0 "$SMOKE_APP_PID" 2>/dev/null; then
    return 0
  fi
  printf 'the app exited during startup. app.stdout tail:\n%s\n' \
    "$(tail -n 20 "$SMOKE_WORK/logs/app.stdout" 2>/dev/null)"
  return 1
}

# True when the app answers Apple events and lists the account this run wrote
# into its profile. The UID is per-run, so an answer that carries it also proves
# the events reach the instance this run started.
smoke_app_has_account() {
  local output
  # The app name is written into the script, not passed in: AppleScript needs
  # the app's own terminology at compile time, and a reference resolved from a
  # variable has none ("The variable accounts is not defined").
  # The timeout keeps one unresponsive app from holding up the whole wait:
  # AppleScript's own default is two minutes per call.
  if ! output="$(osascript -e 'with timeout of 10 seconds' \
    -e "tell application \"$APP_NAME\" to get name of every account" \
    -e 'end timeout' 2>&1)"; then
    # -1743 is the Automation permission, which only the user can grant. Every
    # other failure, such as -600 while the app still starts, is a retry.
    if [[ "$output" == *"-1743"* ]]; then
      smoke_fail "Automation permission" "the terminal is not allowed to send Apple events to $APP_NAME" \
        "enable System Settings > Privacy & Security > Automation > $(smoke_terminal_name) > $APP_NAME, then run this script again"
    fi
    printf 'the app did not answer: %s\napp.stdout tail:\n%s\n' \
      "$output" "$(tail -n 10 "$SMOKE_WORK/logs/app.stdout" 2>/dev/null)"
    return 1
  fi
  if grep -qF -- "$SMOKE_ACCOUNT_UID" <<<"$output"; then
    return 0
  fi
  printf 'the app lists no account %s yet: %s\n' "$SMOKE_ACCOUNT_UID" "$output"
  return 1
}

# Run AppleScript with arguments. Account names and message text always travel
# as arguments, never inside the script text, so a value cannot change what the
# script does. Only the app name is written into the script, because AppleScript
# resolves an app's own terminology at compile time.
#   smoke_applescript <script line> [<script line> ...] -- <argument> ...
smoke_applescript() {
  local lines=()
  while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do
    lines+=(-e "$1")
    shift
  done
  [ "${1:-}" = "--" ] && shift

  local output
  # A script that reaches an unresponsive app must not hold the run open.
  if ! output="$(osascript -e 'on run argv' -e 'with timeout of 30 seconds' \
    "${lines[@]}" -e 'end timeout' -e 'end run' "$@" 2>&1)"; then
    # A dead app answers -609, which reads like a permission problem and is not
    # one. Report the crash, with the two places that name its cause.
    if [ "$SMOKE_APP_WAS_LAUNCHED" = 1 ] && ! kill -0 "$SMOKE_APP_PID" 2>/dev/null; then
      smoke_fail "the app stopped during an AppleScript command" "$output" \
        "the app crashed. Read the end of $SMOKE_WORK/logs/app.stdout, and the newest $APP_NAME report in ~/Library/Logs/DiagnosticReports"
    fi
    smoke_fail "AppleScript" "$output" \
      "check System Settings > Privacy & Security > Automation > $(smoke_terminal_name) > $APP_NAME"
  fi
  printf '%s\n' "$output"
}

# Bring the account online. The app connects on the first online status.
#   smoke_go_online <uid>
smoke_go_online() {
  local uid="$1"
  smoke_step "bringing $uid online"
  smoke_applescript \
    "tell application \"$APP_NAME\" to tell account (item 1 of argv) to go online" \
    -- "$uid" >/dev/null
}

# Read the account's status type. This is a status, not a connection: the app
# reports "available" for an account that has not connected yet.
#   smoke_adium_status <uid>
smoke_adium_status() {
  local uid="$1"
  osascript -e 'on run argv' \
    -e 'with timeout of 10 seconds' \
    -e "tell application \"$APP_NAME\" to tell account (item 1 of argv) to get status type" \
    -e 'end timeout' \
    -e 'end run' "$uid" 2>&1 || printf 'AppleScript failed\n'
}

# Send a message from Adium to a contact, through a chat the app opens.
#   smoke_send <account-uid> <contact-uid> <message>
smoke_send() {
  local account_uid="$1" contact_uid="$2" message="$3"
  smoke_step "sending from Adium: $message"
  smoke_applescript \
    "tell application \"$APP_NAME\"" \
    'tell account (item 1 of argv)' \
    'set newChat to make new chat with contacts {contact (item 2 of argv)} with new chat window' \
    'end tell' \
    'send newChat message (item 3 of argv)' \
    'end tell' \
    -- "$account_uid" "$contact_uid" "$message" >/dev/null
}

# --- assertions -----------------------------------------------------------

smoke_logs_directory() {
  printf '%s\n' "$SMOKE_HOME/Library/Application Support/Adium 2.0/Users/Default/Logs"
}

# True when Adium has written the text into any chat log. The app logs every
# message it displays, so this is the file-level proof that a message arrived.
#   smoke_log_contains <text>
smoke_log_contains() {
  local needle="$1" logs
  logs="$(smoke_logs_directory)"
  if grep -rq -- "$needle" "$logs" 2>/dev/null; then
    return 0
  fi
  printf 'the chat logs hold no %s yet:\n%s\n' "$needle" \
    "$(find "$logs" -type f 2>/dev/null | head -n 10)"
  return 1
}

# True once the peer process has finished with status 0. The status is kept, so
# a second call reports the same result rather than a reaped process.
#   smoke_peer_succeeded <pid> <logfile>
smoke_peer_succeeded() {
  local pid="$1" logfile="${2:-}"
  if kill -0 "$pid" 2>/dev/null; then
    return 1
  fi
  if [ -z "$SMOKE_PEER_STATUS" ]; then
    SMOKE_PEER_STATUS=0
    wait "$pid" 2>/dev/null || SMOKE_PEER_STATUS=$?
  fi
  [ "$SMOKE_PEER_STATUS" -eq 0 ] && return 0
  printf 'the peer exited %s after failing its own check. Peer log tail:\n%s\n' \
    "$SMOKE_PEER_STATUS" "$(tail -n 15 "$logfile" 2>/dev/null)"
  return 1
}

# --- teardown -------------------------------------------------------------

# Stop every process of the app this run started. The recorded pid is not
# enough: a second copy of the same bundle can start beside it, and a copy left
# running would answer the Apple events of the next run.
smoke_stop_app() {
  [ "$SMOKE_APP_WAS_LAUNCHED" -eq 1 ] || return 0
  SMOKE_APP_WAS_LAUNCHED=0

  local pids deadline
  pids="$(smoke_app_processes)"
  [ -n "$pids" ] || return 0
  # Word splitting is wanted: kill takes every pid in the list.
  # shellcheck disable=SC2086
  kill -TERM $pids 2>/dev/null || true

  deadline=$((SECONDS + 15))
  while [ "$SECONDS" -lt "$deadline" ] && [ -n "$(smoke_app_processes)" ]; do
    sleep 0.5
  done

  pids="$(smoke_app_processes)"
  [ -n "$pids" ] || return 0
  # shellcheck disable=SC2086
  kill -KILL $pids 2>/dev/null || true
  deadline=$((SECONDS + 5))
  while [ "$SECONDS" -lt "$deadline" ] && [ -n "$(smoke_app_processes)" ]; do
    sleep 0.5
  done

  pids="$(smoke_app_processes)"
  if [ -n "$pids" ]; then
    smoke_warn "the app did not stop; pid $pids is still running:
    kill -KILL $pids"
  fi
}

smoke_stop_peer() {
  [ -n "$SMOKE_PEER_PID" ] || return 0
  kill -TERM "$SMOKE_PEER_PID" 2>/dev/null || true
  SMOKE_PEER_PID=""
}

smoke_cleanup() {
  local status=$?
  smoke_stop_app
  smoke_stop_peer
  smoke_keychain_remove
  if [ "${SMOKE_KEEP:-0}" = "1" ]; then
    # The server stays up with the work directory, so the run can be inspected
    # with docker logs after it ends.
    smoke_step "kept the work directory: $SMOKE_WORK
kept the server container: read it with docker logs $SMOKE_CONTAINER"
  else
    if [ -n "${SMOKE_STOP_SERVER:-}" ]; then
      $SMOKE_STOP_SERVER >/dev/null 2>&1 || smoke_warn "the server container was not removed;
    remove it with: docker rm -f \$(docker ps -aq --filter name=$SMOKE_TRANSPORT)"
    fi
    if [ "$SMOKE_WORK_CREATED" = "1" ] && [ -d "$SMOKE_WORK" ]; then
      trash "$SMOKE_WORK" >/dev/null 2>&1 ||
        smoke_warn "the work directory was not removed: $SMOKE_WORK"
    fi
  fi
  exit "$status"
}

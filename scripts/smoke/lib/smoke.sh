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
# scripts/smoke/README.md. Nothing here touches the real Adium profile.
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

SMOKE_TRANSPORT=""
SMOKE_HOME=""
SMOKE_WORK=""
SMOKE_APP_PID=""
SMOKE_APP_WAS_LAUNCHED=0
SMOKE_KEYCHAIN_SERVICE=""
SMOKE_KEYCHAIN_ACCOUNT=""

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
# step is visible sooner.
#   smoke_wait_for <seconds> <description> <command...>
smoke_wait_for() {
  local seconds="$1" description="$2"
  shift 2
  local deadline=$((SECONDS + seconds))
  while [ "$SECONDS" -lt "$deadline" ]; do
    if "$@" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.5
  done
  smoke_fail "wait for $description" "the condition stayed false for ${seconds}s" \
    "run with SMOKE_KEEP=1 to keep the work directory, then read the app and server logs in it"
}

# Name the function that stops the transport's server. The cleanup step calls it.
#   smoke_set_server_stop <function>
smoke_set_server_stop() {
  SMOKE_STOP_SERVER="$1"
}

smoke_require() {
  local tool
  for tool in "$@"; do
    command -v "$tool" >/dev/null 2>&1 ||
      smoke_fail "tool check" "$tool is not on PATH" "install $tool and run this script again"
  done
}

# --- profile and app ------------------------------------------------------

# Set up the work directory and the isolated home for one run.
#   smoke_begin <transport>
smoke_begin() {
  SMOKE_TRANSPORT="$1"
  # The work directory stays inside the repository. Docker Desktop and colima
  # share the home directory with their virtual machine, so a server config
  # under the home tree is the only path a container can mount.
  mkdir -p "$REPO_ROOT/.tmp"
  SMOKE_WORK="${SMOKE_WORK:-$(mktemp -d "$REPO_ROOT/.tmp/smoke-$SMOKE_TRANSPORT.XXXXXX")}"
  SMOKE_HOME="$SMOKE_WORK/home"
  mkdir -p "$SMOKE_HOME" "$SMOKE_WORK/logs"
  trap smoke_cleanup EXIT

  [ -x "$APP_BINARY" ] || smoke_fail "app check" "no app at $APP_BUNDLE" \
    "build the app first: make adium"
  smoke_step "work directory: $SMOKE_WORK"
}

# Write the throwaway profile. Extra preferences come as "key=value" pairs.
#   smoke_profile <transport> <uid> [key=value ...]
smoke_profile() {
  local transport="$1" uid="$2"
  shift 2

  local arguments=(--home "$SMOKE_HOME" --transport "$transport" --uid "$uid")
  local preference
  for preference in "$@"; do
    arguments+=(--pref "$preference")
  done

  local output
  output="$(python3 -I "$SMOKE_DIR/lib/profile.py" "${arguments[@]}")" ||
    smoke_fail "profile write" "profile.py exited non-zero" "read the message above and fix the profile arguments"

  SMOKE_KEYCHAIN_SERVICE="$(sed -n 's/^keychain-service=//p' <<<"$output")"
  SMOKE_KEYCHAIN_ACCOUNT="$(sed -n 's/^keychain-account=//p' <<<"$output")"
}

# Store the account password in the login keychain. Adium reads account
# passwords from an internet-password item keyed by the service name it builds
# from the account, which profile.py computes.
#   smoke_keychain_add <password>
smoke_keychain_add() {
  local password="$1"

  security add-internet-password \
    -s "$SMOKE_KEYCHAIN_SERVICE" -a "$SMOKE_KEYCHAIN_ACCOUNT" \
    -r AdIM -w "$password" -U >/dev/null 2>&1 ||
    smoke_fail "keychain write" "cannot add an internet password for $SMOKE_KEYCHAIN_SERVICE" \
      "unlock the login keychain and run this script again"
}

smoke_keychain_remove() {
  [ -n "$SMOKE_KEYCHAIN_SERVICE" ] || return 0
  security delete-internet-password \
    -s "$SMOKE_KEYCHAIN_SERVICE" -a "$SMOKE_KEYCHAIN_ACCOUNT" >/dev/null 2>&1 || true
}

# Confirm the terminal may drive the app through Apple events. Without the
# Automation permission every scripted step fails, so check once, up front.
smoke_check_automation() {
  local output
  if ! output="$(osascript -e "tell application \"$APP_NAME\" to get version" 2>&1)"; then
    if [[ "$output" == *"-1743"* ]]; then
      smoke_fail "Automation permission" "the terminal is not allowed to send Apple events to $APP_NAME" \
        "enable System Settings > Privacy & Security > Automation > $(smoke_terminal_name) > $APP_NAME, then run this script again"
    fi
    smoke_fail "AppleScript check" "$output" "start $APP_NAME once by hand and run this script again"
  fi
}

smoke_terminal_name() {
  local pid=$$ name=""
  while [ -n "$pid" ] && [ "$pid" != "1" ]; do
    name="$(ps -o comm= -p "$pid" 2>/dev/null || true)"
    case "$name" in
    *.app/Contents/MacOS/*)
      printf '%s\n' "$(basename "${name%%.app/*})")"
      return 0
      ;;
    esac
    pid="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')"
  done
  printf 'the terminal\n'
}

# Launch the app against the throwaway home. The app writes its profile, its
# logs, and its caches inside that home only.
smoke_launch_app() {
  CFFIXED_USER_HOME="$SMOKE_HOME" "$APP_BINARY" >"$SMOKE_WORK/logs/app.stdout" 2>&1 &
  SMOKE_APP_PID=$!
  SMOKE_APP_WAS_LAUNCHED=1
  smoke_step "app started, pid $SMOKE_APP_PID"
  smoke_wait_for "$SMOKE_CONNECT_TIMEOUT" "the app window" smoke_adium_answers
}

smoke_adium_answers() {
  osascript -e "tell application \"$APP_NAME\" to count accounts" >/dev/null 2>&1
}

# Run an AppleScript fragment. The fragment is plain text for osascript.
smoke_applescript() {
  local script="$1"
  local output
  if ! output="$(osascript -e "$script" 2>&1)"; then
    smoke_fail "AppleScript" "$output" \
      "check System Settings > Privacy & Security > Automation > $(smoke_terminal_name) > $APP_NAME"
  fi
  printf '%s\n' "$output"
}

# Bring the account online. The app connects on the first online status.
smoke_go_online() {
  local uid="$1"
  smoke_step "bringing $uid online"
  smoke_applescript "tell application \"$APP_NAME\" to tell account \"$uid\" to go online" >/dev/null
}

smoke_go_offline() {
  local uid="$1"
  osascript -e "tell application \"$APP_NAME\" to tell account \"$uid\" to go offline" >/dev/null 2>&1 || true
}

# Send a message from Adium to a contact, through a chat the app opens.
#   smoke_send <account-uid> <contact-uid> <message>
smoke_send() {
  local account_uid="$1" contact_uid="$2" message="$3"
  smoke_step "sending from Adium: $message"
  smoke_applescript "tell application \"$APP_NAME\"
	tell account \"$account_uid\"
		set newChat to make new chat with contacts {contact \"$contact_uid\"} with new chat window
	end tell
	send newChat message \"$message\"
end tell" >/dev/null
}

# --- assertions -----------------------------------------------------------

smoke_logs_directory() {
  printf '%s\n' "$SMOKE_HOME/Library/Application Support/Adium 2.0/Users/Default/Logs"
}

# True when Adium has written the text into any chat log. The app logs every
# message it displays, so this is the file-level proof that a message arrived.
smoke_log_contains() {
  local needle="$1"
  grep -rq -- "$needle" "$(smoke_logs_directory)" 2>/dev/null
}

# --- teardown -------------------------------------------------------------

smoke_stop_app() {
  [ "$SMOKE_APP_WAS_LAUNCHED" -eq 1 ] || return 0
  osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
  local deadline=$((SECONDS + 15))
  while [ "$SECONDS" -lt "$deadline" ] && kill -0 "$SMOKE_APP_PID" 2>/dev/null; do
    sleep 0.5
  done
  if kill -0 "$SMOKE_APP_PID" 2>/dev/null; then
    kill "$SMOKE_APP_PID" 2>/dev/null || true
  fi
  SMOKE_APP_WAS_LAUNCHED=0
}

smoke_cleanup() {
  local status=$?
  smoke_stop_app
  smoke_keychain_remove
  if [ -n "${SMOKE_STOP_SERVER:-}" ]; then
    $SMOKE_STOP_SERVER >/dev/null 2>&1 || true
  fi
  if [ "${SMOKE_KEEP:-0}" = "1" ]; then
    smoke_step "kept the work directory: $SMOKE_WORK"
  elif [ -n "$SMOKE_WORK" ] && [ -d "$SMOKE_WORK" ]; then
    trash "$SMOKE_WORK" >/dev/null 2>&1 || true
  fi
  exit "$status"
}

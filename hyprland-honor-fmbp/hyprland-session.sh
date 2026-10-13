#!/usr/bin/env bash
set -euo pipefail
set +m

if [[ $# -eq 0 || ${1:0:1} != / || ! -x $1 ]]; then
  printf '%s\n' 'hyprland-session: an absolute watchdog executable is required' >&2
  exit 64
fi
if [[ ${XDG_RUNTIME_DIR:-} != /* || ! -d $XDG_RUNTIME_DIR || ! -O $XDG_RUNTIME_DIR ]]; then
  printf '%s\n' 'hyprland-session: a user-owned XDG_RUNTIME_DIR is required' >&2
  exit 1
fi

umask 077
lock_file="$XDG_RUNTIME_DIR/hyprland-session.lock"
control_file="$XDG_RUNTIME_DIR/hyprland-session-control.lock"
exec 9>>"$lock_file"
if ! flock -n 9; then
  printf '%s\n' 'hyprland-session: another direct session is already running' >&2
  exit 1
fi

child_pid=
group_pid=
signal_status=0
# shellcheck disable=SC2329
cleanup() {
  local status=$1
  trap - EXIT
  trap '' TERM INT
  if [[ -n $group_pid ]]; then
    kill -TERM -- "-$group_pid" 2>/dev/null || true
    if [[ -n $child_pid ]]; then
      kill -TERM "$child_pid" 2>/dev/null || true
    fi
    for (( attempt = 0; attempt < 50; attempt++ )); do
      if ! kill -0 -- "-$group_pid" 2>/dev/null &&
        { [[ -z $child_pid ]] || ! kill -0 "$child_pid" 2>/dev/null; }; then
        break
      fi
      sleep 0.1 || true
    done
    if kill -0 -- "-$group_pid" 2>/dev/null; then
      kill -KILL -- "-$group_pid" 2>/dev/null || true
    fi
    if [[ -n $child_pid ]]; then
      if kill -0 "$child_pid" 2>/dev/null; then
        kill -KILL "$child_pid" 2>/dev/null || true
      fi
      if ! kill -0 "$child_pid" 2>/dev/null; then
        wait "$child_pid" 2>/dev/null || true
      fi
    fi
  fi
  exec 8>>"$control_file"
  flock 8 || true
  : >"$lock_file"
  systemctl --user stop hyprland-session.target 8>&- 9>&- || true
  exit "$status"
}
terminate() {
  signal_status=$1
  if [[ -n $group_pid ]]; then
    exit "$signal_status"
  fi
}
trap 'cleanup "$?"' EXIT
trap 'terminate 143' TERM
trap 'terminate 130' INT

read -r HYPRLAND_SESSION_TOKEN </proc/sys/kernel/random/uuid
export HYPRLAND_SESSION_TOKEN
export HYPRLAND_SESSION_SUPERVISOR_PID=$$
printf '%s %s\n' "$HYPRLAND_SESSION_SUPERVISOR_PID" "$HYPRLAND_SESSION_TOKEN" >"$lock_file"

setsid "$@" 9>&- &
child_pid=$!
group_pid=$child_pid
if (( signal_status != 0 )); then
  terminate "$signal_status"
fi
status=0
wait "$child_pid" || status=$?
child_pid=
exit "$status"

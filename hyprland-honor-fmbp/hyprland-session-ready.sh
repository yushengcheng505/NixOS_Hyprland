#!/usr/bin/env bash
set -euo pipefail

exec > >(systemd-cat --identifier=hyprland-session-ready) 2>&1

fail() {
  printf 'hyprland-session-ready: %s\n' "$1" >&2
  exit 1
}

[[ ${XDG_RUNTIME_DIR:-} == /* && -d $XDG_RUNTIME_DIR && -O $XDG_RUNTIME_DIR ]] || fail 'invalid runtime directory'
[[ ${WAYLAND_DISPLAY:-} =~ ^wayland-[0-9]+$ ]] || fail 'invalid WAYLAND_DISPLAY'
[[ ${HYPRLAND_INSTANCE_SIGNATURE:-} =~ ^[a-zA-Z0-9_-]+$ ]] || fail 'invalid HYPRLAND_INSTANCE_SIGNATURE'
[[ ${HYPRLAND_SESSION_SUPERVISOR_PID:-} =~ ^[0-9]+$ && ${HYPRLAND_SESSION_TOKEN:-} =~ ^[a-f0-9-]+$ ]] || fail 'not launched by the direct-session supervisor'

umask 077
lock_file="$XDG_RUNTIME_DIR/hyprland-session.lock"
[[ -f $lock_file && -O $lock_file ]] || fail 'missing session lock'
exec 8>>"$XDG_RUNTIME_DIR/hyprland-session-control.lock"
flock 8
exec 9<"$lock_file"
if flock -n 9; then
  fail 'no supervised session holds the lock'
fi
read -r supervisor token <"$lock_file" || fail 'session is shutting down'
[[ $supervisor == "$HYPRLAND_SESSION_SUPERVISOR_PID" && $token == "$HYPRLAND_SESSION_TOKEN" ]] || fail 'session ownership changed'
kill -0 "$supervisor" 2>/dev/null || fail 'session supervisor exited'
ancestor=$PPID
while [[ $ancestor != "$supervisor" ]]; do
  (( ancestor > 1 )) || fail 'caller is not a supervised compositor descendant'
  parent=
  while read -r field value _; do
    if [[ $field == PPid: ]]; then
      parent=$value
      break
    fi
  done <"/proc/$ancestor/status"
  [[ $parent =~ ^[0-9]+$ ]] || fail 'caller ancestry is unavailable'
  ancestor=$parent
done

for socket in \
  "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" \
  "$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket.sock" \
  "$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"; do
  for (( attempt = 0; attempt < 50; attempt++ )); do
    [[ -S $socket && -O $socket ]] && break
    kill -0 "$supervisor" 2>/dev/null || fail 'session supervisor exited'
    sleep 0.1
  done
  [[ -S $socket && -O $socket ]] || fail "socket is not ready: $socket"
done

systemctl --user stop hyprland-session.target 8>&- 9>&-

keys=(
  DISPLAY WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE
  XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE
  XDG_SESSION_ID XDG_SEAT XDG_VTNR
  QT_QPA_PLATFORM QT_QPA_PLATFORMTHEME QT_STYLE_OVERRIDE
  XCURSOR_THEME XCURSOR_SIZE HYPRCURSOR_THEME HYPRCURSOR_SIZE
)
environment=()
for key in "${keys[@]}"; do
  environment+=("$key=${!key-}")
done
dbus-update-activation-environment --systemd "${environment[@]}" 8>&- 9>&-
for unit in \
  quickshell.service hypridle-direct.service easycliproxyapi.service \
  xdg-desktop-portal.service xdg-desktop-portal-hyprland.service \
  xdg-desktop-portal-gtk.service; do
  if systemctl --user --quiet is-failed "$unit" 8>&- 9>&-; then
    systemctl --user reset-failed "$unit" 8>&- 9>&-
  fi
done
systemctl --user start hyprland-session.target 8>&- 9>&-
printf '%s\n' 'hyprland-session-ready: session services started'

--############################
--## ENVIRONMENT VARIABLES ###
--############################

---@module 'hl'

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("RUST_BACKTRACE", "full")
hl.env("COLORBT_SHOW_HIDDEN", "1")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Qt QML modules used by Quickshell
hl.env("QML2_IMPORT_PATH", "/run/current-system/sw/lib/qt-6/qml")
hl.env("QML_IMPORT_PATH", "/run/current-system/sw/lib/qt-6/qml")

--################
--## AUTOSTART ###
--################

---@module 'hl'

hl.on("hyprland.start", function()
    -- Make the Wayland session visible to user services and refresh the
    -- direct-session portals used for screen sharing.
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE; systemctl --user reset-failed xdg-desktop-portal-hyprland-direct.service; systemctl --user restart xdg-desktop-portal-hyprland-direct.service xdg-desktop-portal-direct.service")
    -- Start the user unit only after Hyprland has published its output scale.
    -- The unit adds its own five-second ExecStartPre delay.
    hl.exec_cmd("sh -c 'sleep 8; systemctl --user start easycliproxyapi.service'")
    -- Quickshell provides the NetworkManager UI in this session. Stop the
    -- legacy GTK tray applet, which has no compatible host under Wayland.
    hl.exec_cmd("sh -c 'sleep 3; pkill -x nm-applet'")
	 hl.exec_cmd("env LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8 QML2_IMPORT_PATH=/run/current-system/sw/lib/qt-6/qml QML_IMPORT_PATH=/run/current-system/sw/lib/qt-6/qml quickshell -n -p ~/.config/quickshell/cartoon-shell")
end)

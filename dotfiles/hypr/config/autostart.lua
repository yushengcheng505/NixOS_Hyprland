--################
--## AUTOSTART ###
--################

---@module 'hl'

hl.on("hyprland.start", function()
    hl.exec_cmd("hyprland-session-ready")
end)

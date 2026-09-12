--#######################
--## GLOBAL VARIABLES ###
--#######################

---@module 'hl'

local mainMod = "SUPER"
local terminal = "kitty"
local fileManager = "nautilus"
local menu = "qs ipc --path ~/.config/quickshell/cartoon-shell call rect getToggle"

return {
	mainMod = mainMod,
	terminal = terminal,
	fileManager = fileManager,
	menu = menu,
}

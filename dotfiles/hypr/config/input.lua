--############
--## INPUT ###
--############

---@module 'hl'

hl.config({
	input = {
		kb_layout = "us,ru",
		kb_variant = "",
		kb_model = "",
		kb_options = "grp:alt_shift_toggle",
		kb_rules = "",
		follow_mouse = 1,
		sensitivity = 0,

		touchpad = {
			natural_scroll = true,
			["disable_while_typing"] = true,
		},
	},
})

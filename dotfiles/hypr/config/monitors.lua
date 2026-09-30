--###############
--## MONITORS ###
--###############

---@module 'hl'

hl.monitor({
	output = "eDP-1",
	mode = "3120x2080@120",
	position = "auto",
	scale = 1.7333333,
})

-- Render XWayland clients at native pixel size instead of upscaling their
-- logical-resolution buffers; this removes the blur on fractional scale.
hl.config({
	xwayland = {
		force_zero_scaling = true,
	},
})

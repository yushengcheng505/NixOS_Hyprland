---@module 'hl'

-- Keep EasyCLIProxyAPI in the normal tiling layout.
hl.window_rule({
	name = "easycliproxyapi-floating",
	match = { class = "^EasyCLIProxyAPI$" },
	float = false,
})

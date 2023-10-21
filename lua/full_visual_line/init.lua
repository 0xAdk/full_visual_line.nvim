local M = {}

local internal = require 'full_visual_line.internal'

-- Just in case
function M.setup(opts)
	M.enable()
end

function M.toggle()
	if M.is_enabled() then
		M.disable()
	else
		M.enable()
	end
end

function M.is_enabled()
	return internal.is_autocmd_setup()
end

function M.enable()
	internal.cleanup()
	internal.setup_autocmd()

	-- the plugin got enabled while already in visual line mode
	if vim.api.nvim_get_mode().mode == 'V' then
		internal.clear_lines()

		local state = internal.update_visual_line_state()
		internal.draw_lines_in_range(state.start, state._end)
	end
end

function M.disable()
	internal.cleanup()
end

return M

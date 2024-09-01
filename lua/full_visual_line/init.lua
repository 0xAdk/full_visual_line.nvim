-- FIXME:
-- * changing cursorlineopt to disable number highlighting while in visual mode
--   doesn't clear highlighting on numbers

local M = {}

local internal = require 'full_visual_line.internal'

-- Just in case
function M.setup(_opts)
	internal.setup_highlights()
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
	if internal.in_visual_or_select_mode() then
		internal.clear_lines()

		local state = internal.update_visual_line_state()
		if internal.in_visual_or_select_line_mode() then
			internal.draw_lines_in_range(state.start, state._end)
		end

		if internal.is_nr_highlights_enabled() then
			internal.draw_numbers_in_range(state.start, state._end)
			internal.draw_cursor_number_hl()
		end
	end
end

function M.disable()
	internal.cleanup()
end

return M

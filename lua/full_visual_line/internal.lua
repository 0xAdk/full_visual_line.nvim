local Rgb = require 'full_visual_line.internal.color'.Rgb

local M = {}
local group_name = 'full_line_visual_mode'

local a = vim.api
M.autocmd_group = a.nvim_create_augroup(group_name, { clear = true })
M.nsid = a.nvim_create_namespace(group_name)

function M.setup_highlights()
	a.nvim_set_hl(0, 'VisualCursorLineNr', { default = true, link = 'CursorLineNr' })

	local line_nr = Rgb.get_hl(0, { name = 'LineNr' })
	local cursor_line_nr = Rgb.get_hl(0, { name = 'VisualCursorLineNr' })

	local fg, bg
	if line_nr.fg ~= nil and cursor_line_nr.fg ~= nil then
		fg = line_nr.fg:blend(cursor_line_nr.fg, 0.5):to_number()
	end

	if line_nr.bg ~= nil and cursor_line_nr.bg ~= nil then
		bg = line_nr.bg:blend(cursor_line_nr.bg, 0.5):to_number()
	end

	a.nvim_set_hl(0, 'VisualLineNr', { default = true, fg = fg, bg = bg })
end

function M.is_autocmd_setup()
	return not vim.tbl_isempty(a.nvim_get_autocmds { group = M.autocmd_group })
end

function M.setup_autocmd()
	a.nvim_create_autocmd({ 'CursorMoved', 'ModeChanged' }, {
		group = M.autocmd_group,
		callback = vim.schedule_wrap(M.handle_autocmd),
	})
end

function M.remove_autocmd()
	a.nvim_clear_autocmds { group = M.autocmd_group }
end

function M.get_cursor_line_nr_fg()
	local hl = vim.api.nvim_get_hl(0, { name = 'CursorLineNr' })

	if hl == vim.empty_dict() then
		return nil
	end

	return hl.fg
end

function M.in_visual_or_select_mode()
	local modes = {
		'v', 'vs',
		'V', 'Vs',
		'', 's',
		's',
		'S',
		'',
	}

	return vim.tbl_contains(modes, a.nvim_get_mode().mode)
end

function M.in_visual_or_select_line_mode()
	local modes = { 'V', 'Vs', 'S' }

	return vim.tbl_contains(modes, a.nvim_get_mode().mode)
end

function M.is_nr_highlights_enabled()
	if not vim.wo.cursorline then
		return false
	end

	local opt = vim.wo.cursorlineopt
	return opt:match 'both' ~= nil
		or opt:match 'number' ~= nil
end

function M.draw_cursor_number_hl()
	local start, _end = M.get_selection_range()
	a.nvim_buf_set_extmark(0, M.nsid, start - 1, 0, { number_hl_group = 'VisualLineNr' })
	a.nvim_buf_set_extmark(0, M.nsid, _end - 1, 0, { number_hl_group = 'VisualLineNr' })

	local pos = a.nvim_win_get_cursor(0)
	a.nvim_buf_set_extmark(0, M.nsid, pos[1] - 1, 0, {
		number_hl_group = 'VisualCursorLineNr'
	})
end

function M.draw_lines_in_range(range_start, range_end)
	for line = range_start, range_end do
		a.nvim_buf_set_extmark(0, M.nsid, line - 1, 0, {
			line_hl_group = 'Visual',
		})
	end
end

function M.draw_numbers_in_range(range_start, range_end)
	for line = range_start, range_end do
		a.nvim_buf_set_extmark(0, M.nsid, line - 1, 0, {
			number_hl_group = 'VisualLineNr',
		})
	end
end

function M.clear_lines()
	a.nvim_buf_clear_namespace(0, M.nsid, 0, -1)
end

function M.clear_lines_in_range(range_start, range_end)
	a.nvim_buf_clear_namespace(0, M.nsid, range_start, range_end)
end

function M.cleanup()
	M.remove_autocmd()
	M.clear_lines()
end

-- we need to store the last positions of the start and end of the visual
-- selection in order to partially update the selection. Fully clearing and
-- redrawing on every update can cause flickering.
--
-- {start,end}_move_delta is just for convenience
local selection_state = nil

function M.update_visual_line_state()
	local start, _end = M.get_selection_range()

	if selection_state == nil then
		selection_state = { old_start = start, old_end = _end }
	else
		selection_state = { old_start = selection_state.start, old_end = selection_state._end }
	end

	selection_state.start = start
	selection_state._end = _end

	selection_state.start_move_delta = selection_state.start - selection_state.old_start
	selection_state.end_move_delta = selection_state._end - selection_state.old_end

	return selection_state
end

function M.get_selection_range()
	local start_line, end_line = vim.fn.line 'v', vim.fn.line '.'

	-- ensure the start line is always less than or equal to the end line
	if start_line > end_line then
		start_line, end_line = end_line, start_line
	end

	return start_line, end_line
end

function M.handle_autocmd(opts)
	if not M.in_visual_or_select_mode() then
		M.clear_lines()
		return
	end

	local state = M.update_visual_line_state()

	if opts.event == 'ModeChanged' then
		M.clear_lines()
		if M.in_visual_or_select_line_mode() then
			M.draw_lines_in_range(state.start, state._end)
		end

		if M.is_nr_highlights_enabled() then
			M.draw_numbers_in_range(state.start, state._end)
			M.draw_cursor_number_hl()
		end
		return
	end

	-- nothing changed
	if state.start_move_delta == 0 and state.end_move_delta == 0 then
		if M.is_nr_highlights_enabled() then
			M.draw_cursor_number_hl()
		end
		return
	end

	-- add/remove selection lines from the start/end depending on which moved
	-- if both the start and end have moved just clear and redraw everything
	--
	-- `s` = old start, `S` = new start, `e` = old end, `E` = new end
	-- `_` = current vis line, `-` = remove vis line, `+` = add vis line
	if state.start_move_delta ~= 0 and state.end_move_delta ~= 0 then
		M.clear_lines()
		M.draw_lines_in_range(state.start, state._end)
	elseif state.start_move_delta < 0 then
		-- ...S<+++s____E..
		if M.in_visual_or_select_line_mode() then
			M.draw_lines_in_range(state.start, state.old_start - 1)
		end

		if M.is_nr_highlights_enabled() then
			-- off by one due to the current line having a different highlight
			-- then the body of the visual selection
			M.draw_numbers_in_range(state.start, state.old_start)
		end
	elseif state.start_move_delta > 0 then
		-- ...s--->S____E..
		M.clear_lines_in_range(state.old_start - 1, state.start - 1)
	elseif state.end_move_delta > 0 then
		-- ...S____e+++>E..
		if M.in_visual_or_select_line_mode() then
			M.draw_lines_in_range(state.old_end + 1, state._end)
		end

		if M.is_nr_highlights_enabled() then
			-- off by one due to the current line having a different highlight
			-- then the body of the visual selection
			M.draw_numbers_in_range(state.old_end, state._end)
		end
	elseif state.end_move_delta < 0 then
		-- ...S____E<---e..
		M.clear_lines_in_range(state._end, state.old_end)
	end

	if M.is_nr_highlights_enabled() then
		M.draw_cursor_number_hl()
	end
end

return M

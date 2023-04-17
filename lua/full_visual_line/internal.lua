local M = {}
local group_name = 'full_line_visual_mode'

local a = vim.api
local autocmd_group = a.nvim_create_augroup(group_name, { clear = true })
local nsid = a.nvim_create_namespace(group_name)

function M.is_autocmd_setup()
	return not vim.tbl_isempty(a.nvim_get_autocmds { group = group_name })
end

function M.setup_autocmd()
	a.nvim_create_autocmd({ 'CursorMoved', 'ModeChanged' }, {
		group = autocmd_group,
		callback = M.handle_autocmd,
	})
end

function M.remove_autocmd()
	a.nvim_clear_autocmds { group = group_name }
end

function M.draw_lines_in_range(range_start, range_end)
	for line = range_start, range_end do
		a.nvim_buf_set_extmark(0, nsid, line - 1, 0, { line_hl_group = 'Visual' })
	end
end

function M.clear_lines()
	a.nvim_buf_clear_namespace(0, nsid, 0, -1)
end

function M.clear_lines_in_range(range_start, range_end)
	a.nvim_buf_clear_namespace(0, nsid, range_start, range_end)
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
	local start_line, end_line  = vim.fn.line 'v', vim.fn.line '.'

	-- ensure the start line is always less than or equal to the end line
	if start_line > end_line then
		start_line, end_line = end_line, start_line
	end

	return start_line, end_line
end

function M.handle_autocmd(opts)
	if a.nvim_get_mode().mode ~= 'V' then
		M.clear_lines()
		return
	end

	local state = M.update_visual_line_state()

	if opts.event == 'ModeChanged' then
		M.clear_lines()
		M.draw_lines_in_range(state.start, state._end)
		return
	end

	-- nothing changed
	if state.start_move_delta == 0 and state.end_move_delta == 0 then
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
		M.draw_lines_in_range(state.start, state.old_start - 1)
	elseif state.start_move_delta > 0 then
		-- ...s--->S____E..
		M.clear_lines_in_range(state.old_start - 1, state.start - 1)
	elseif state.end_move_delta > 0 then
		-- ...S____e+++>E..
		M.draw_lines_in_range(state.old_end + 1, state._end)
	elseif state.end_move_delta < 0 then
		-- ...S____E<---e..
		M.clear_lines_in_range(state._end, state.old_end)
	end
end

return M

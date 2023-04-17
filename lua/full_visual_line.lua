local M = {}
local group_name = 'full_line_visual_mode'

local a = vim.api
local autocmd_group = a.nvim_create_augroup(group_name, { clear = true })
local nsid = a.nvim_create_namespace(group_name)

do
	local visual_line_state = nil
	function M._get_visual_line_state()
		return visual_line_state
	end

	function M._update_visual_line_state()
		local start_line, end_line = M._get_selection_range()

		if visual_line_state == nil then
			visual_line_state = { old_start = start_line, old_end = end_line }
		else
			visual_line_state = { old_start = visual_line_state.start, old_end = visual_line_state._end }
		end

		visual_line_state.start = start_line
		visual_line_state._end = end_line

		visual_line_state.start_move_delta = visual_line_state.start - visual_line_state.old_start
		visual_line_state.end_move_delta = visual_line_state._end - visual_line_state.old_end

		return visual_line_state
	end

	function M._get_selection_range()
		local start_line, end_line  = vim.fn.line 'v', vim.fn.line '.'

		-- ensure the start line is always less than or equal to the end line
		if start_line > end_line then
			start_line, end_line = end_line, start_line
		end

		return start_line, end_line
	end
end

function M._setup_autocmd()
	a.nvim_create_autocmd({ 'CursorMoved', 'ModeChanged' }, {
		group = autocmd_group,
		callback = M._handle_autocmd,
	})
end

function M._remove_autocmd()
	a.nvim_clear_autocmds { group = group_name }
end

function M._handle_autocmd(opts)
	if a.nvim_get_mode().mode ~= 'V' then
		M._clear_lines()
		return
	end

	local state = M._update_visual_line_state()

	if opts.event == 'ModeChanged' then
		M._clear_lines()
		M._draw_lines_in_range(state.start, state._end)
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
		M._clear_lines()
		M._draw_lines_in_range(state.start, state._end)
	elseif state.start_move_delta < 0 then
		-- ...S<+++s____E..
		M._draw_lines_in_range(state.start, state.old_start - 1)
	elseif state.start_move_delta > 0 then
		-- ...s--->S____E..
		M._clear_lines_in_range(state.old_start - 1, state.start - 1)
	elseif state.end_move_delta > 0 then
		-- ...S____e+++>E..
		M._draw_lines_in_range(state.old_end + 1, state._end)
	elseif state.end_move_delta < 0 then
		-- ...S____E<---e..
		M._clear_lines_in_range(state._end, state.old_end)
	end
end

function M._draw_lines_in_range(range_start, range_end)
	for line = range_start, range_end do
		a.nvim_buf_set_extmark(0, nsid, line - 1, 0, { line_hl_group = 'Visual' })
	end
end

function M._clear_lines()
	a.nvim_buf_clear_namespace(0, nsid, 0, -1)
end

function M._clear_lines_in_range(range_start, range_end)
	a.nvim_buf_clear_namespace(0, nsid, range_start, range_end)
end

function M._cleanup()
	M._remove_autocmd()
	M._clear_lines()
end

function M.disable()
	M._cleanup()
end

function M.enable()
	M._cleanup()
	M._setup_autocmd()

	-- the plugin got turned on while already in visual line mode
	if a.nvim_get_mode().mode == 'V' then
		M._clear_lines()

		local state = M._update_visual_line_state()
		M._draw_lines_in_range(state.start, state._end)
	end
end

function M.is_enabled()
	return not vim.tbl_isempty(a.nvim_get_autocmds { group = group_name })
end

function M.toggle()
	if M.is_enabled() then
		M.disable()
	else
		M.enable()
	end
end

-- Just in case
function M.setup(opts)
	M.enable()
end

return M

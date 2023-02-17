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

	function M._update_visual_line_state(reset)
		-- escape and reenter 'V' mode to refresh '< and '> marks.
		-- This cause a lot of glitchy looking blinking for concealed text
		-- if 'concealcursor' doesn't include 'v'
		local keys = a.nvim_replace_termcodes('<esc>gv', true, false, true)
		a.nvim_feedkeys(keys, 'x!', false)
		local start_line, end_line  = a.nvim_buf_get_mark(0, '<')[1], a.nvim_buf_get_mark(0, '>')[1]

		if reset or visual_line_state == nil then
			visual_line_state = {
				old_start = start_line, old_end = end_line,
				start = start_line, _end = end_line,
			}
		else
			visual_line_state = {
				old_start = visual_line_state.start, old_end = visual_line_state._end,
				start = start_line, _end = end_line,
			}
		end
	end
end

function M._redraw_all_lines()
	local lines = M._get_visual_line_state()

	a.nvim_buf_clear_namespace(0, nsid, 0, -1)
	for line = lines.start, lines._end do
		a.nvim_buf_set_extmark(0, nsid, line - 1, 0, { line_hl_group = 'Visual' })
	end
end

function M._setup_autocmd()
	a.nvim_create_autocmd({ 'CursorMoved', 'ModeChanged' }, {
		group = autocmd_group,
		callback = M._handle_autocmd,
	})
end

function M._handle_autocmd(opts)
	if a.nvim_get_mode().mode ~= 'V' then
		a.nvim_buf_clear_namespace(0, nsid, 0, -1)
		return
	end

	M._update_visual_line_state()

	if opts.event == 'ModeChanged' then
		M._redraw_all_lines()
	end

	local autocmd_state = M._get_visual_line_state()

	if
		autocmd_state.old_start == autocmd_state.start
		and autocmd_state.old_end == autocmd_state._end
	then
		-- abort since nothing has changed
		return
	end

	local start_moved = autocmd_state.old_start ~= autocmd_state.start
	local end_moved = autocmd_state.old_end ~= autocmd_state._end

	-- figure out which end of the selection has changed. Then add or remove line highlights accordingly.
	-- If both ends have changed just clear and redraw everything
	if start_moved and not end_moved then
		local move_delta = autocmd_state.start - autocmd_state.old_start

		if move_delta < 0 then
			-- ........S____E..
			-- ...+++++........
			-- ...S_________E..
			for line = autocmd_state.start, autocmd_state.old_start - 1 do
				a.nvim_buf_set_extmark(0, nsid, line - 1, 0, { line_hl_group = 'Visual' })
			end
		else
			-- ...S_________E..
			-- ...-----........
			-- ........S____E..
			a.nvim_buf_clear_namespace(0, nsid, autocmd_state.old_start - 1, autocmd_state.start - 1)
		end
	elseif end_moved and not start_moved then
		local move_delta = autocmd_state._end - autocmd_state.old_end

		if move_delta > 0 then
			-- ...S____E.......
			-- .........+++++..
			-- ...S_________E..
			for line = autocmd_state.old_end + 1, autocmd_state._end do
				a.nvim_buf_set_extmark(0, nsid, line - 1, 0, { line_hl_group = 'Visual' })
			end
		else
			-- ...S_________E..
			-- .........-----..
			-- ...S____E.......
			a.nvim_buf_clear_namespace(0, nsid, autocmd_state._end, autocmd_state.old_end)
		end
	else
		M._redraw_all_lines()
	end
end

function M._cleanup()
	a.nvim_clear_autocmds { group = group_name }
	a.nvim_buf_clear_namespace(0, nsid, 0, -1)
end

function M.disable()
	M._cleanup()
end

function M.enable()
	M._cleanup()
	M._setup_autocmd()

	-- the plugin got turned on while already in visual line mode
	if a.nvim_get_mode().mode == 'V' then
		M._update_visual_line_state()
		M._redraw_all_lines()
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

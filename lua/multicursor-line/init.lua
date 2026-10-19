local mc = require("multicursor-nvim")

local M = {}

---@alias McLineMode "head" | "tail" | "alternate"

---@class McLineState
---@field mode McLineMode Current active mode
---@field start_line integer Starting line number (1-indexed)
---@field end_line integer Target ending line number (1-indexed)
---@field current_line integer Current line index reached
---@field active boolean Whether a progressive session is active
---@field is_all_selected boolean Whether all lines are currently selected

---@class McLineKeymaps
---@field step? string|false Extra key for stepping (optional)
---@field step_back? string|false Extra key for stepping back (optional)
---@field toggle_all? string|false Extra key for toggling select all (optional)

---@class McLineConfig
---@field default_mode McLineMode Default mode ("head" | "tail" | "alternate")
---@field alternate_start "tail" | "head" Which position the 1st line takes in alternate mode (default: "tail")
---@field prefix string Keymap prefix for starter keys (default: "<leader>m")
---@field dynamic_layer boolean Whether to activate the interactive single-key layer (default: true)
---@field keymaps McLineKeymaps

---@type McLineConfig
local default_config = {
    default_mode = "head",
    alternate_start = "tail",
    prefix = "<leader>m",
    dynamic_layer = true,
    keymaps = {
        step = false,
        step_back = false,
        toggle_all = false,
    },
}

M.config = vim.deepcopy(default_config)

---@type McLineState|nil
local state = nil

---Get current active state (read-only copy)
---@return McLineState|nil
function M.get_state()
    if not state then
        return nil
    end
    return vim.deepcopy(state)
end

---Check if a progressive session is currently active
---@return boolean
function M.is_active()
    return state ~= nil and state.active
end

---Reset internal session state
function M.reset()
    state = nil
end

---Calculate target column for a given line in the specified mode
---@param mode McLineMode
---@param line_nr integer 1-indexed line number
---@param line_index integer 1-indexed relative line index within target range
---@return integer col 1-indexed byte column
function M.get_col_for_line(mode, line_nr, line_index)
    local line_str = vim.api.nvim_buf_get_lines(0, line_nr - 1, line_nr, true)[1] or ""
    local max_col = math.max(1, #line_str)

    if mode == "head" then
        return 1
    elseif mode == "tail" then
        return max_col
    elseif mode == "alternate" then
        local is_tail
        if M.config.alternate_start == "tail" then
            is_tail = (line_index % 2 == 1) -- 1: tail, 2: head, 3: tail, 4: head ...
        else
            is_tail = (line_index % 2 == 0) -- 1: head, 2: tail, 3: head, 4: tail ...
        end
        return is_tail and max_col or 1
    end
    return 1
end

---Resolve target line range based on options or current editor context
---@param opts? { start_line?: integer, end_line?: integer }
---@return integer start_line, integer end_line
local function resolve_range(opts)
    opts = opts or {}
    if opts.start_line and opts.end_line then
        return math.min(opts.start_line, opts.end_line), math.max(opts.start_line, opts.end_line)
    end

    local mode = vim.fn.mode()
    -- Visual mode range
    if mode:match("[vV\22]") then
        local vpos = vim.fn.getpos("v")
        local curpos = vim.fn.getpos(".")
        -- Exit visual mode to normal mode cleanly
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
        local s = math.min(vpos[2], curpos[2])
        local e = math.max(vpos[2], curpos[2])
        return s, e
    end

    local cur_line = vim.fn.line(".")
    local total_lines = vim.fn.line("$")

    -- If count was provided (e.g. 5:McLineHead or 5<leader>mh)
    if vim.v.count > 0 then
        return cur_line, math.min(total_lines, cur_line + vim.v.count - 1)
    end

    -- Default: from current line to buffer end
    return cur_line, total_lines
end

---Switch active mode
---@param mode McLineMode
function M.set_mode(mode)
    if mode ~= "head" and mode ~= "tail" and mode ~= "alternate" then
        error("multicursor-line: Invalid mode: " .. tostring(mode))
    end
    if state then
        state.mode = mode
    else
        M.config.default_mode = mode
    end
end

---Progressively append next line cursor down (corresponding to n or j)
---@param mode? McLineMode
---@param range? { start_line?: integer, end_line?: integer }
function M.step(mode, range)
    -- 1. Initialize session if not active
    if not state or not state.active then
        local s_line, e_line = resolve_range(range)
        local cur_mode = mode or (state and state.mode) or M.config.default_mode

        if mc.hasCursors() then
            mc.clearCursors()
        end

        state = {
            mode = cur_mode,
            start_line = s_line,
            end_line = e_line,
            current_line = s_line,
            active = true,
            is_all_selected = false,
        }

        mc.action(function(ctx)
            local main = ctx:mainCursor()
            local col = M.get_col_for_line(state.mode, state.start_line, 1)
            main:setPos({ state.start_line, col })
        end)
        return
    end

    if state.is_all_selected then
        vim.notify("multicursor-line: All lines already selected (press A to toggle)", vim.log.levels.INFO)
        return
    end

    -- 2. Check if reached boundary
    if state.current_line >= state.end_line then
        vim.notify("multicursor-line: Reached the end of target lines", vim.log.levels.INFO)
        return
    end

    -- 3. Append cursor at next line
    local next_line = state.current_line + 1
    local line_idx = next_line - state.start_line + 1
    local col = M.get_col_for_line(state.mode, next_line, line_idx)

    mc.action(function(ctx)
        local new_cur = ctx:addCursor()
        new_cur:setPos({ next_line, col })
        new_cur:select()
    end)

    state.current_line = next_line
    if state.current_line == state.end_line then
        state.is_all_selected = true
    end
end

---Step backward / remove the last added cursor (corresponding to p or k)
function M.step_back()
    if not state or not state.active then
        return
    end

    if state.is_all_selected then
        state.is_all_selected = false
    end

    if state.current_line > state.start_line then
        mc.action(function(ctx)
            ctx:mainCursor():delete()
        end)
        state.current_line = state.current_line - 1
    else
        vim.notify("multicursor-line: At the first line", vim.log.levels.INFO)
    end
end

---Cancel select-all and revert to a single cursor at start_line
function M.cancel_select_all()
    if not state then
        return
    end

    if mc.hasCursors() then
        mc.clearCursors()
    end

    mc.action(function(ctx)
        local main = ctx:mainCursor()
        local col = M.get_col_for_line(state.mode, state.start_line, 1)
        main:setPos({ state.start_line, col })
    end)

    state.current_line = state.start_line
    state.is_all_selected = false
end

---Select all lines in range at target positions instantaneously
---@param mode? McLineMode
---@param range? { start_line?: integer, end_line?: integer }
function M.select_all(mode, range)
    local s_line, e_line
    if state and state.active and not range then
        s_line = state.start_line
        e_line = state.end_line
    else
        s_line, e_line = resolve_range(range)
    end

    local cur_mode = mode or (state and state.mode) or M.config.default_mode

    if mc.hasCursors() then
        mc.clearCursors()
    end

    mc.action(function(ctx)
        local main = ctx:mainCursor()
        local line_idx = 1
        for l = s_line, e_line do
            local col = M.get_col_for_line(cur_mode, l, line_idx)
            if l == s_line then
                main:setPos({ l, col })
            else
                local cur = ctx:addCursor()
                cur:setPos({ l, col })
            end
            line_idx = line_idx + 1
        end
    end)

    state = {
        mode = cur_mode,
        start_line = s_line,
        end_line = e_line,
        current_line = e_line,
        active = true,
        is_all_selected = true,
    }
end

---Toggle select-all: if all lines selected, cancel back to line 1; otherwise select all
function M.toggle_all()
    if not state or not state.active then
        M.select_all()
        return
    end

    if state.is_all_selected then
        M.cancel_select_all()
    else
        M.select_all(state.mode)
    end
end

---Start a mode and trigger the first cursor
---@param mode McLineMode
---@param range? { start_line?: integer, end_line?: integer }
function M.start(mode, range)
    M.reset()
    M.step(mode, range)
end

---Clear all cursors and reset session state
function M.clear()
    M.reset()
    if mc.hasCursors() then
        mc.clearCursors()
    end
end

---Register user commands
local function register_commands()
    -- :McLine [head|tail|alternate] [step|all|toggle]
    vim.api.nvim_create_user_command("McLine", function(opts)
        local args = vim.split(opts.args, "%s+", { trimempty = true })
        local mode = args[1]
        local action = args[2] or "step"
        local range = nil
        if opts.range == 2 then
            range = { start_line = opts.line1, end_line = opts.line2 }
        end

        if action == "all" then
            M.select_all(mode, range)
        elseif action == "toggle" then
            M.toggle_all()
        else
            M.step(mode, range)
        end
    end, {
        range = true,
        nargs = "*",
        complete = function(_, cmd_line)
            local parts = vim.split(cmd_line, "%s+")
            if #parts <= 2 then
                return { "head", "tail", "alternate" }
            elseif #parts == 3 then
                return { "step", "all", "toggle" }
            end
            return {}
        end,
        desc = "Multicursor line generator (head/tail/alternate)",
    })

    vim.api.nvim_create_user_command("McLineHead", function(opts)
        local r = opts.range == 2 and { start_line = opts.line1, end_line = opts.line2 } or nil
        M.start("head", r)
    end, { range = true, desc = "Start line-head mode" })

    vim.api.nvim_create_user_command("McLineHeadAll", function(opts)
        local r = opts.range == 2 and { start_line = opts.line1, end_line = opts.line2 } or nil
        M.select_all("head", r)
    end, { range = true, desc = "Select all line heads" })

    vim.api.nvim_create_user_command("McLineTail", function(opts)
        local r = opts.range == 2 and { start_line = opts.line1, end_line = opts.line2 } or nil
        M.start("tail", r)
    end, { range = true, desc = "Start line-tail mode" })

    vim.api.nvim_create_user_command("McLineTailAll", function(opts)
        local r = opts.range == 2 and { start_line = opts.line1, end_line = opts.line2 } or nil
        M.select_all("tail", r)
    end, { range = true, desc = "Select all line tails" })

    vim.api.nvim_create_user_command("McLineAlt", function(opts)
        local r = opts.range == 2 and { start_line = opts.line1, end_line = opts.line2 } or nil
        M.start("alternate", r)
    end, { range = true, desc = "Start alternating head/tail mode" })

    vim.api.nvim_create_user_command("McLineAltAll", function(opts)
        local r = opts.range == 2 and { start_line = opts.line1, end_line = opts.line2 } or nil
        M.select_all("alternate", r)
    end, { range = true, desc = "Select all alternating head/tail" })

    vim.api.nvim_create_user_command("McLineClear", function()
        M.clear()
    end, { desc = "Clear multicursor line session" })
end

---Setup plugin
---@param opts? McLineConfig
function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", default_config, opts or {})
    register_commands()

    local augroup = vim.api.nvim_create_augroup("MulticursorLineSession", { clear = true })

    -- Reset state if buffer or window changes
    vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
        group = augroup,
        callback = function()
            M.reset()
        end,
    })

    -- When entering insert mode, complete session setup so j/k/n/p return to normal afterwards
    vim.api.nvim_create_autocmd("ModeChanged", {
        group = augroup,
        pattern = "*:i*",
        callback = function()
            if state and state.active then
                state.active = false
            end
        end,
    })

    local set = vim.keymap.set
    local prefix = M.config.prefix

    -- Starter keybindings
    if prefix and prefix ~= "" then
        set({ "n", "x" }, prefix .. "h", function() M.start("head") end, { desc = "MC-Line: Head mode" })
        set({ "n", "x" }, prefix .. "t", function() M.start("tail") end, { desc = "MC-Line: Tail mode" })
        set({ "n", "x" }, prefix .. "a", function() M.start("alternate") end, { desc = "MC-Line: Alternate mode" })

        set({ "n", "x" }, prefix .. "H", function() M.select_all("head") end, { desc = "MC-Line: Select all heads" })
        set({ "n", "x" }, prefix .. "T", function() M.select_all("tail") end, { desc = "MC-Line: Select all tails" })
        set({ "n", "x" }, prefix .. "A", function() M.select_all("alternate") end, { desc = "MC-Line: Select all alternate" })
    end

    -- Interactive dynamic layer: single-key navigation during active line session
    if M.config.dynamic_layer then
        mc.addKeymapLayer(function(layerSet)
            -- Step down: n or j
            layerSet({ "n", "x" }, "j", function()
                if state and state.active then
                    M.step()
                else
                    vim.cmd("normal! j")
                end
            end)
            layerSet({ "n", "x" }, "n", function()
                if state and state.active then
                    M.step()
                else
                    vim.cmd("normal! n")
                end
            end)

            -- Step back / up: k or p
            layerSet({ "n", "x" }, "k", function()
                if state and state.active then
                    M.step_back()
                else
                    vim.cmd("normal! k")
                end
            end)
            layerSet({ "n", "x" }, "p", function()
                if state and state.active then
                    M.step_back()
                else
                    vim.cmd("normal! p")
                end
            end)

            -- Toggle select-all: A
            layerSet({ "n", "x" }, "A", function()
                if state and state.active then
                    M.toggle_all()
                else
                    vim.cmd("normal! A")
                end
            end)

            -- Cancel session
            layerSet({ "n", "x" }, "q", function()
                M.clear()
            end)
            layerSet("n", "<Esc>", function()
                M.clear()
            end)

            -- Optional extra keybindings if user explicitly configured them
            if M.config.keymaps.step then
                layerSet({ "n", "x" }, M.config.keymaps.step, function()
                    M.step()
                end)
            end
            if M.config.keymaps.step_back then
                layerSet({ "n", "x" }, M.config.keymaps.step_back, function()
                    M.step_back()
                end)
            end
            if M.config.keymaps.toggle_all then
                layerSet({ "n", "x" }, M.config.keymaps.toggle_all, function()
                    M.toggle_all()
                end)
            end
        end)
    end
end

return M

local M = {}

---@alias McLineMode "head" | "tail" | "alternate"
---@alias McBackend "vm" | "multicursor"

---@class McLineState
---@field mode McLineMode
---@field min_line integer
---@field max_line integer
---@field count integer

---@class McLineConfig
---@field backend "auto" | "vm" | "multicursor"
---@field alternate_start "tail" | "head"
---@field prefix string

---@type McLineConfig
local default_config = {
    backend = "auto",
    alternate_start = "tail",
    prefix = "<leader>m",
}

M.config = vim.deepcopy(default_config)

---@type McLineState|nil
local state = nil

---Detect available multi-cursor engine
---@return McBackend
local function get_backend()
    if M.config.backend == "vm" or M.config.backend == "multicursor" then
        return M.config.backend
    end
    -- Auto detection: prefer vim-visual-multi for live real-time typing
    if vim.fn.exists("*vm#commands#add_cursor_at_pos") == 1 or package.loaded["vim-visual-multi"] or vim.g.loaded_visual_multi then
        return "vm"
    end
    local ok, _ = pcall(require, "multicursor-nvim")
    if ok then
        return "multicursor"
    end
    return "vm"
end

---Reset state
function M.reset()
    state = nil
end

---Check if VM or multicursor has active cursors
local function has_active_cursors()
    local b = get_backend()
    if b == "vm" then
        return vim.b.visual_multi == 1
    else
        local ok, mc = pcall(require, "multicursor-nvim")
        return ok and mc.hasCursors()
    end
end

---Clear active cursors
function M.clear()
    M.reset()
    local b = get_backend()
    if b == "vm" then
        if vim.b.visual_multi == 1 then
            pcall(vim.fn["vm#reset"])
        end
    else
        local ok, mc = pcall(require, "multicursor-nvim")
        if ok and mc.hasCursors() then
            mc.clearCursors()
        end
    end
end

---Calculate column for a line
---@param mode McLineMode
---@param line_nr integer 1-indexed
---@param line_index integer 1-indexed
---@return integer col_0_indexed 0-indexed column
function M.get_col(mode, line_nr, line_index)
    local line_str = vim.api.nvim_buf_get_lines(0, line_nr - 1, line_nr, true)[1] or ""
    local max_col = math.max(0, #line_str - 1)

    if mode == "head" then
        return 0
    elseif mode == "tail" then
        return max_col
    elseif mode == "alternate" then
        local is_tail
        if M.config.alternate_start == "tail" then
            is_tail = (line_index % 2 == 1)
        else
            is_tail = (line_index % 2 == 0)
        end
        return is_tail and max_col or 0
    end
    return 0
end

---Add a cursor at line and 0-indexed column
---@param line integer 1-indexed
---@param col integer 0-indexed
local function add_cursor_at(line, col)
    local b = get_backend()
    if b == "vm" then
        vim.api.nvim_win_set_cursor(0, { line, col })
        vim.fn["vm#commands#add_cursor_at_pos"](0)
    else
        local mc = require("multicursor-nvim")
        mc.action(function(ctx)
            if not mc.hasCursors() then
                local main = ctx:mainCursor()
                main:setPos({ line, col + 1 })
            else
                local cur = ctx:addCursor()
                cur:setPos({ line, col + 1 })
                cur:select()
            end
        end)
    end
end

---Add cursor down (向下选)
---@param mode McLineMode
function M.step_down(mode)
    local total = vim.fn.line("$")
    if not state or not has_active_cursors() then
        local cur = vim.fn.line(".")
        local c1 = M.get_col(mode, cur, 1)
        add_cursor_at(cur, c1)

        local next_line = math.min(total, cur + 1)
        if next_line > cur then
            local c2 = M.get_col(mode, next_line, 2)
            add_cursor_at(next_line, c2)
            state = { mode = mode, min_line = cur, max_line = next_line, count = 2 }
        else
            state = { mode = mode, min_line = cur, max_line = cur, count = 1 }
        end
        return
    end

    if state.max_line >= total then
        vim.notify("multicursor-line: 已到文件末尾", vim.log.levels.INFO)
        return
    end

    state.max_line = state.max_line + 1
    state.count = state.count + 1
    local c = M.get_col(state.mode, state.max_line, state.count)
    add_cursor_at(state.max_line, c)
end

---Add cursor up (向上选)
---@param mode McLineMode
function M.step_up(mode)
    if not state or not has_active_cursors() then
        local cur = vim.fn.line(".")
        local c1 = M.get_col(mode, cur, 1)
        add_cursor_at(cur, c1)

        local prev_line = math.max(1, cur - 1)
        if prev_line < cur then
            local c2 = M.get_col(mode, prev_line, 2)
            add_cursor_at(prev_line, c2)
            state = { mode = mode, min_line = prev_line, max_line = cur, count = 2 }
        else
            state = { mode = mode, min_line = cur, max_line = cur, count = 1 }
        end
        return
    end

    if state.min_line <= 1 then
        vim.notify("multicursor-line: 已到文件起始行", vim.log.levels.INFO)
        return
    end

    state.min_line = state.min_line - 1
    state.count = state.count + 1
    local c = M.get_col(state.mode, state.min_line, state.count)
    add_cursor_at(state.min_line, c)
end

---Select all lines in range
---@param mode McLineMode
---@param s_line? integer
---@param e_line? integer
function M.select_all(mode, s_line, e_line)
    if not s_line or not e_line then
        local vmode = vim.fn.mode()
        if vmode:match("[vV\22]") then
            local vpos = vim.fn.getpos("v")
            local curpos = vim.fn.getpos(".")
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
            s_line = math.min(vpos[2], curpos[2])
            e_line = math.max(vpos[2], curpos[2])
        else
            -- Normal mode: from current line to buffer end (or whole buffer if count is 0)
            s_line = vim.fn.line(".")
            e_line = vim.fn.line("$")
        end
    end

    M.clear()

    local b = get_backend()
    if b == "vm" then
        local idx = 1
        for l = s_line, e_line do
            local c = M.get_col(mode, l, idx)
            add_cursor_at(l, c)
            idx = idx + 1
        end
    else
        local mc = require("multicursor-nvim")
        mc.action(function(ctx)
            local main = ctx:mainCursor()
            local idx = 1
            for l = s_line, e_line do
                local c = M.get_col(mode, l, idx)
                if l == s_line then
                    main:setPos({ l, c + 1 })
                else
                    local cur = ctx:addCursor()
                    cur:setPos({ l, c + 1 })
                end
                idx = idx + 1
            end
        end)
    end

    state = { mode = mode, min_line = s_line, max_line = e_line, count = e_line - s_line + 1 }
end

---Register user commands
local function register_commands()
    -- :McLineHead [down|up|all]
    vim.api.nvim_create_user_command("McLineHead", function(opts)
        local action = opts.args ~= "" and opts.args or (opts.range == 2 and "all" or "down")
        if action == "all" then
            local s = opts.range == 2 and opts.line1 or nil
            local e = opts.range == 2 and opts.line2 or nil
            M.select_all("head", s, e)
        elseif action == "up" then
            M.step_up("head")
        else
            M.step_down("head")
        end
    end, { range = true, nargs = "?" })

    -- :McLineTail [down|up|all]
    vim.api.nvim_create_user_command("McLineTail", function(opts)
        local action = opts.args ~= "" and opts.args or (opts.range == 2 and "all" or "down")
        if action == "all" then
            local s = opts.range == 2 and opts.line1 or nil
            local e = opts.range == 2 and opts.line2 or nil
            M.select_all("tail", s, e)
        elseif action == "up" then
            M.step_up("tail")
        else
            M.step_down("tail")
        end
    end, { range = true, nargs = "?" })

    -- :McLineAlt [down|up|all]
    vim.api.nvim_create_user_command("McLineAlt", function(opts)
        local action = opts.args ~= "" and opts.args or (opts.range == 2 and "all" or "down")
        if action == "all" then
            local s = opts.range == 2 and opts.line1 or nil
            local e = opts.range == 2 and opts.line2 or nil
            M.select_all("alternate", s, e)
        elseif action == "up" then
            M.step_up("alternate")
        else
            M.step_down("alternate")
        end
    end, { range = true, nargs = "?" })

    vim.api.nvim_create_user_command("McLineClear", function()
        M.clear()
    end, {})
end

---Setup plugin
---@param opts? McLineConfig
function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", default_config, opts or {})
    register_commands()

    local set = vim.keymap.set
    local p = M.config.prefix

    -- 1. 行首模式 (Head)
    set("n", p .. "j", function() M.step_down("head") end, { desc = "行首: 向下加一行光标" })
    set("n", p .. "k", function() M.step_up("head") end, { desc = "行首: 向上加一行光标" })
    set({ "n", "x" }, p .. "h", function() M.select_all("head") end, { desc = "行首: 全选 (选区或全段)" })

    -- 2. 行尾模式 (Tail)
    set("n", p .. "l", function() M.step_down("tail") end, { desc = "行尾: 向下加一行光标" })
    set("n", p .. "L", function() M.step_up("tail") end, { desc = "行尾: 向上加一行光标" })
    set({ "n", "x" }, p .. "t", function() M.select_all("tail") end, { desc = "行尾: 全选 (选区或全段)" })

    -- 3. 首尾交替模式 (Alternate)
    set("n", p .. "n", function() M.step_down("alternate") end, { desc = "交替: 向下加一行光标" })
    set("n", p .. "p", function() M.step_up("alternate") end, { desc = "交替: 向上加一行光标" })
    set({ "n", "x" }, p .. "a", function() M.select_all("alternate") end, { desc = "交替: 全选 (选区或全段)" })
end

return M

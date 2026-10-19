local M = {}

---@alias McLineMode "head" | "tail" | "alternate"
---@alias McBackend "vm" | "multicursor"

---@class McLineKeymaps
---@field head string
---@field tail string
---@field alternate string

---@class McLineConfig
---@field backend "auto" | "vm" | "multicursor"
---@field alternate_start "tail" | "head"
---@field create_keymaps boolean
---@field visual_keys McLineKeymaps
---@field normal_keys McLineKeymaps

---@type McLineConfig
local default_config = {
    backend = "auto",
    alternate_start = "tail",
    create_keymaps = true,
    visual_keys = {
        head = "<leader>h",
        tail = "<leader>t",
        alternate = "<leader>a",
    },
    normal_keys = {
        head = "<leader>mh",
        tail = "<leader>mt",
        alternate = "<leader>ma",
    },
}

M.config = vim.deepcopy(default_config)

---Detect available multi-cursor engine
---@return McBackend
local function get_backend()
    if M.config.backend == "vm" or M.config.backend == "multicursor" then
        return M.config.backend
    end
    if vim.fn.exists("*vm#commands#add_cursor_at_pos") == 1 or package.loaded["vim-visual-multi"] or vim.g.loaded_visual_multi then
        return "vm"
    end
    local ok, _ = pcall(require, "multicursor-nvim")
    if ok then
        return "multicursor"
    end
    return "vm"
end

---Clear active cursors
function M.clear()
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
---@param line_index integer 1-indexed (position in selection: 1, 2, 3...)
---@param is_block? boolean
---@param s_col? integer 0-indexed block start col
---@param e_col? integer 0-indexed block end col
---@return integer col_0_indexed 0-indexed column
function M.get_col(mode, line_nr, line_index, is_block, s_col, e_col)
    local line_str = vim.api.nvim_buf_get_lines(0, line_nr - 1, line_nr, true)[1] or ""
    local max_col = math.max(0, #line_str - 1)

    if is_block and s_col and e_col then
        local left = math.min(s_col, max_col)
        local right = math.min(e_col, max_col)
        if mode == "head" then
            return left
        elseif mode == "tail" then
            return right
        elseif mode == "alternate" then
            local is_tail
            if M.config.alternate_start == "tail" then
                is_tail = (line_index % 2 == 1)
            else
                is_tail = (line_index % 2 == 0)
            end
            return is_tail and right or left
        end
    else
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

---Apply multi-cursor mode to current selection or range
---@param mode McLineMode
---@param opts? { line1?: integer, line2?: integer }
function M.apply(mode, opts)
    local cur_mode = vim.fn.mode()
    local is_visual = cur_mode:match("[vV\22]") ~= nil

    local s_line, e_line
    local is_block = false
    local s_col, e_col

    if is_visual then
        -- Read visual mode selection endpoints
        local p_v = vim.fn.getpos("v")
        local p_c = vim.fn.getpos(".")
        -- Exit visual mode
        local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
        vim.api.nvim_feedkeys(esc, "nx", false)

        s_line = math.min(p_v[2], p_c[2])
        e_line = math.max(p_v[2], p_c[2])
        s_col = math.min(p_v[3], p_c[3]) - 1
        e_col = math.max(p_v[3], p_c[3]) - 1
        is_block = (cur_mode == "\22" or cur_mode == "<C-v>")
    elseif opts and opts.line1 and opts.line2 then
        s_line = opts.line1
        e_line = opts.line2
    else
        local cur = vim.fn.line(".")
        local count = vim.v.count
        s_line = cur
        e_line = (count > 1) and (cur + count - 1) or cur
    end

    -- Clear any previous multi-cursor instance
    M.clear()

    local b = get_backend()
    if b == "vm" then
        local idx = 1
        for l = s_line, e_line do
            local col = M.get_col(mode, l, idx, is_block, s_col, e_col)
            add_cursor_at(l, col)
            idx = idx + 1
        end
    else
        local mc = require("multicursor-nvim")
        mc.action(function(ctx)
            local main = ctx:mainCursor()
            local idx = 1
            for l = s_line, e_line do
                local col = M.get_col(mode, l, idx, is_block, s_col, e_col)
                if l == s_line then
                    main:setPos({ l, col + 1 })
                else
                    local cur = ctx:addCursor()
                    cur:setPos({ l, col + 1 })
                    cur:select()
                end
                idx = idx + 1
            end
        end)
    end

    local title = mode == "head" and "行首" or (mode == "tail" and "行尾" or "首尾交替")
    local count = e_line - s_line + 1
    vim.api.nvim_echo({
        { string.format("-- 多光标 [%s] (%d 行) -- ", title, count), "ModeMsg" },
        { "i/a: 输入 | c: 替换 | Esc: 退出", "Comment" },
    }, false, {})
end

---Head mode (行首加光标)
---@param opts? { line1?: integer, line2?: integer }
function M.head(opts)
    M.apply("head", opts)
end

---Tail mode (行尾加光标)
---@param opts? { line1?: integer, line2?: integer }
function M.tail(opts)
    M.apply("tail", opts)
end

---Alternate mode (首尾交替加光标)
---@param opts? { line1?: integer, line2?: integer }
function M.alternate(opts)
    M.apply("alternate", opts)
end

---Backward compatibility helper
---@param mode McLineMode
---@param s_line? integer
---@param e_line? integer
function M.select_all(mode, s_line, e_line)
    M.apply(mode, { line1 = s_line, line2 = e_line })
end

---Register user commands
local function register_commands()
    vim.api.nvim_create_user_command("McLineHead", function(opts)
        M.apply("head", { line1 = opts.line1, line2 = opts.line2 })
    end, { range = true, desc = "多光标: 行首加光标" })

    vim.api.nvim_create_user_command("McLineTail", function(opts)
        M.apply("tail", { line1 = opts.line1, line2 = opts.line2 })
    end, { range = true, desc = "多光标: 行尾加光标" })

    vim.api.nvim_create_user_command("McLineAlt", function(opts)
        M.apply("alternate", { line1 = opts.line1, line2 = opts.line2 })
    end, { range = true, desc = "多光标: 首尾交替加光标" })

    vim.api.nvim_create_user_command("McLineClear", function()
        M.clear()
    end, { desc = "多光标: 清除所有光标" })
end

---Setup plugin
---@param opts? McLineConfig
function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", default_config, opts or {})
    register_commands()

    if not M.config.create_keymaps then
        return
    end

    local set = vim.keymap.set
    local v = M.config.visual_keys
    local n = M.config.normal_keys

    -- Visual Mode mappings (快速 2 键触发)
    if v.head and v.head ~= "" then
        set("x", v.head, function() M.apply("head") end, { desc = "多光标: 选中行首加光标" })
    end
    if v.tail and v.tail ~= "" then
        set("x", v.tail, function() M.apply("tail") end, { desc = "多光标: 选中行尾加光标" })
    end
    if v.alternate and v.alternate ~= "" then
        set("x", v.alternate, function() M.apply("alternate") end, { desc = "多光标: 选中首尾交替加光标" })
    end

    -- Visual Mode 别名（兼容 <leader>m 助记分组）
    set("x", "<leader>mh", function() M.apply("head") end, { desc = "多光标: 选中行首加光标" })
    set("x", "<leader>mt", function() M.apply("tail") end, { desc = "多光标: 选中行尾加光标" })
    set("x", "<leader>ma", function() M.apply("alternate") end, { desc = "多光标: 选中首尾交替加光标" })

    -- Normal Mode mappings (支持数字前缀例如 5<leader>mh)
    if n.head and n.head ~= "" then
        set("n", n.head, function() M.apply("head") end, { desc = "多光标: 行首加光标" })
    end
    if n.tail and n.tail ~= "" then
        set("n", n.tail, function() M.apply("tail") end, { desc = "多光标: 行尾加光标" })
    end
    if n.alternate and n.alternate ~= "" then
        set("n", n.alternate, function() M.apply("alternate") end, { desc = "多光标: 首尾交替加光标" })
    end
end

return M

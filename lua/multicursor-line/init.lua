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

---Clean up temporary submode keymaps
---@param bufnr? integer
function M.cleanup_submode(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end

    local keys = { "i", "a", "c", "s", "<Esc>" }
    for _, k in ipairs(keys) do
        pcall(vim.keymap.del, "n", k, { buffer = bufnr })
    end
end

---Clear active cursors
function M.clear()
    M.cleanup_submode()
    local b = get_backend()
    if b == "vm" then
        if vim.b.visual_multi == 1 then
            pcall(vim.cmd, "call b:VM_Selection.Edit.extra_spaces.remove()")
            pcall(vim.fn["vm#reset"])
        end
    else
        local ok, mc = pcall(require, "multicursor-nvim")
        if ok and mc.hasCursors() then
            mc.clearCursors()
        end
    end
end

---Check if line is tail or head in current mode
---@param mode McLineMode
---@param line_index integer 1-indexed
---@return boolean is_tail
function M.is_tail_line(mode, line_index)
    if mode == "tail" then
        return true
    elseif mode == "head" then
        return false
    elseif mode == "alternate" then
        if M.config.alternate_start == "tail" then
            return (line_index % 2 == 1)
        else
            return (line_index % 2 == 0)
        end
    end
    return false
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
    local bufnr = vim.api.nvim_get_current_buf()

    if b == "vm" then
        local line_index = 1
        for l = s_line, e_line do
            local line_str = vim.api.nvim_buf_get_lines(bufnr, l - 1, l, true)[1] or ""
            local len = #line_str
            local is_tail = M.is_tail_line(mode, line_index)

            if is_tail then
                if is_block then
                    if (e_col + 1) < len then
                        -- Position directly after block right edge inside text
                        vim.api.nvim_win_set_cursor(0, { l, e_col + 1 })
                        vim.fn["vm#commands#add_cursor_at_pos"](0)
                    else
                        -- Position at EOL using VM extra_spaces
                        vim.api.nvim_win_set_cursor(0, { l, math.max(0, len - 1) })
                        vim.fn["vm#commands#add_cursor_at_pos"](0)
                        local r_idx = #vim.b.VM_Selection.Regions - 1
                        vim.cmd(string.format([[
                            call b:VM_Selection.Edit.extra_spaces.add(b:VM_Selection.Regions[%d])
                            let b:VM_Selection.Regions[%d].a = b:VM_Selection.Regions[%d].a + 1
                            let b:VM_Selection.Regions[%d].b = b:VM_Selection.Regions[%d].b + 1
                        ]], r_idx, r_idx, r_idx, r_idx, r_idx))
                    end
                else
                    -- Linewise tail: place at EOL and add extra space so cursor is truly past line end
                    vim.api.nvim_win_set_cursor(0, { l, math.max(0, len - 1) })
                    vim.fn["vm#commands#add_cursor_at_pos"](0)
                    local r_idx = #vim.b.VM_Selection.Regions - 1
                    vim.cmd(string.format([[
                        call b:VM_Selection.Edit.extra_spaces.add(b:VM_Selection.Regions[%d])
                        let b:VM_Selection.Regions[%d].a = b:VM_Selection.Regions[%d].a + 1
                        let b:VM_Selection.Regions[%d].b = b:VM_Selection.Regions[%d].b + 1
                    ]], r_idx, r_idx, r_idx, r_idx, r_idx))
                end
            else
                -- Head: position at line start or block left edge
                local col = is_block and math.min(s_col, math.max(0, len - 1)) or 0
                vim.api.nvim_win_set_cursor(0, { l, col })
                vim.fn["vm#commands#add_cursor_at_pos"](0)
            end

            line_index = line_index + 1
        end

        -- Map i, a, c, s so pressing any of them starts insert at the exact target positions
        local function start_insert()
            M.cleanup_submode(bufnr)
            vim.cmd("call b:VM_Selection.Insert.key('i')")
        end

        local kopts = { buffer = bufnr, nowait = true }
        vim.keymap.set("n", "i", start_insert, kopts)
        vim.keymap.set("n", "a", start_insert, kopts)
        vim.keymap.set("n", "c", start_insert, kopts)
        vim.keymap.set("n", "s", start_insert, kopts)
        vim.keymap.set("n", "<Esc>", function()
            M.clear()
        end, kopts)
    else
        local mc = require("multicursor-nvim")
        pcall(function() vim.opt.virtualedit = "onemore" end)
        mc.action(function(ctx)
            local main = ctx:mainCursor()
            local line_index = 1
            for l = s_line, e_line do
                local line_str = vim.api.nvim_buf_get_lines(bufnr, l - 1, l, true)[1] or ""
                local len = #line_str
                local is_tail = M.is_tail_line(mode, line_index)
                local col_1_indexed

                if is_tail then
                    if is_block then
                        col_1_indexed = math.min(e_col + 2, len + 1)
                    else
                        col_1_indexed = len + 1
                    end
                else
                    col_1_indexed = is_block and (math.min(s_col, math.max(0, len - 1)) + 1) or 1
                end

                if l == s_line then
                    main:setPos({ l, col_1_indexed })
                else
                    local cur = ctx:addCursor()
                    cur:setPos({ l, col_1_indexed })
                    cur:select()
                end
                line_index = line_index + 1
            end
        end)
    end

    local title = mode == "head" and "行首" or (mode == "tail" and "行尾" or "首尾交替")
    local count = e_line - s_line + 1
    vim.api.nvim_echo({
        { string.format("-- 多光标 [%s] (%d 行) -- ", title, count), "ModeMsg" },
        { "直接按 i / a 开始输入 | Esc 退出", "Comment" },
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

    -- Autocommands to prevent keymap leakage
    local grp = vim.api.nvim_create_augroup("MulticursorLineCleanup", { clear = true })
    vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
        group = grp,
        callback = function(ev)
            M.cleanup_submode(ev.buf)
        end,
    })

    if not M.config.create_keymaps then
        return
    end

    local set = vim.keymap.set
    local v = M.config.visual_keys
    local n = M.config.normal_keys

    -- Visual Mode mappings (快速 2 键触发)
    if v.head and v.head ~= "" then
        set("x", v.head, function() M.apply("head") end, { desc = "多光标: 选区行首/左边缘加光标" })
    end
    if v.tail and v.tail ~= "" then
        set("x", v.tail, function() M.apply("tail") end, { desc = "多光标: 选区行尾/右边缘加光标" })
    end
    if v.alternate and v.alternate ~= "" then
        set("x", v.alternate, function() M.apply("alternate") end, { desc = "多光标: 选区首尾/左右交替加光标" })
    end

    -- Visual Mode 别名（兼容 <leader>m 助记分组）
    set("x", "<leader>mh", function() M.apply("head") end, { desc = "多光标: 选区行首加光标" })
    set("x", "<leader>mt", function() M.apply("tail") end, { desc = "多光标: 选区行尾加光标" })
    set("x", "<leader>ma", function() M.apply("alternate") end, { desc = "多光标: 选区首尾交替加光标" })

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

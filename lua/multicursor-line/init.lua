local M = {}
local native_stop
local cursor_ns = vim.api.nvim_create_namespace("multicursor-line-cursors")

---@alias McLineMode "head" | "bol" | "tail" | "alternate" | "alternate_bol"
---@alias McBackend "native" | "vm" | "multicursor"

---@class McLineKeymaps
---@field head string
---@field bol string
---@field tail string
---@field alternate string
---@field alternate_bol string

---@class McLineConfig
---@field backend "native" | "auto" | "vm" | "multicursor"
---@field alternate_start "tail" | "head"
---@field create_keymaps boolean
---@field visual_keys McLineKeymaps
---@field normal_keys McLineKeymaps

---@type McLineConfig
local default_config = {
    backend = "native",
    alternate_start = "tail",
    create_keymaps = true,
    visual_keys = {
        head = "<leader>h",           -- 每行首个非空字符前（跳过缩进）
        bol = "<leader>H",            -- 绝对行首（第 0 列，包含缩进）
        tail = "<leader>t",           -- 行尾
        alternate = "<leader>a",       -- 首尾交替（智能首字符前 <-> 行尾）
        alternate_bol = "<leader>A",   -- 首尾交替（绝对行首 <-> 行尾）
    },
    normal_keys = {
        head = "<leader>mh",
        bol = "<leader>mH",
        tail = "<leader>mt",
        alternate = "<leader>ma",
        alternate_bol = "<leader>mA",
    },
}

M.config = vim.deepcopy(default_config)

---Detect available multi-cursor engine
---@return McBackend
local function get_backend()
    if M.config.backend == "vm" or M.config.backend == "multicursor" or M.config.backend == "native" then
        return M.config.backend
    end
    -- The native backend edits every selected line with one Neovim command, so
    -- it stays responsive with thousands of cursors. vim-visual-multi creates
    -- a highlight match per cursor, which becomes unusable on large ranges.
    return "native"
end

---Clean up temporary submode keymaps
---@param bufnr? integer
function M.cleanup_submode(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end

    local keys = { "i", "a", "c", "s", "<Esc>", "<C-c>" }
    for _, k in ipairs(keys) do
        pcall(vim.keymap.del, "n", k, { buffer = bufnr })
    end
end

---Clear active cursors
---@param bufnr? integer
function M.clear(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    M.cleanup_submode(bufnr)
    local b = get_backend()
    if b == "native" then
        native_stop()
        return
    end
    if b == "vm" then
        local is_vm = false
        if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
            is_vm = (vim.b[bufnr].visual_multi == 1 or vim.b[bufnr].visual_multi == true)
        end
        if not is_vm then
            is_vm = (vim.b.visual_multi == 1 or vim.b.visual_multi == true or vim.fn.exists("b:visual_multi") == 1)
        end
        if is_vm then
            pcall(vim.cmd, "silent! call b:VM_Selection.Edit.extra_spaces.remove()")
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
    elseif mode == "head" or mode == "bol" then
        return false
    elseif mode == "alternate" or mode == "alternate_bol" then
        if M.config.alternate_start == "tail" then
            return (line_index % 2 == 1)
        else
            return (line_index % 2 == 0)
        end
    end
    return false
end

---Calculate head column for a line
---@param mode McLineMode
---@param line_str string
---@param is_block boolean
---@param s_col integer 0-indexed block left edge
---@return integer col 0-indexed
function M.get_head_column(mode, line_str, is_block, s_col)
    local len = #line_str
    local max_col = math.max(0, len - 1)
    if is_block then
        return math.min(s_col, max_col)
    end
    if mode == "bol" or mode == "alternate_bol" then
        return 0
    else
        -- "head" / "alternate": first non-blank character
        local indent = line_str:match("^%s*") or ""
        return math.min(#indent, max_col)
    end
end

---@class McNativePosition
---@field line integer
---@field col integer
---@field applied integer

---Native backend state: one insertion point per selected line.
local native = {
    bufnr = nil,
    positions = {},
    active = false,
    main = 1,
    augroup = nil,
}

---Draw every insertion point with one batched pass.
local function native_draw()
    if not native.bufnr or not vim.api.nvim_buf_is_valid(native.bufnr) then
        return
    end
    vim.api.nvim_buf_clear_namespace(native.bufnr, cursor_ns, 0, -1)
    for _, p in ipairs(native.positions) do
        local ok = pcall(vim.api.nvim_buf_set_extmark, native.bufnr, cursor_ns, p.line - 1, p.col + p.applied, {
            virt_text = { { "│", "MultiCursor" } },
            virt_text_pos = "overlay",
            priority = 120,
        })
        if not ok then
            native.positions = {}
            return
        end
    end
end

---Compute insertion points for the native backend.
---@param mode McLineMode
---@param s_line integer
---@param e_line integer
---@param is_block boolean
---@param s_col integer
---@param e_col integer
---@return McNativePosition[]
local function native_positions(mode, s_line, e_line, is_block, s_col, e_col)
    local bufnr = vim.api.nvim_get_current_buf()
    local positions = {}
    local line_index = 1
    for l = s_line, e_line do
        local line_str = vim.api.nvim_buf_get_lines(bufnr, l - 1, l, true)[1] or ""
        local len = #line_str
        local col
        if M.is_tail_line(mode, line_index) then
            col = is_block and math.min(e_col + 1, len) or len
        else
            col = M.get_head_column(mode, line_str, is_block, s_col)
        end
        positions[#positions + 1] = { line = l, col = col, applied = 0 }
        line_index = line_index + 1
    end
    return positions
end

---Apply the text typed at the main cursor to every other line. The editor's
---own change events are used instead of an insert-mode <BS> mapping, because
---completion plugins install their own <BS> mapping and would shadow it.
local function native_sync_insert()
    if not native.active then
        return
    end
    local bufnr = native.bufnr
    local main = native.positions[native.main]
    if not main then
        return
    end
    local cursor = vim.api.nvim_win_get_cursor(0)
    if cursor[1] ~= main.line then
        return
    end
    local current = vim.api.nvim_buf_get_lines(bufnr, main.line - 1, main.line, false)[1] or ""
    local inserted = current:sub(main.col + 1, cursor[2])
    local shrank = native.main_len ~= nil and #current < native.main_len
    native.main_len = #current
    for i, p in ipairs(native.positions) do
        if i ~= native.main then
            local row = p.line - 1
            if #inserted >= p.applied then
                local delta = inserted:sub(p.applied + 1)
                if delta ~= "" then
                    pcall(vim.api.nvim_buf_set_text, bufnr, row, p.col + p.applied, row, p.col + p.applied, { delta })
                end
            else
                pcall(vim.api.nvim_buf_set_text, bufnr, row, p.col, row, p.col + p.applied, { inserted })
            end
            if #inserted == 0 and shrank and p.col > 0 then
                pcall(vim.api.nvim_buf_set_text, bufnr, row, p.col - 1, row, p.col, {})
                p.col = p.col - 1
            end
        end
        p.applied = #inserted
    end
    native_draw()
end

---End the native editing session and clean up its keymaps.
native_stop = function()
    native.active = false
    if native.augroup then
        pcall(vim.api.nvim_del_augroup_by_id, native.augroup)
        native.augroup = nil
    end
    if native.bufnr and vim.api.nvim_buf_is_valid(native.bufnr) then
        vim.api.nvim_buf_clear_namespace(native.bufnr, cursor_ns, 0, -1)
    end
    native.positions = {}
end

---Start live editing
local function native_start_insert()
    local bufnr = native.bufnr
    if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) or #native.positions == 0 then
        return
    end
    local current_line = vim.api.nvim_win_get_cursor(0)[1]
    native.main = 1
    for i, p in ipairs(native.positions) do
        if p.line == current_line then
            native.main = i
            break
        end
    end
    local main = native.positions[native.main]
    vim.api.nvim_win_set_cursor(0, { main.line, main.col })
    native.active = true
    native.augroup = vim.api.nvim_create_augroup("McLineNativeInsert", { clear = true })
    vim.api.nvim_create_autocmd("TextChangedI", {
        group = native.augroup,
        buffer = bufnr,
        callback = native_sync_insert,
    })
    vim.api.nvim_create_autocmd("InsertLeave", {
        group = native.augroup,
        buffer = bufnr,
        callback = function()
            native_stop()
        end,
    })
    native.main_len = nil
    vim.cmd("startinsert")
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

    if b == "native" then
        native_stop()
        native.bufnr = bufnr
        native.positions = native_positions(mode, s_line, e_line, is_block, s_col, e_col)
        native_draw()

        local kopts = { buffer = bufnr, nowait = true }
        for _, k in ipairs({ "i", "a", "c", "s" }) do
            vim.keymap.set("n", k, function()
                native_start_insert()
            end, kopts)
        end
        vim.keymap.set("n", "<Esc>", function()
            native_stop()
        end, kopts)
        vim.keymap.set("n", "<C-c>", function()
            native_stop()
        end, kopts)
    elseif b == "vm" then
        vim.fn["vm#init_buffer"](1)
        vim.fn["vm#commands#init"]()
        local vm_vars = vim.b.VM_Selection.Vars
        local old_eco = vm_vars.eco
        vm_vars.eco = 1
        local tail_eol_region_indices = {}
        local line_index = 1

        for l = s_line, e_line do
            local line_str = vim.api.nvim_buf_get_lines(bufnr, l - 1, l, true)[1] or ""
            local len = #line_str
            local is_tail = M.is_tail_line(mode, line_index)

            if is_tail then
                if is_block then
                    if (e_col + 1) < len then
                        -- Position directly after block right edge inside existing line text
                        vim.api.nvim_win_set_cursor(0, { l, e_col + 1 })
                        vim.fn["vm#commands#add_cursor_at_pos"](0)
                    else
                        -- At or past line end: position on last char in normal mode without modifying buffer
                        vim.api.nvim_win_set_cursor(0, { l, math.max(0, len - 1) })
                        vim.fn["vm#commands#add_cursor_at_pos"](0)
                    end
                else
                    -- Linewise tail: position on last char in normal mode (no trailing space added!)
                    vim.api.nvim_win_set_cursor(0, { l, math.max(0, len - 1) })
                    vim.fn["vm#commands#add_cursor_at_pos"](0)
                end
            else
                -- Head: position at first non-blank or column 0
                local col = M.get_head_column(mode, line_str, is_block, s_col)
                vim.api.nvim_win_set_cursor(0, { l, col })
                vim.fn["vm#commands#add_cursor_at_pos"](0)
            end

            line_index = line_index + 1
        end

        vm_vars.eco = 1
        vim.b[bufnr].VM_Selection.Vars.eco = 1
        vim.api.nvim_buf_clear_namespace(bufnr, cursor_ns, 0, -1)
        vim.cmd("call b:VM_Selection.Global.remove_highlight()")
        -- Draw insertion points as a single extmark batch instead of one
        -- matchaddpos per cursor, which is quadratic for thousands of lines.
        for _, region in ipairs(vim.b[bufnr].VM_Selection.Regions) do
            pcall(vim.api.nvim_buf_set_extmark, bufnr, cursor_ns, region.l - 1, region.a - 1, {
                virt_text = { { "│", "MultiCursor" } },
                virt_text_pos = "overlay",
                priority = 120,
            })
        end

        -- Map i, a, c, s so pressing any of them starts insert mode at target positions
        local function start_insert()
            -- Unbind i, a, c, s from normal mode so native insert works,
            -- but KEEP <Esc> and <C-c> mapped!
            local edit_keys = { "i", "a", "c", "s" }
            for _, k in ipairs(edit_keys) do
                pcall(vim.keymap.del, "n", k, { buffer = bufnr })
            end

            -- Automatically clear multicursor when leaving insert mode
            vim.api.nvim_create_autocmd("InsertLeave", {
                buffer = bufnr,
                once = true,
                callback = function()
                    vim.schedule(function()
                        M.clear(bufnr)
                    end)
                end,
            })

            -- Only now, at the moment of typing, transition EOL tail cursors to insert mode
            for _, r_idx in ipairs(tail_eol_region_indices) do
                vim.cmd(string.format([[
                    call b:VM_Selection.Edit.extra_spaces.add(b:VM_Selection.Regions[%d])
                    let b:VM_Selection.Regions[%d].a = b:VM_Selection.Regions[%d].a + 1
                    let b:VM_Selection.Regions[%d].b = b:VM_Selection.Regions[%d].b + 1
                ]], r_idx, r_idx, r_idx, r_idx, r_idx))
            end
            vim.cmd("call b:VM_Selection.Insert.key('i')")
        end

        local kopts = { buffer = bufnr, nowait = true }
        vim.keymap.set("n", "i", start_insert, kopts)
        vim.keymap.set("n", "a", start_insert, kopts)
        vim.keymap.set("n", "c", start_insert, kopts)
        vim.keymap.set("n", "s", start_insert, kopts)
        vim.keymap.set("n", "<Esc>", function()
            M.clear(bufnr)
        end, kopts)
        vim.keymap.set("n", "<C-c>", function()
            M.clear(bufnr)
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
                    col_1_indexed = M.get_head_column(mode, line_str, is_block, s_col) + 1
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

        vim.api.nvim_create_autocmd("InsertLeave", {
            buffer = bufnr,
            once = true,
            callback = function()
                vim.schedule(function()
                    M.clear(bufnr)
                end)
            end,
        })
        local kopts = { buffer = bufnr, nowait = true }
        vim.keymap.set("n", "<Esc>", function()
            M.clear(bufnr)
        end, kopts)
        vim.keymap.set("n", "<C-c>", function()
            M.clear(bufnr)
        end, kopts)
    end

    local title_map = {
        head = "首字符前",
        bol = "绝对行首",
        tail = "行尾",
        alternate = "首尾交替(首字符前)",
        alternate_bol = "首尾交替(绝对行首)",
    }
    local title = title_map[mode] or mode
    local count = e_line - s_line + 1
    vim.api.nvim_echo({
        { string.format("-- 多光标 [%s] (%d 行) -- ", title, count), "ModeMsg" },
        { "直接按 i / a 开始输入 | Esc 退出", "Comment" },
    }, false, {})
end

---Head mode (每行首个非空字符前，跳过缩进)
---@param opts? { line1?: integer, line2?: integer }
function M.head(opts)
    M.apply("head", opts)
end

---BOL mode (绝对行首第 0 列，包含缩进)
---@param opts? { line1?: integer, line2?: integer }
function M.bol(opts)
    M.apply("bol", opts)
end

---Tail mode (行尾加光标)
---@param opts? { line1?: integer, line2?: integer }
function M.tail(opts)
    M.apply("tail", opts)
end

---Alternate mode (智能首尾交替：首字符前 <-> 行尾)
---@param opts? { line1?: integer, line2?: integer }
function M.alternate(opts)
    M.apply("alternate", opts)
end

---Alternate BOL mode (绝对首尾交替：绝对行首 <-> 行尾)
---@param opts? { line1?: integer, line2?: integer }
function M.alternate_bol(opts)
    M.apply("alternate_bol", opts)
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
    end, { range = true, desc = "多光标: 每行首个字符前加光标（跳过缩进）" })

    vim.api.nvim_create_user_command("McLineBol", function(opts)
        M.apply("bol", { line1 = opts.line1, line2 = opts.line2 })
    end, { range = true, desc = "多光标: 绝对行首第 0 列加光标（包含缩进）" })

    vim.api.nvim_create_user_command("McLineTail", function(opts)
        M.apply("tail", { line1 = opts.line1, line2 = opts.line2 })
    end, { range = true, desc = "多光标: 行尾加光标" })

    vim.api.nvim_create_user_command("McLineAlt", function(opts)
        M.apply("alternate", { line1 = opts.line1, line2 = opts.line2 })
    end, { range = true, desc = "多光标: 首尾交替（首字符前 <-> 行尾）" })

    vim.api.nvim_create_user_command("McLineAltBol", function(opts)
        M.apply("alternate_bol", { line1 = opts.line1, line2 = opts.line2 })
    end, { range = true, desc = "多光标: 首尾交替（绝对行首 <-> 行尾）" })

    vim.api.nvim_create_user_command("McLineClear", function()
        M.clear()
    end, { desc = "多光标: 清除所有光标" })
end

---Setup plugin
---@param opts? McLineConfig
function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", default_config, opts or {})
    M.cursor_namespace = cursor_ns
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

    -- Visual Mode mappings (快速触发)
    -- 1. 首字符前（智能代码首，跳过缩进）
    if v.head and v.head ~= "" then
        set("x", v.head, function() M.apply("head") end, { desc = "多光标: 每行首字符前加光标（跳过缩进）" })
    end
    set("x", "<leader>i", function() M.apply("head") end, { desc = "多光标: 每行首字符前加光标（跳过缩进）" })

    -- 2. 绝对行首（第 0 列，包含缩进）
    if v.bol and v.bol ~= "" then
        set("x", v.bol, function() M.apply("bol") end, { desc = "多光标: 绝对行首加光标（第 0 列）" })
    end
    set("x", "<leader>0", function() M.apply("bol") end, { desc = "多光标: 绝对行首加光标（第 0 列）" })

    -- 3. 行尾
    if v.tail and v.tail ~= "" then
        set("x", v.tail, function() M.apply("tail") end, { desc = "多光标: 选区行尾加光标" })
    end

    -- 4. 首尾交替（智能首字符前 <-> 行尾）
    if v.alternate and v.alternate ~= "" then
        set("x", v.alternate, function() M.apply("alternate") end, { desc = "多光标: 选区首尾交替（首字符前 <-> 行尾）" })
    end

    -- 5. 首尾交替（绝对行首 <-> 行尾）
    if v.alternate_bol and v.alternate_bol ~= "" then
        set("x", v.alternate_bol, function() M.apply("alternate_bol") end, { desc = "多光标: 选区首尾交替（绝对行首 <-> 行尾）" })
    end

    -- Visual Mode 助记分组 (<leader>m...)
    set("x", "<leader>mh", function() M.apply("head") end, { desc = "多光标: 每行首字符前加光标" })
    set("x", "<leader>mi", function() M.apply("head") end, { desc = "多光标: 每行首字符前加光标" })
    set("x", "<leader>mH", function() M.apply("bol") end, { desc = "多光标: 绝对行首加光标" })
    set("x", "<leader>m0", function() M.apply("bol") end, { desc = "多光标: 绝对行首加光标" })
    set("x", "<leader>mt", function() M.apply("tail") end, { desc = "多光标: 选区行尾加光标" })
    set("x", "<leader>ma", function() M.apply("alternate") end, { desc = "多光标: 首尾交替（首字符前）" })
    set("x", "<leader>mA", function() M.apply("alternate_bol") end, { desc = "多光标: 首尾交替（绝对行首）" })

    -- Normal Mode mappings (支持数字前缀例如 5<leader>mh)
    if n.head and n.head ~= "" then
        set("n", n.head, function() M.apply("head") end, { desc = "多光标: 首字符前加光标" })
    end
    if n.bol and n.bol ~= "" then
        set("n", n.bol, function() M.apply("bol") end, { desc = "多光标: 绝对行首加光标" })
    end
    if n.tail and n.tail ~= "" then
        set("n", n.tail, function() M.apply("tail") end, { desc = "多光标: 行尾加光标" })
    end
    if n.alternate and n.alternate ~= "" then
        set("n", n.alternate, function() M.apply("alternate") end, { desc = "多光标: 首尾交替（首字符前）" })
    end
    if n.alternate_bol and n.alternate_bol ~= "" then
        set("n", n.alternate_bol, function() M.apply("alternate_bol") end, { desc = "多光标: 首尾交替（绝对行首）" })
    end
end

return M

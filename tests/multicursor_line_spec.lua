-- Unit tests for multicursor-line.nvim
local repo_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(repo_root)

-- Load vim-visual-multi
local lazy_vm = vim.fn.stdpath("data") .. "/lazy/vim-visual-multi"
if vim.fn.isdirectory(lazy_vm) == 1 then
    vim.opt.runtimepath:append(lazy_vm)
    vim.cmd("runtime plugin/visual-multi.vim")
end

local mcline = require("multicursor-line")
mcline.setup({
    backend = "vm",
    alternate_start = "tail",
})

vim.cmd("new")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "aaa", "bbb", "ccc", "ddd" })

-- 1. Test is_tail_line
assert(mcline.is_tail_line("head", 1) == false, "Head should not be tail")
assert(mcline.is_tail_line("tail", 1) == true, "Tail should be tail")
assert(mcline.is_tail_line("alternate", 1) == true, "Alt line 1 should be tail")
assert(mcline.is_tail_line("alternate", 2) == false, "Alt line 2 should be head")

-- 2. Test apply head on range
mcline.apply("head", { line1 = 1, line2 = 4 })
assert(vim.b.visual_multi == 1, "VM should be active")
assert(#vim.b.VM_Selection.Regions == 4, "Should have 4 regions")
for i = 1, 4 do
    assert(vim.fn.getline(i):find(" $") == nil, "Normal mode should not have trailing space")
end
mcline.clear()

-- 3. Test apply tail on range in Normal Mode (MUST NOT add trailing spaces!)
mcline.apply("tail", { line1 = 1, line2 = 4 })
assert(vim.b.visual_multi == 1, "VM should be active")
assert(#vim.b.VM_Selection.Regions == 4, "Should have 4 regions")
for i = 1, 4 do
    assert(vim.fn.getline(i) == ({ "aaa", "bbb", "ccc", "ddd" })[i], "Line text must not have trailing spaces added in normal mode")
end
mcline.clear()

-- 4. Test apply alternate on range in Normal Mode (MUST NOT have trailing spaces!)
mcline.apply("alternate", { line1 = 1, line2 = 4 })
assert(vim.b.visual_multi == 1, "VM should be active")
assert(#vim.b.VM_Selection.Regions == 4, "Should have 4 regions")
for i = 1, 4 do
    assert(vim.fn.getline(i) == ({ "aaa", "bbb", "ccc", "ddd" })[i], "Odd/even lines must remain completely untouched in normal mode")
end

-- 5. Test pressing 'i' to enter insert mode
-- The buffer mapping for 'i' will execute start_insert
local bufnr = vim.api.nvim_get_current_buf()
local map_i = vim.fn.maparg("i", "n", false, true)
assert(type(map_i) == "table" and map_i.callback ~= nil, "'i' mapping should be active")
map_i.callback()

assert(#vim.b.VM_Selection.Insert.cursors == 4, "Should have 4 insert cursors")
local cursors = vim.b.VM_Selection.Insert.cursors
assert(cursors[1].a == 4, "Insert cursor 1 should be col 4 (tail)")
assert(cursors[2].a == 1, "Insert cursor 2 should be col 1 (head)")
assert(cursors[3].a == 4, "Insert cursor 3 should be col 4 (tail)")
assert(cursors[4].a == 1, "Insert cursor 4 should be col 1 (head)")

mcline.clear()

-- 6. Test visual block selection
local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
local ctrl_v = vim.api.nvim_replace_termcodes("<C-v>", true, false, true)

-- Select block lines 1..4, cols 1..2 (characters 1..2)
vim.api.nvim_win_set_cursor(0, { 1, 0 })
vim.api.nvim_feedkeys(ctrl_v .. "3jl", "nx", false)
mcline.apply("alternate")

assert(vim.b.visual_multi == 1, "VM should be active for block alternate")
for i = 1, 4 do
    assert(vim.fn.getline(i) == ({ "aaa", "bbb", "ccc", "ddd" })[i], "Block normal mode must not modify line text")
end
mcline.clear()

vim.cmd("bdelete!")
print("ALL MULTICURSOR-LINE NO-TRAILING-SPACE TESTS PASSED!")

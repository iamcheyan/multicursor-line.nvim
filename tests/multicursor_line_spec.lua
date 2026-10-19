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
for _, r in ipairs(vim.b.VM_Selection.Regions) do
    assert(r.a == 1, "VM col should be 1 (1-indexed)")
end
mcline.clear()

-- 3. Test apply tail on range (should be truly at EOL, col 4 after "aaa")
mcline.apply("tail", { line1 = 1, line2 = 4 })
assert(vim.b.visual_multi == 1, "VM should be active")
assert(#vim.b.VM_Selection.Regions == 4, "Should have 4 regions")
for _, r in ipairs(vim.b.VM_Selection.Regions) do
    assert(r.a == 4, "VM tail col should be 4 (after 3 chars)")
end
mcline.clear()
-- Verify trailing spaces are cleanly removed on clear
for i = 1, 4 do
    assert(vim.fn.getline(i):find(" $") == nil, "No trailing space should remain after clear")
end

-- 4. Test apply alternate on range
mcline.apply("alternate", { line1 = 1, line2 = 4 })
assert(vim.b.visual_multi == 1, "VM should be active")
assert(#vim.b.VM_Selection.Regions == 4, "Should have 4 regions")
local regions = vim.b.VM_Selection.Regions
assert(regions[1].a == 4, "Line 1 should be tail after 'aaa' (col 4)")
assert(regions[2].a == 1, "Line 2 should be head before 'bbb' (col 1)")
assert(regions[3].a == 4, "Line 3 should be tail after 'ccc' (col 4)")
assert(regions[4].a == 1, "Line 4 should be head before 'ddd' (col 1)")

-- 5. Test entering insert mode via 'i' in alternate
vim.cmd("call b:VM_Selection.Insert.key('i')")
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
local b_regions = vim.b.VM_Selection.Regions
assert(b_regions[1].a == 3, "Block Line 1 should be after block right edge (col 3)")
assert(b_regions[2].a == 1, "Block Line 2 should be at block left edge (col 1)")
assert(b_regions[3].a == 3, "Block Line 3 should be after block right edge (col 3)")
assert(b_regions[4].a == 1, "Block Line 4 should be at block left edge (col 1)")
mcline.clear()

vim.cmd("bdelete!")
print("ALL MULTICURSOR-LINE ALTERNATE & TAIL POSITION TESTS PASSED!")

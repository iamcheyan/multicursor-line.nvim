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
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "123456789", "abcdefghi", "ABCDEFGHI", "444444444" })

-- 1. Test get_col for line modes
assert(mcline.get_col("head", 1, 1) == 0, "Line head should be col 0")
assert(mcline.get_col("tail", 1, 1) == 8, "Line tail should be col 8")
assert(mcline.get_col("alternate", 1, 1) == 8, "Alt line 1 should be tail (col 8)")
assert(mcline.get_col("alternate", 2, 2) == 0, "Alt line 2 should be head (col 0)")

-- 2. Test get_col for block modes (cols 2..5, 0-indexed: 1..4)
assert(mcline.get_col("head", 1, 1, true, 1, 4) == 1, "Block head should be col 1")
assert(mcline.get_col("tail", 1, 1, true, 1, 4) == 4, "Block tail should be col 4")
assert(mcline.get_col("alternate", 1, 1, true, 1, 4) == 4, "Alt block line 1 should be tail (col 4)")
assert(mcline.get_col("alternate", 2, 2, true, 1, 4) == 1, "Alt block line 2 should be head (col 1)")

-- 3. Test apply head on range
mcline.apply("head", { line1 = 1, line2 = 3 })
assert(vim.b.visual_multi == 1, "VM should be active")
assert(#vim.b.VM_Selection.Regions == 3, "Should have 3 regions")
for _, r in ipairs(vim.b.VM_Selection.Regions) do
    assert(r.a == 1, "VM col should be 1 (1-indexed)")
end
mcline.clear()

-- 4. Test apply tail on range
mcline.apply("tail", { line1 = 1, line2 = 3 })
assert(vim.b.visual_multi == 1, "VM should be active")
assert(#vim.b.VM_Selection.Regions == 3, "Should have 3 regions")
for _, r in ipairs(vim.b.VM_Selection.Regions) do
    assert(r.a == 9, "VM tail col should be 9 (1-indexed)")
end
mcline.clear()

-- 5. Test apply alternate on range
mcline.apply("alternate", { line1 = 1, line2 = 3 })
assert(vim.b.visual_multi == 1, "VM should be active")
assert(#vim.b.VM_Selection.Regions == 3, "Should have 3 regions")
local regions = vim.b.VM_Selection.Regions
assert(regions[1].a == 9, "Line 1 should be tail (9)")
assert(regions[2].a == 1, "Line 2 should be head (1)")
assert(regions[3].a == 9, "Line 3 should be tail (9)")
mcline.clear()

-- 6. Test visual block selection
local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
local ctrl_v = vim.api.nvim_replace_termcodes("<C-v>", true, false, true)

-- Select block lines 1..3, cols 2..5 (1-indexed: 2..5 -> 0-indexed: 1..4)
vim.api.nvim_win_set_cursor(0, { 1, 1 })
vim.api.nvim_feedkeys(ctrl_v .. "2j3l", "nx", false)
mcline.apply("alternate")

assert(vim.b.visual_multi == 1, "VM should be active for block alternate")
assert(#vim.b.VM_Selection.Regions == 3, "Should have 3 regions for block alternate")
local block_regions = vim.b.VM_Selection.Regions
assert(block_regions[1].a == 5, "Block Line 1 should be right edge (col 5)")
assert(block_regions[2].a == 2, "Block Line 2 should be left edge (col 2)")
assert(block_regions[3].a == 5, "Block Line 3 should be right edge (col 5)")
mcline.clear()

-- 7. Test user commands
vim.cmd("1,3McLineHead")
assert(vim.b.visual_multi == 1, "VM active after command")
assert(#vim.b.VM_Selection.Regions == 3, "3 regions from command")
vim.cmd("McLineClear")
assert(vim.b.visual_multi ~= 1, "VM cleared after McLineClear")

vim.cmd("bdelete!")
print("ALL MULTICURSOR-LINE SELECTION-BASED TESTS PASSED!")

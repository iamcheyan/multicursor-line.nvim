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

-- Test get_col
assert(mcline.get_col("head", 1, 1) == 0, "Head col should be 0")
assert(mcline.get_col("tail", 1, 1) == 2, "Tail col line 1 should be 2")
assert(mcline.get_col("alternate", 1, 1) == 2, "Alt col line 1 should be 2 (tail)")
assert(mcline.get_col("alternate", 2, 2) == 0, "Alt col line 2 should be 0 (head)")

-- Test select_all
mcline.select_all("alternate", 1, 4)
assert(vim.b.visual_multi == 1, "VM should be active")
assert(#vim.b.VM_Selection.Regions == 4, "Should have 4 VM regions")
mcline.clear()

-- Test step_down
vim.api.nvim_win_set_cursor(0, { 1, 0 })
mcline.step_down("head")
assert(vim.b.visual_multi == 1, "VM active after step_down")
assert(#vim.b.VM_Selection.Regions == 2, "Should have 2 cursors after first step_down")

mcline.step_down("head")
assert(#vim.b.VM_Selection.Regions == 3, "Should have 3 cursors after second step_down")
mcline.clear()

vim.cmd("bdelete!")
print("ALL MULTICURSOR-LINE VM STEP & SELECT TESTS PASSED!")

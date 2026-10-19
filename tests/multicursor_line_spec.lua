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
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
    '  "gnucobol_eyebrow": "OFFICIAL COMPILER",',
    '  "gnucobol_lead": "...",',
    '    ("课程与示例", "..."),',
    '    ("`cobc` 编译", "..."),',
    '  ],'
})

-- 1. Test get_head_column
local lines = vim.api.nvim_buf_get_lines(0, 0, 5, false)
-- Head mode: first non-blank
assert(mcline.get_head_column("head", lines[1], false, 0) == 2, "Line 1 head should be 2")
assert(mcline.get_head_column("head", lines[3], false, 0) == 4, "Line 3 head should be 4")
-- BOL mode: absolute col 0
assert(mcline.get_head_column("bol", lines[1], false, 0) == 0, "Line 1 bol should be 0")
assert(mcline.get_head_column("bol", lines[3], false, 0) == 0, "Line 3 bol should be 0")

-- 2. Test apply head (每行首个非空字符前)
mcline.apply("head", { line1 = 1, line2 = 5 })
assert(vim.b.visual_multi == 1, "VM should be active")
local r = vim.b.VM_Selection.Regions
assert(r[1].a == 3, "Line 1 cursor should be at col 3 (1-indexed for byte 2)")
assert(r[2].a == 3, "Line 2 cursor should be at col 3")
assert(r[3].a == 5, "Line 3 cursor should be at col 5 (1-indexed for byte 4)")
assert(r[4].a == 5, "Line 4 cursor should be at col 5")
assert(r[5].a == 3, "Line 5 cursor should be at col 3")
mcline.clear()

-- 3. Test apply bol (绝对行首第 0 列)
mcline.apply("bol", { line1 = 1, line2 = 5 })
assert(vim.b.visual_multi == 1, "VM should be active")
for _, reg in ipairs(vim.b.VM_Selection.Regions) do
    assert(reg.a == 1, "All BOL cursors should be at col 1 (0-indexed 0)")
end
mcline.clear()

-- 4. Test apply alternate (智能首尾交替：首字符前 <-> 行尾)
mcline.apply("alternate", { line1 = 1, line2 = 5 })
assert(vim.b.visual_multi == 1, "VM should be active")
local alt_r = vim.b.VM_Selection.Regions
assert(alt_r[1].a == #lines[1], "Line 1 should be tail")
assert(alt_r[2].a == 3, "Line 2 should be first non-blank (col 3)")
assert(alt_r[3].a == #lines[3], "Line 3 should be tail")
assert(alt_r[4].a == 5, "Line 4 should be first non-blank (col 5)")
assert(alt_r[5].a == #lines[5], "Line 5 should be tail")
mcline.clear()

-- 5. Test apply alternate_bol (绝对首尾交替：第 0 列 <-> 行尾)
mcline.apply("alternate_bol", { line1 = 1, line2 = 5 })
assert(vim.b.visual_multi == 1, "VM should be active")
local alt_bol_r = vim.b.VM_Selection.Regions
assert(alt_bol_r[1].a == #lines[1], "Line 1 should be tail")
assert(alt_bol_r[2].a == 1, "Line 2 should be absolute bol (col 1)")
assert(alt_bol_r[3].a == #lines[3], "Line 3 should be tail")
assert(alt_bol_r[4].a == 1, "Line 4 should be absolute bol (col 1)")
assert(alt_bol_r[5].a == #lines[5], "Line 5 should be tail")
mcline.clear()

vim.cmd("bdelete!")
print("ALL MULTICURSOR-LINE INDENTATION TESTS PASSED!")

-- Unit tests for multicursor-line.nvim

-- Add repository and multicursor dependency to runtimepath
local repo_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(repo_root)

local lazy_mc = vim.fn.stdpath("data") .. "/lazy/multicursor.nvim"
if vim.fn.isdirectory(lazy_mc) == 1 then
    vim.opt.runtimepath:append(lazy_mc)
end

local mc = require("multicursor-nvim")
mc.setup()

local mcline = require("multicursor-line")
mcline.setup({
    default_mode = "head",
    alternate_start = "tail",
})

-- Test 1: get_col_for_line calculation
vim.cmd("new")
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
    "aaa",
    "bbbb",
    "ccccc",
    "dddddd",
})

assert(mcline.get_col_for_line("head", 1, 1) == 1, "Head mode should be col 1")
assert(mcline.get_col_for_line("tail", 1, 1) == 3, "Tail mode line 1 should be col 3")
assert(mcline.get_col_for_line("tail", 2, 2) == 4, "Tail mode line 2 should be col 4")
assert(mcline.get_col_for_line("tail", 3, 3) == 5, "Tail mode line 3 should be col 5")

-- Alternate mode: 1->tail (3), 2->head (1), 3->tail (5), 4->head (1)
assert(mcline.get_col_for_line("alternate", 1, 1) == 3, "Alt mode line 1 should be tail (3)")
assert(mcline.get_col_for_line("alternate", 2, 2) == 1, "Alt mode line 2 should be head (1)")
assert(mcline.get_col_for_line("alternate", 3, 3) == 5, "Alt mode line 3 should be tail (5)")
assert(mcline.get_col_for_line("alternate", 4, 4) == 1, "Alt mode line 4 should be head (1)")

-- Test 2: Step execution
mcline.start("alternate", { start_line = 1, end_line = 4 })
assert(mcline.is_active(), "Session should be active")
local st = mcline.get_state()
assert(st.current_line == 1, "Step 1 should be on line 1")

-- Step down (n / j)
mcline.step()
st = mcline.get_state()
assert(st.current_line == 2, "Step 2 should be on line 2")
assert(mc.numCursors() == 2, "Should have 2 cursors")

mcline.step()
st = mcline.get_state()
assert(st.current_line == 3, "Step 3 should be on line 3")
assert(mc.numCursors() == 3, "Should have 3 cursors")

-- Step back (p / k)
mcline.step_back()
st = mcline.get_state()
assert(st.current_line == 2, "After step_back should be on line 2")
assert(mc.numCursors() == 2, "Should have 2 cursors after step_back")

-- Step forward again to 4
mcline.step()
mcline.step()
st = mcline.get_state()
assert(st.current_line == 4, "Should be on line 4")
assert(mc.numCursors() == 4, "Should have 4 cursors")

mcline.clear()
assert(not mcline.is_active(), "Session should be cleared")
assert(mc.numCursors() == 1, "Cursors should be cleared")

-- Test 3: Toggle all (A)
mcline.start("head", { start_line = 1, end_line = 4 })
assert(mc.numCursors() == 1, "Start with 1 cursor")

-- Press A to select all
mcline.toggle_all()
assert(mc.numCursors() == 4, "Select all should generate 4 cursors")
st = mcline.get_state()
assert(st.is_all_selected == true, "is_all_selected should be true")

-- Press A again to cancel select all
mcline.toggle_all()
assert(mc.numCursors() == 1, "Toggle again should revert to 1 cursor")
st = mcline.get_state()
assert(st.is_all_selected == false, "is_all_selected should be false")
assert(st.current_line == 1, "Reverted to line 1")

mcline.clear()

vim.cmd("bdelete!")
print("ALL MULTICURSOR-LINE EXTENDED TESTS PASSED!")

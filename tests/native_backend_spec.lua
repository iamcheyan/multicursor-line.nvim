-- Tests for the native backend (default): batched insertion points.
local repo_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(repo_root)

local mcline = require("multicursor-line")
mcline.setup({ backend = "native" })

vim.cmd("new")
local buf = vim.api.nvim_get_current_buf()
local lines = {}
for i = 1, 4000 do
    lines[i] = string.format("%06d-ACTIVE-DATA-RECORD", i)
end
vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

local function marks()
    return vim.api.nvim_buf_get_extmarks(buf, mcline.cursor_namespace, 0, -1, {})
end

-- Building cursors across 4000 lines must stay fast (single batched pass).
local start = vim.uv.hrtime()
mcline.apply("head", { line1 = 1, line2 = 4000 })
local elapsed = (vim.uv.hrtime() - start) / 1e9
assert(#marks() == 4000, "one insertion point per line, got " .. #marks())
assert(elapsed < 2.0, string.format("4000 cursors must build in under 2s, took %.3fs", elapsed))

-- Indented lines: head mode points at the first non-blank character.
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "  alpha", "    bravo" })
mcline.apply("head", { line1 = 1, line2 = 2 })
local head_marks = marks()
assert(head_marks[1][3] == 2, "head of '  alpha' must be byte 2")
assert(head_marks[2][3] == 4, "head of '    bravo' must be byte 4")

-- BOL mode points at column 0.
mcline.apply("bol", { line1 = 1, line2 = 2 })
for _, mark in ipairs(marks()) do
    assert(mark[3] == 0, "bol cursors must sit at column 0")
end

-- Tail mode points at the end of each line.
mcline.apply("tail", { line1 = 1, line2 = 2 })
local tail_marks = marks()
assert(tail_marks[1][3] == #"  alpha", "tail of '  alpha' must be the line end")
assert(tail_marks[2][3] == #"    bravo", "tail of '    bravo' must be the line end")

-- Clearing removes every insertion point.
mcline.clear()
assert(#marks() == 0, "clear() must remove all insertion points")

vim.cmd("bdelete!")
print("native_backend_spec: OK")
vim.cmd("qa!")

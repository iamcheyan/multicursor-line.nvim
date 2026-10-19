# multicursor-line.nvim

> **Ultra-fast line and block-based multi-cursor plugin for Neovim** (Head / Tail / Alternate).  
> Create multi-cursors instantly across visual selections and rectangular blocks with live real-time typing and backspacing.

[English](README.md) | [简体中文](README.zh-CN.md)

---

## 💡 Core Philosophy: Select First, Apply Instantly

Clean and simple Neovim philosophy:
- Select the target lines or rectangle block using native Vim motions (`Vj`, `vip`, `ggVG`, `<C-v>`).
- Press a single mapping (`<leader>h`, `<leader>t`, `<leader>a`).
- Multi-cursors appear immediately on all selected lines!
- Press `i` or `a` to type simultaneously across all cursors with real-time updates and backspacing.

---

## 🎯 3 Core Actions

| Action | Visual Mode Key | Description |
| :--- | :--- | :--- |
| **Head (行首)** | `<leader>h` or `<leader>mh` | Add cursors at the **head** of all selected lines (or **left edge** of visual block) |
| **Tail (行尾)** | `<leader>t` or `<leader>mt` | Add cursors at the **tail** of all selected lines (or **right edge** of visual block) |
| **Alternate (首尾交替)** | `<leader>a` or `<leader>ma` | Add cursors **alternating between head and tail** (or alternating right and left edges of visual block) |

---

## 📐 Visual Block Support (`<C-v>`)

When you create a rectangular block using `<C-v>`:
- **Head (`<leader>h`)**: Cursors line up at the **left edge** of the rectangle.
- **Tail (`<leader>t`)**: Cursors line up at the **right edge** of the rectangle.
- **Alternate (`<leader>a`)**: Cursors alternate between the **right and left edges** of the rectangle.

---

## ⌨️ Workflow

1. **Select lines**:
   - Two lines: `Vj`
   - Paragraph: `vip`
   - Whole buffer: `ggVG`
   - Rectangular box: `<C-v>3j4l`
2. **Apply mode**:
   - Press `<leader>h` (Head), `<leader>t` (Tail), or `<leader>a` (Alternate)
3. **Edit**:
   - Press `i` to insert live across all cursors
   - Press `a` to append live across all cursors
   - Press `c` to change text
   - Press `<Esc>` to exit multi-cursor

---

## 📦 Installation (lazy.nvim)

```lua
{
    "iamcheyan/multicursor-line.nvim",
    dependencies = { "mg979/vim-visual-multi" },
    opts = {
        backend = "vm",             -- "vm" (live typing) or "multicursor"
        alternate_start = "tail",   -- Start alternate mode with "tail" or "head"
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
    },
}
```

---

## ⚙️ Commands

- `:[range]McLineHead`: Add cursors at line/block head
- `:[range]McLineTail`: Add cursors at line/block tail
- `:[range]McLineAlt`: Add cursors alternating between head and tail
- `:McLineClear`: Clear all active cursors

---

## 📄 License

MIT License © 2026 iamcheyan

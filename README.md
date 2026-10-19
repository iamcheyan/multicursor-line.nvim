# multicursor-line.nvim

> **Ultra-fast line and block-based multi-cursor plugin for Neovim** (Smart First-Non-Blank / Absolute BOL / Tail / Alternate).  
> Create multi-cursors instantly across visual selections and rectangular blocks with indentation awareness and live real-time typing.

[English](README.md) | [简体中文](README.zh-CN.md)

---

## 💡 Core Philosophy: Select First, Apply Instantly

Clean and simple Neovim philosophy:
- Select the target lines or rectangle block using native Vim motions (`Vj`, `vip`, `ggVG`, `<C-v>`).
- Press a single mapping (`<leader>h`, `<leader>0`, `<leader>t`, `<leader>a`).
- Multi-cursors appear immediately on all selected lines!
- Press `i` or `a` to type simultaneously across all cursors with real-time updates and backspacing.

---

## 🎯 Core Actions & Keymaps

To accommodate code with indentation, two head modes are supported:

| Action | Visual Mode Key | Mnemonic Group | Description |
| :--- | :--- | :--- | :--- |
| **First Non-Blank (首字符前)** | **`<leader>h`** or **`<leader>i`** | `<leader>mh` / `<leader>mi` | **Skips indentation**, places cursors before the **first non-blank character** of each line |
| **Absolute BOL (绝对行首)** | **`<leader>H`** or **`<leader>0`** | `<leader>mH` / `<leader>m0` | Places cursors at **column 0** (leftmost column, including indentation) |
| **Tail (行尾)** | **`<leader>t`** | `<leader>mt` | Places cursors at the **end** of each line (past the line end) |
| **Alternate (Smart)** | **`<leader>a`** | `<leader>ma` | Alternates between tail and **first non-blank** (skips indentation) |
| **Alternate (BOL)** | **`<leader>A`** | `<leader>mA` | Alternates between tail and **column 0** |

---

## 📐 Indentation & Visual Block Examples

### 1. Indented Code (e.g. JSON / Python)
```json
  "about_title": "COBOL Intro",
  "gnucobol_title": "GnuCOBOL Compiler",
    ("course_item", "COBOL Source"),
```
- Press **`<leader>h`**: Cursors automatically align before `"about_title"`, `"gnucobol_title"`, and `("course_item"`, adapting dynamically to varying indentation depths!
- Press **`<leader>0`**: All cursors sit at column 0.

### 2. Rectangular Block Support (`<C-v>`)
- **Head (`<leader>h`)**: Cursors line up at the **left edge** of the rectangle.
- **Tail (`<leader>t`)**: Cursors line up at the **right edge** of the rectangle.
- **Alternate (`<leader>a`)**: Cursors alternate between the **right and left edges** of the rectangle.

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
    },
}
```

---

## ⚙️ Commands

- `:[range]McLineHead`: Add cursors before first non-blank character
- `:[range]McLineBol`: Add cursors at column 0
- `:[range]McLineTail`: Add cursors at line/block tail
- `:[range]McLineAlt`: Add cursors alternating between tail and first non-blank
- `:[range]McLineAltBol`: Add cursors alternating between tail and column 0
- `:McLineClear`: Clear all active cursors

---

## 📄 License

MIT License © 2026 iamcheyan

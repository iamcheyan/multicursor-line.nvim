# multicursor-line.nvim

> **按行位置快速生成多光标插件**（支持逐步扩展与一次全选）  
> Progressive and one-shot line-based multi-cursor generation for Neovim (0.10+), powered by [multicursor.nvim](https://github.com/jake-stewart/multicursor.nvim).

[English](README.md) | [简体中文](README.zh-CN.md)

---

## 💡 Design Philosophy

The core principle of **multicursor-line.nvim** is:  
**"Generate cursors progressively at predefined line geometries (Head, Tail, Alternating)"**, rather than searching for text strings.

Built on top of `multicursor.nvim`'s fast and robust multi-cursor engine, it adds intuitive stateful line-by-line progression and batch line-selection capabilities.

---

## ✨ Features

### 1. 行首模式 (Head Mode)
Places cursors at the beginning (`col = 1`) of each target line.
* Step 1: `|aaa`
* Step 2: `|aaa` \ `|bbb`
* Step 3: `|aaa` \ `|bbb` \ `|ccc`
* *Also supports one-shot select-all!*

### 2. 行尾模式 (Tail Mode)
Places cursors at the end of each target line.
* Step 1: `aaa|`
* Step 2: `aaa|` \ `bbb|`
* Step 3: `aaa|` \ `bbb|` \ `ccc|`
* *Also supports one-shot select-all!*

### 3. 首尾交替模式 (Alternating Mode)
Alternates cursor positions between tail and head across lines (configurable start position).
* Step 1: `aaa|`
* Step 2: `aaa|` \ `|bbb`
* Step 3: `aaa|` \ `|bbb` \ `ccc|`
* Step 4: `aaa|` \ `|bbb` \ `ccc|` \ `|ddd`
* *Also supports one-shot select-all!*

### 4. 范围支持 (Scope & Range)
* **Visual Line 选区** (`V` 选中的行)
* **整个 Buffer** (默认从当前行向下扩展至末尾)
* **用户指定行范围** (支持 Vim Ex 命令行范围，如 `:10,20McLineAltAll` 或 `:'<,'>McLineHead`)
* **Count 支持** (如 `5<leader>mh` 针对接下来的 5 行)

### 5. 优雅的键位复用 (Keymap Layer Multiplexing)
* **未激活时**：`<C-n>` 保持你的原生键位映射（如常规查词或跳行），完全不被占用。
* **激活行模式后**：`<C-n>` 临时作为“向当前模式追加下一行光标”，连按 `<C-n>` 极速推进。
* **`<M-C-n>` (Alt-Ctrl-N)**：当前模式下一键全选所有目标行。
* **`<Esc>`**：清除多光标，`<C-n>` 立即归还原生行为。

---

## 📦 Installation (lazy.nvim)

```lua
{
    "iamcheyan/multicursor-line.nvim",
    dependencies = {
        "jake-stewart/multicursor.nvim",
        branch = "1.0",
    },
    config = function()
        -- 1. Initialize multicursor.nvim
        local mc = require("multicursor-nvim")
        mc.setup()

        -- 2. Initialize multicursor-line.nvim
        require("multicursor-line").setup({
            default_mode = "head",      -- "head" | "tail" | "alternate"
            alternate_start = "tail",   -- "tail" | "head"
            prefix = "<leader>m",       -- Starter keymap prefix
            dynamic_layer = true,       -- Multiplex <C-n> only during active session
            keymaps = {
                step = "<C-n>",
                select_all = "<M-C-n>",
                standalone_step = false, -- Optional: standalone key like "<M-n>"
            },
        })
    end,
}
```

---

## ⌨️ Keybindings

| Key | Mode | Description |
| :--- | :--- | :--- |
| `<leader>mh` | Normal / Visual | 启动行首模式（第 1 步） |
| `<leader>mt` | Normal / Visual | 启动行尾模式（第 1 步） |
| `<leader>ma` | Normal / Visual | 启动首尾交替模式（第 1 步） |
| `<C-n>` *(激活时)* | Normal / Visual | 向当前模式追加下一行光标 |
| `<M-C-n>` *(激活时)*| Normal / Visual | 当前模式下一键全选所有行 |
| `<leader>mH` | Normal / Visual | 直接全选所有行首 |
| `<leader>mT` | Normal / Visual | 直接全选所有行尾 |
| `<leader>mA` | Normal / Visual | 直接全选所有首尾交替 |
| `<Esc>` | Normal | 清除多光标并退出会话 |

---

## 💻 Commands

| Command | Range | Description |
| :--- | :--- | :--- |
| `:McLineHead` | Yes | 启动行首模式并生成第 1 个光标 |
| `:McLineHeadAll` | Yes | 直接在所有目标行首生成光标 |
| `:McLineTail` | Yes | 启动行尾模式并生成第 1 个光标 |
| `:McLineTailAll` | Yes | 直接在所有目标行尾生成光标 |
| `:McLineAlt` | Yes | 启动首尾交替模式并生成第 1 个光标 |
| `:McLineAltAll` | Yes | 直接对全部目标行应用首尾交替规则 |
| `:McLineClear` | No | 清除多光标与状态 |
| `:[range]McLine [head\|tail\|alt] [step\|all]` | Yes | 统一参数化命令 |

---

## 🛠️ Lua API

```lua
local mcline = require("multicursor-line")

-- 逐步单步追加
mcline.step("head")
mcline.step("tail")
mcline.step("alternate")

-- 一键全选
mcline.select_all("alternate", { start_line = 1, end_line = 20 })

-- 切换当前模式
mcline.set_mode("tail")

-- 清除状态与光标
mcline.clear()
```

---

## 📄 License

MIT License © 2026 iamcheyan

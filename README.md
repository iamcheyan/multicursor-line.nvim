# multicursor-line.nvim

> **按行位置快速生成多光标插件**（行首 / 行尾 / 首尾交替，支持向上/向下追加与一次全选）  
> Progressive and one-shot line-based multi-cursor generation for Neovim, supporting real-time simultaneous typing and backspacing.

[English](README.md) | [简体中文](README.zh-CN.md)

---

## 💡 设计原则 (Design Philosophy)

插件核心理念：**“按行位置（行首、行尾、首尾交替）极速生成预定义多光标”**。
* **实时多光标输入**：选完后直接按 `i` 或 `a`，打一个字每个光标实时出现，按退格每个光标实时删除！
* **无按键冲突**：不抢占普通单字母键（如 `A` 或 `m`），操作直观清晰。

---

## ✨ 核心功能 (3 大模式)

### 1. 行首模式 (Head Mode)
* **向下追加 (`<leader>mj`)**：从当前行开始，按一次向下加一行行首光标。
* **向上追加 (`<leader>mk`)**：从当前行开始，按一次向上加一行行首光标。
* **全选 (`<leader>mh`)**：Visual 模式下全选选区行首；Normal 模式下全选整段行首。

### 2. 行尾模式 (Tail Mode)
* **向下追加 (`<leader>ml`)**：从当前行开始，按一次向下加一行行尾光标。
* **向上追加 (`<leader>mL`)**：从当前行开始，按一次向上加一行行尾光标。
* **全选 (`<leader>mt`)**：Visual 模式下全选选区行尾；Normal 模式下全选整段行尾。

### 3. 首尾交替模式 (Alternate Mode)
* **向下追加 (`<leader>mn`)**：按一次向下追加一行（首尾交替）。
* **向上追加 (`<leader>mp`)**：按一次向上追加一行（首尾交替）。
* **全选 (`<leader>ma`)**：Visual 模式下全选选区首尾交替；Normal 模式下全选整段交替。

---

## 📦 安装与配置 (lazy.nvim)

```lua
{
    "iamcheyan/multicursor-line.nvim",
    dependencies = { "mg979/vim-visual-multi" },
    opts = {
        backend = "vm", -- "vm" 支持实时打字与退格同步
        alternate_start = "tail",
        prefix = "<leader>m",
    },
    config = function(_, opts)
        require("multicursor-line").setup(opts)
    end,
}
```

---

## ⌨️ 快捷键速查

| 模式 | 快捷键 | 功能说明 |
| :--- | :--- | :--- |
| **行首** | `<leader>mj` | 行首：向下加一行光标 |
| **行首** | `<leader>mk` | 行首：向上加一行光标 |
| **行首** | `<leader>mh` | 行首：全选（选区或全段） |
| **行尾** | `<leader>ml` | 行尾：向下加一行光标 |
| **行尾** | `<leader>mL` | 行尾：向上加一行光标 |
| **行尾** | `<leader>mt` | 行尾：全选（选区或全段） |
| **交替** | `<leader>mn` | 首尾交替：向下加一行光标 |
| **交替** | `<leader>mp` | 首尾交替：向上加一行光标 |
| **交替** | `<leader>ma` | 首尾交替：全选（选区或全段） |
| **通用** | `<Esc>` | 退出并清除多光标 |

---

## 📄 License

MIT License © 2026 iamcheyan

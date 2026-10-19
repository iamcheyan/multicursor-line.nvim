# multicursor-line.nvim

> **按行位置快速生成多光标插件**（支持逐步扩展与一次全选）  
> 专为 Neovim (0.10+) 打造，基于 [multicursor.nvim](https://github.com/jake-stewart/multicursor.nvim) 的行多光标扩展。

[English](README.md) | [简体中文](README.zh-CN.md)

---

## 💡 设计原则

插件的核心原则是：**“按行逐步生成预定义光标位置”**，而不是搜索字符串生成多光标。

在日常文本编辑、表格对齐、键值对批量转换等场景下，很多时候我们需要的不是找相同的变量名，而是快速在目标行段的行首、行尾或交替位置排布光标。

---

## ✨ 核心功能

### 1. 行首模式 (Head Mode)
在目标范围内的每一行行首（`col = 1`）创建光标：
* 第一次触发：`|aaa`
* 第二次触发：`|aaa` \ `|bbb`
* 第三次触发：`|aaa` \ `|bbb` \ `|ccc`
* 持续触发直到覆盖所有行。
* 提供一键全选命令：瞬间在所有行首排布光标。

### 2. 行尾模式 (Tail Mode)
在目标范围内的每一行行尾创建光标：
* 第一次：`aaa|`
* 第二次：`aaa|` \ `bbb|`
* 第三次：`aaa|` \ `bbb|` \ `ccc|`
* 持续扩展直到全部行。
* 提供一键全选命令：瞬间选中所有行尾。

### 3. 首尾交替模式 (Alternating Mode)
在目标行段中按照“行尾 ➔ 行首 ➔ 行尾 ➔ 行首”规律交替放置光标：
* 第一次：`aaa|`
* 第二次：`aaa|` \ `|bbb`
* 第三次：`aaa|` \ `|bbb` \ `ccc|`
* 第四次：`aaa|` \ `|bbb` \ `ccc|` \ `|ddd`
* 持续扩展直到全部行。
* 提供一键全选命令：直接对全选行段应用首尾交替规则。

### 4. 范围支持 (Scope)
* **Visual Line 选区**：在 `V` 模式选好范围后，直接触发即可对选区生效。
* **整个 Buffer**：在 Normal 模式默认从当前行向下扩展至文件结尾。
* **自定义行范围**：支持标准 Ex 命令范围（如 `:10,30McLineAltAll` 或 `:'<,'>McLineHead`）。
* **Count 计数值**：如输入 `5<leader>mh` 针对接下来的 5 行生效。

### 5. 快捷键复用与冲突解决方案
* **未激活多光标时**：`<C-n>` 绝不占用你的全局映射（如查词、跳词等）。
* **启动行模式后**：借助 `multicursor.nvim` 的动态键位层，`<C-n>` 临时作为“向当前模式追加下一行光标”，连按 `<C-n>` 极速扩展。
* **`<M-C-n>` (Alt-Ctrl-N)**：当前模式下一键全选。
* **`<Esc>`**：退出多光标，所有按键立即归还系统默认行为。

---

## 📦 安装与配置 (lazy.nvim)

```lua
{
    "iamcheyan/multicursor-line.nvim",
    dependencies = {
        "jake-stewart/multicursor.nvim",
        branch = "1.0",
    },
    config = function()
        -- 1. 初始化底层引擎 multicursor.nvim
        local mc = require("multicursor-nvim")
        mc.setup()

        -- 2. 初始化本插件
        require("multicursor-line").setup({
            default_mode = "head",      -- 默认模式: "head" | "tail" | "alternate"
            alternate_start = "tail",   -- 交替模式首行位置: "tail" | "head"
            prefix = "<leader>m",       -- 启动快捷键前缀
            dynamic_layer = true,       -- 是否仅在激活期间动态合用 <C-n>
            keymaps = {
                step = "<C-n>",         -- 步进追加下一行
                select_all = "<M-C-n>", -- 一键全选
                standalone_step = false, -- 可选：独立未激活也能按的步进键（如 "<M-n>"）
            },
        })
    end,
}
```

---

## ⌨️ 默认快捷键

| 快捷键 | 模式 | 说明 |
| :--- | :--- | :--- |
| `<leader>mh` | Normal / Visual | 启动行首模式（第 1 行） |
| `<leader>mt` | Normal / Visual | 启动行尾模式（第 1 行） |
| `<leader>ma` | Normal / Visual | 启动首尾交替模式（第 1 行） |
| `<C-n>` *(激活状态)* | Normal / Visual | 向当前模式追加下一行光标 |
| `<M-C-n>` *(激活状态)*| Normal / Visual | 当前模式下一键全选所有目标行 |
| `<leader>mH` | Normal / Visual | 直接全选所有行首 |
| `<leader>mT` | Normal / Visual | 直接全选所有行尾 |
| `<leader>mA` | Normal / Visual | 直接全选所有首尾交替 |
| `<Esc>` | Normal | 清除所有多光标并退出会话 |

---

## 💻 Ex 命令

| 命令 | 支持范围 | 功能说明 |
| :--- | :--- | :--- |
| `:McLineHead` | 是 | 启动行首模式并生成第 1 个光标 |
| `:McLineHeadAll` | 是 | 直接在所有目标行首生成光标 |
| `:McLineTail` | 是 | 启动行尾模式并生成第 1 个光标 |
| `:McLineTailAll` | 是 | 直接在所有目标行尾生成光标 |
| `:McLineAlt` | 是 | 启动首尾交替模式并生成第 1 个光标 |
| `:McLineAltAll` | 是 | 直接对全部目标行应用首尾交替规则 |
| `:McLineClear` | 否 | 清除所有光标与内部会话状态 |
| `:[range]McLine [head\|tail\|alt] [step\|all]` | 是 | 统一参数化命令 |

---

## 📄 开源许可

MIT License © 2026 iamcheyan

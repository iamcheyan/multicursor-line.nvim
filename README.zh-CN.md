# multicursor-line.nvim

> **按行位置快速生成多光标插件**（支持单键逐步扩展与一次全选）  
> 专为 Neovim (0.10+) 打造，基于 [multicursor.nvim](https://github.com/jake-stewart/multicursor.nvim) 的行多光标扩展。

[English](README.md) | [简体中文](README.zh-CN.md)

---

## 💡 设计原则

插件的核心原则是：**“按行逐步生成预定义光标位置”**，而不是搜索字符串生成多光标。

在日常文本编辑、表格对齐、键值对批量转换等场景下，我们通常需要在目标行段的行首、行尾或交替位置排布光标。  
为了彻底摆脱按键冲突与手指疲劳，本插件提供**无修饰键交互层（Single-Key Session Layer）**：
* **无需按 `Ctrl+n`**：彻底告别终端快捷键冲突（如 Kitty 弹新窗口）。
* **纯正 Vim 人体工程学**：通过 `<leader>m[h/t/a]` 唤起后，直接单键 `j`/`n` 顺畅推进。

---

## ✨ 核心功能

### 1. 行首模式 (Head Mode)
在目标范围内的每一行行首（`col = 1`）创建光标：
* 第一次触发：`|aaa`
* 第二次触发：`|aaa` \ `|bbb`
* 第三次触发：`|aaa` \ `|bbb` \ `|ccc`
* 支持一键全选。

### 2. 行尾模式 (Tail Mode)
在目标范围内的每一行行尾创建光标：
* 第一次：`aaa|`
* 第二次：`aaa|` \ `bbb|`
* 第三次：`aaa|` \ `bbb|` \ `ccc|`
* 支持一键全选。

### 3. 首尾交替模式 (Alternating Mode)
在目标行段中按照“行尾 ➔ 行首 ➔ 行尾 ➔ 行首”规律交替放置光标：
* 第一次：`aaa|`
* 第二次：`aaa|` \ `|bbb`
* 第三次：`aaa|` \ `|bbb` \ `ccc|`
* 第四次：`aaa|` \ `|bbb` \ `ccc|` \ `|ddd`
* 支持一键全选。

### 4. 范围支持 (Scope)
* **Visual Line 选区**：在 `V` 模式选好范围后，直接触发即可对选区生效。
* **整个 Buffer**：在 Normal 模式默认从当前行向下扩展至文件结尾。
* **自定义行范围**：支持标准 Ex 命令范围（如 `:10,30McLineAltAll` 或 `:'<,'>McLineHead`）。
* **Count 计数值**：如输入 `5<leader>mh` 针对接下来的 5 行生效。

### 5. 极速单键交互层（零冲突、零疲劳）
通过启动快捷键唤起会话后，进入临时的单键交互状态，无需一直按住 Ctrl：
* **`j` / `n`**：向下一行追加光标（步进）。
* **`k` / `p`**：向上回退一行（撤销最近添加的光标）。
* **`A`**：**全选 / 取消全选切换（Toggle All）**。按一下全选，再按一下恢复单光标。
* **`i` / `a`**：直接在所有已生成的光标位置进入插入模式开始打字！
* **`<Esc>` / `q`**：退出会话并清除多光标。

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
            dynamic_layer = true,       -- 开启单键交互层
        })
    end,
}
```

---

## ⌨️ 快捷键速查

### 1. 会话启动键 (Starters)

| 快捷键 | 模式 | 说明 |
| :--- | :--- | :--- |
| `<leader>mh` | Normal / Visual | 启动行首模式（第 1 行） |
| `<leader>mt` | Normal / Visual | 启动行尾模式（第 1 行） |
| `<leader>ma` | Normal / Visual | 启动首尾交替模式（第 1 行） |
| `<leader>mH` | Normal / Visual | 直接全选所有行首 |
| `<leader>mT` | Normal / Visual | 直接全选所有行尾 |
| `<leader>mA` | Normal / Visual | 直接全选所有首尾交替 |

### 2. 激活期间交互键 (Active Session Keys)

| 按键 | 动作 | 功能说明 |
| :--- | :--- | :--- |
| **`j`** 或 **`n`** | Step Down | 向下追加下一行光标 |
| **`k`** 或 **`p`** | Step Up | 向上回退 / 撤销上一个光标 |
| **`A`** | Toggle All | **全选 / 取消全选切换** |
| **`i`** 或 **`a`** | Insert | 立即在所有光标处进入插入模式 |
| **`q`** 或 **`<Esc>`** | Exit | 退出会话并清除多光标 |

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
| `:[range]McLine [head\|tail\|alt] [step\|all\|toggle]` | 是 | 统一参数化命令 |

---

## 📄 开源许可

MIT License © 2026 iamcheyan

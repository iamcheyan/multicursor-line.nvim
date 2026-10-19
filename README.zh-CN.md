# multicursor-line.nvim

> **按选区位置极速生成多光标插件**（行首 / 行尾 / 首尾交替，支持普通选区与矩形块选区）  
> 专为 Neovim 打造的多光标扩展，支持全光标实时同步打字与退格删除。

[English](README.md) | [简体中文](README.zh-CN.md)

---

## 💡 核心设计理念：先选后按，极简高效

统一针对**用户选中的区域**批量加光标：
- 想给哪些行加，先用 Vim 原生选择方式选中（`Vj` 选两行、`vip` 选段落、`ggVG` 全选、或 `<C-v>` 矩形块选择）。
- 按下对应快捷键，立刻在所有目标位置生成多光标！
- 按 `i` 或 `a`，所有光标**实时打字、实时退格删除**。

---

## 🎯 3 个核心操作

| 操作 | 快捷键 (Visual 模式) | 说明 |
| :--- | :--- | :--- |
| **行首加光标** | `<leader>h` 或 `<leader>mh` | 在所有选中行的**行首**（矩形块模式下为**左边缘**）创建光标 |
| **行尾加光标** | `<leader>t` 或 `<leader>mt` | 在所有选中行的**行尾**（矩形块模式下为**右边缘**）创建光标 |
| **首尾交替加光标** | `<leader>a` 或 `<leader>ma` | 在选中行按**首尾交替**（矩形块模式下按**左右边缘交替**）创建光标 |

> Normal 模式下也支持命令与计数前缀，例如 `5<leader>mh` 向下 5 行行首加光标。

---

## 📐 矩形选区支持 (Visual Block `<C-v>`)

如果你使用 `<C-v>` 拉出了一个矩形框：
- **行首 (`<leader>h`)**：光标整齐排列在矩形框的**最前面（左边缘）**。
- **行尾 (`<leader>t`)**：光标整齐排列在矩形框的**最后面（右边缘）**。
- **首尾交替 (`<leader>a`)**：光标在矩形框的**右边缘与左边缘交替排列**。

---

## ⌨️ 常用工作流程

1. **选中目标行**：
   - 选两行：`Vj`
   - 选一段：`vip`
   - 全选整个文件：`ggVG`
   - 选矩形框：`<C-v>3j4l`
2. **触发模式**：
   - 按 `<leader>h`（行首）/ `<leader>t`（行尾）/ `<leader>a`（首尾交替）
3. **开始编辑**：
   - 按 `i`：在光标处同时输入
   - 按 `a`：在光标后追加输入
   - 按 `c`：批量修改
   - 按 `<Esc>`：退出多光标

---

## 📦 安装与配置 (lazy.nvim)

```lua
{
    "iamcheyan/multicursor-line.nvim",
    dependencies = { "mg979/vim-visual-multi" },
    opts = {
        backend = "vm",             -- "vm" (实时打字) 或 "multicursor"
        alternate_start = "tail",   -- 交替模式首行位置 ("tail" 或 "head")
        create_keymaps = true,      -- 自动注册快捷键
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

## ⚙️ Ex 用户命令

- `:[range]McLineHead`：选区或范围行首加光标（默认当前行）
- `:[range]McLineTail`：选区或范围行尾加光标
- `:[range]McLineAlt`：选区或范围首尾交替加光标
- `:McLineClear`：清除所有光标

---

## 📄 开源许可

MIT License © 2026 iamcheyan

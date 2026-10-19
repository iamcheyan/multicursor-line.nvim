# multicursor-line.nvim

> **按选区位置极速生成多光标插件**（智能首字符前 / 绝对行首 / 行尾 / 首尾交替，支持缩进感知与矩形块选区）  
> 专为 Neovim 打造的多光标扩展，支持全光标实时同步打字与退格删除。

[English](README.md) | [简体中文](README.zh-CN.md)

---

## 💡 核心设计理念：先选后按，极简高效

统一针对**用户选中的区域**批量加光标：
- 想给哪些行加，先用 Vim 原生选择方式选中（`Vj` 选两行、`vip` 选段落、`ggVG` 全选、或 `<C-v>` 矩形块选择）。
- 按下对应快捷键，立刻在所有目标位置生成多光标！
- 按 `i` 或 `a`，所有光标**实时打字、实时退格删除**。

---

## 🎯 核心操作与快捷键

针对代码中普遍存在的**缩进空格**，本插件提供两套行首模式：

| 操作 | 快捷键 (Visual 模式) | 助记分组 | 说明 |
| :--- | :--- | :--- | :--- |
| **首字符前加光标** | **`<leader>h`** 或 **`<leader>i`** | `<leader>mh` / `<leader>mi` | **智能跳过缩进**，光标精准停在每行**第一个非空字符前**（写代码最常用！） |
| **绝对行首加光标** | **`<leader>H`** 或 **`<leader>0`** | `<leader>mH` / `<leader>m0` | 光标停在每行**第 0 列**（最左侧，包含所有缩进空格） |
| **行尾加光标** | **`<leader>t`** | `<leader>mt` | 在所有选中行的**行尾**创建光标（文本末尾之后） |
| **首尾交替 (智能)** | **`<leader>a`** | `<leader>ma` | 奇数行行尾，偶数行**首个字符前（智能跳过缩进）** |
| **首尾交替 (绝对)** | **`<leader>A`** | `<leader>mA` | 奇数行行尾，偶数行**绝对第 0 列（包含缩进）** |

> Normal 模式下也支持命令与计数前缀，例如 `5<leader>mh` 向下 5 行加光标。

---

## 📐 缩进与矩形选区示例

### 1. 缩进代码演示 (以 JSON / Python 为例)
```json
  "about_title": "COBOL 是什么",
  "gnucobol_title": "GnuCOBOL 官方编译器",
    ("课程与示例", "固定格式 COBOL 源码"),
```
- 按 **`<leader>h`**（首字符前）：光标自动对齐到各行的 `"about_title"`、`"gnucobol_title"` 和 `("课程` 前，各行即使缩进深度不同也能完美自适应！
- 按 **`<leader>0`**（绝对行首）：所有光标统一落在最左侧第 1 列。

### 2. 矩形选区支持 (Visual Block `<C-v>`)
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
   - 按 `<leader>h`（首字符前）/ `<leader>0`（绝对行首）/ `<leader>t`（行尾）/ `<leader>a`（首尾交替）
3. **开始编辑**：
   - 按 `i` 或 `a`：开始同时打字
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
    },
}
```

---

## ⚙️ Ex 用户命令

- `:[range]McLineHead`：选区或范围首个非空字符前加光标
- `:[range]McLineBol`：选区或范围绝对行首第 0 列加光标
- `:[range]McLineTail`：选区或范围行尾加光标
- `:[range]McLineAlt`：选区或范围智能首尾交替加光标
- `:[range]McLineAltBol`：选区或范围绝对首尾交替加光标
- `:McLineClear`：清除所有光标

---

## 📄 开源许可

MIT License © 2026 iamcheyan

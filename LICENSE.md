# 授权 / Licensing

本仓库包含三类内容，授权各不相同。

## 0. 生成方式

本仓库的**译文、文档与本项目自有的工具脚本均由 [DeepSeek](https://www.deepseek.com/)（AI）生成**，
经自动化校验工具链检查后发布，**未经过人工逐条审阅**。
仅对其 README 中标注的那一个游戏版本做过实测，其他版本未测试。

## 1. 译文（`ZH-CN/Strings.xml`、`docs/GLOSSARY.md`）

本项目的简体中文译文，采用
**Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)** 授权。

你可以自由地共享与改编，条件是：

- **署名**：注明来源于本项目
- **相同方式共享**：改编后的作品必须以相同授权发布

完整条款：https://creativecommons.org/licenses/by-sa/4.0/

## 2. 字体（`ZH-CN/SansSC-Regular.otf`）

**Noto Sans SC**，版权归 The Noto Project Authors 所有，
采用 **SIL Open Font License 1.1** 授权。

完整授权文本见 [`ZH-CN/OFL.txt`](ZH-CN/OFL.txt)。

SIL OFL 允许自由使用、研究、修改与再分发（包括随软件一起分发），
条件是保留授权文件，且不得单独售卖字体本身。

## 3. 工具链（`src/`、`tests/`）

本项目原创的 PowerShell 脚本，采用 **MIT License** 授权。

```
MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## 4. 游戏本体

《Juno: New Origins》版权归 **Jundroo, LLC** 所有。

本仓库：

- **不包含**游戏本体的任何原始资产、可执行文件、着色器或音频
- **不包含**英文原文整表（`id` 作为键保留，这是语言包机制的要求）
- 字符串 `id` 归 Jundroo 所有

本包通过游戏官方提供的 `Languages/` 语言包机制工作，**不修改游戏本体任何文件**。
本项目为非官方同人作品，与 Jundroo 无隶属关系。

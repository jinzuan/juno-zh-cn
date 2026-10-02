# Juno: New Origins — 简体中文语言包

Steam 版《Juno: New Origins》的非官方简体中文语言包。

游戏 1.4 起支持 `Languages/` 语言包机制，且**刻意不内置任何语言**，把本地化交给社区。
本仓库提供完整简中译文、配套字体与一套可复现的校验工具链。

## 适配版本

| 项 | 值 |
|---|---|
| **游戏版本** | **1.4.105.0c** |
| **Steam 分支** | `public`（正式版，非 beta / 非 open-beta） |
| Steam buildid | 24658847 |
| 字符串总数 | 9,271 条 |
| 验证日期 | 2026-10-02 |

### 游戏更新后怎么办

语言包**只覆盖它认识的那些 `id`**；游戏若新增字符串，新 `id` 不在本包里，
界面会**回退显示英文**——**不会报错、不会崩**，只是那几条还是英文。

想核实是否有新增字符串，跑一次抽取并比对条数：

```powershell
# 从当前游戏的 EN-US/Strings.xml 重新抽取
powershell -NoProfile -ExecutionPolicy Bypass -File src\extract-strings.ps1

# 看条数是否仍是 9,271
(Get-Content src\strings.json -Raw -Encoding UTF8 | ConvertFrom-Json).Count
```

**条数变多 = 游戏加了新字符串**，多出来的 `id` 就是待补翻的部分。

另外，游戏有时会**重写自己的 `EN-US/Strings.xml`**（实测看到过它规范化空白，
如把 `"thrust. \n"` 改成 `"thrust.\n"`）。这属正常行为，不影响本包。

## 语言包覆盖不到的部分（有意保留）

装上本包后，下面这些**仍然是英文**。这不是漏翻，而是它们不走 `Languages/` 机制：

### 1. 预设飞行器名

```
UserData/CraftDesigns/SimpleATV.xml  SimpleBeast.xml  SimpleBot.xml ...
```

名称取自**文件名或文件内的标识字段**，属于游戏数据不是界面文案。
实测游戏目录里搜不到集中存放处（`resources.assets` 中 `CraftDesigns/` 为空引用）。

**为什么不去改**：那要动 40+ 个设计文件，且属游戏数据而非语言包——
上传/分享飞行器时名字会跟着变，也会和别人的设计混淆。
本包的名分是"一个文件夹即插即用"，改数据文件就破坏了这个边界。

### 2. 「更新内容」（What's New）

游戏在运行**联网获取**这段文本，本地没有任何 changelog 文件。
语言包里只有它的标题和失败提示：

```
MenuUi.WhatsNew.Title  = 更新内容      ← 已汉化
Menu.WhatsNew.ErrorOne = 无法获取"新内容"文本…请稍后重试。  ← 已汉化
```

**正文结构上无法汉化**，除非改游戏代码。

### 3. 天体名（Droo / Luna / Brigo … 共 22 个）

这些**在语言包里、技术上可改**：

```
Planets.Droo.Name   EN='Droo'   ZH='Droo'    ← 保留原文
Planets.Luna.Name   EN='Luna'   ZH='Luna'
```

**为什么保留原文**：

- 天体名同时存在于 `GameData/CelestialDatabase/` 的 XML 里（`name="Boreas"`），
  以及飞行器设计文件中**按名字引用行星**。只改显示名会造成游戏内两套叫法。
- 合同描述大量内联引用天体名（`@Planet`、`@Moon` 变量替换），
  译名会散落在正文里，且与飞行器/存档里的引用不一致。
- 中文航天社区惯用原文名（KSP 的 Kerbin/Mun 也都保留原文）。

### 4. 天体 XML 内的修改器名

`GameData/CelestialDatabase/**/*.xml` 里有 `name="Simple biomes"`、
`name="Get constant"` 这类属性。**技术上可改，但不建议**：
那不属于 `Languages/` 机制，**游戏更新会覆盖**，且会让本包从
"不修改游戏本体任何文件"变成"要改游戏数据"。

### 5. 按键名与单位符号

按键名（`Left Shift`、`Caps Lock`…）、单位符号（`m/s`、`km`、`TP`…）、
数学函数名（`sin`、`atan`…）、型号名（`FXAA`、`RTG`、`RCS`…）
**一律保留原文**——译成中文反而对不上键盘和缩写的实际含义。

## 安装

1. 打开语言目录（Windows）：

   ```
   %USERPROFILE%\AppData\LocalLow\Jundroo\SimpleRockets 2\Languages\
   ```

2. 把本仓库 `ZH-CN/` 整个文件夹复制进去，最终结构：

   ```
   Languages\ZH-CN\
       Strings.xml             译文
       Fonts.xml               字体声明
       SansSC-Regular.otf      完整中文字体（Noto Sans SC，30,892 码位）
       OFL.txt                 字体授权（SIL OFL 1.1，务必保留）
   ```

3. 让游戏使用中文。游戏内**没有语言选择器**（官方说明：选择器只在检测到非 EN-US
   语言时出现，且各版本表现不一），最可靠的方式是直接改设置：

   用文本编辑器打开

   ```
   %USERPROFILE%\AppData\LocalLow\Jundroo\SimpleRockets 2\Settings.xml
   ```

   把 `<General ... language="EN-US" />` 改成 `language="ZH-CN"`，保存后启动游戏。

4. **卸载**：删掉 `Languages\ZH-CN\` 文件夹，并把 `language` 改回 `EN-US`。
   本语言包不修改游戏本体任何文件。

## 为什么需要自带字体

游戏内置的 `SansSC-Regular.otf` 是**官方示例用的子集字体，只有 493 个码位**
（官方注释原文：*"DEMO font: a subset with only the ~14 glyphs used by this
folder's sample strings. Replace with a full-coverage Chinese font (e.g. Noto
Sans SC) before shipping."*）。

**所以不装本包时，游戏的中文界面本身就是缺字的**——这不是本包引入的问题。
本包附带完整版 Noto Sans SC（30,892 码位），并用 cmap 解析验证覆盖全部已用汉字。

## 术语标准

术语唯一真源是 [`docs/GLOSSARY.md`](docs/GLOSSARY.md)。几条核心裁决：

| 英文 | 采用 | 依据 |
|---|---|---|
| `apoapsis` / `periapsis` | **远点 / 近点** | 与 KSP 官方中文本地化一致（`#MechJeb_Apoapsis = 远点`）；KSP 语料中简式 59 次全在 UI 标签，全式 26 次全在专业发动机名 |
| `reaction wheel` | **反作用轮** | 有 `反作用轮扭矩 // Reaction Wheel Torque` 直接对应；「动量轮」指 CMG，严格说不是同一种装置 |
| `craft` | **飞行器** | Juno 原文 `craft` 出现 424 次，是主用词 |
| `gyroscope` | **陀螺仪** | Juno 用 `Gyroscope` 而非 `reaction wheel` |
| `biome` | **生物群系** | Juno 中 `biome` 出现 143 次，是 PlanetStudio 的核心概念 |

术语表建立时参照了本机《坎巴拉太空计划》的官方中文词典与社区汉化补丁
（`dictionary.cfg` 891 KB / 15,294 条中文），因为这些词在航天建造模拟游戏里高度通用。

## 工具链

本仓库的 `src/` 里是一套可复现的 PowerShell 脚本，**全部零第三方依赖**
（Windows PowerShell 5.1 自带即可）。

```
src/extract-strings.ps1   从游戏 EN-US/Strings.xml 抽取原文与元数据
src/make-batches.ps1      按模块切片，支持大模块劈分与断点续做
src/merge.ps1             汇总各批译文，含前后空白自动校正
src/validate.ps1          质量闸门（占位符/标签/id/换行/空白/宽度）
src/pack.ps1              生成 Strings.xml，含 XML 回环验证
src/check-font.ps1        解析字体 cmap 表，验证字形覆盖度
```

### 典型用法

```powershell
# 抽取原文（需要本机装有游戏）
powershell -NoProfile -ExecutionPolicy Bypass -File src\extract-strings.ps1

# 校验字体覆盖（cmap 解析，非渲染测试）
powershell -NoProfile -ExecutionPolicy Bypass -File src\check-font.ps1 `
    -FontPath ZH-CN\SansSC-Regular.otf -TextFile reports\charset.txt

# 校验译文（结构性错误才判失败；退出码 0/1）
powershell -NoProfile -ExecutionPolicy Bypass -File src\validate.ps1 `
    -Original src\strings.json -Translated pack\strings.zh.json
```

## 翻译时必须注意的坑

这些坑都是实测踩出来的，工具链已经对每一类都做了自动检查。

### 1. 换行有两种形态，不能互转

源文件**故意混用**：

| 形态 | 条数 | 含义 |
|---|---|---|
| XML 数字实体 `&#10;` | 81 | 真换行 |
| 字面反斜杠 n（`\n` 两个字符） | 22 | 很可能是游戏识别的转义序列 |

译者若"统一成一种"，就会把转义序列变成字面文本，游戏里显示成 `\n`。
**校验器分别计数比对，逐类相等才算通过。**

### 2. 前后空白是布局意图，只能补不能删

40 条原文以空格结尾、23 条以前导空格开头。例如 FPS 计数器原文是 `AVG: `，
界面把数值直接拼在后面，译文写成 `平均：` 就会渲染成 `平均：60`。

**实测：三个互相独立的翻译批次，24 条尾随空格 100% 被丢掉**——这不是译者疏忽，
是翻译模型的固有倾向（会顺手清理尾部空白）。所以由代码在 `merge.ps1` 里强制补回。

### 3. XML 必须转义，且要与官方写法一致

官方 `Strings.xml` 用 **XML 数字实体**：`&#10;` 换行、`&lt;b&gt;` 富文本标签、
`&amp;` 和号。抽取时解码成真字符是对的，**但写出时必须还原成实体形式**。
初版打包器写成裸换行，导致与源文件 81 条表达方式不一致。

### 4. `ReadElementContentAsString()` 会吞掉注释

元数据（`Px` 宽度预算、上下文）存在**注释**里，不在元素属性里：

```xml
<!-- Px:115 Size:16 Font:Primary ; credits job label -->
<s id="About.Job.Art">Art</s>
```

实测：用 `XmlReader.ReadElementContentAsString()` 读文本 → 只能读到 **10 条**注释；
改为逐节点手工收集、在 `EndElement` 处 break → **9,280 条**。

### 5. 注释与文本不是一一交替，不能用线性游标配对

注释 9,280 条、`<s>` 9,271 条，**多 9 条**。线性游标一旦遇上孤立注释，
后面**全部条目的 Px 预算会整体错位，而且不报错**。
对策：用 `IXmlLineInfo` 按**源文件行号**配对。

### 6. 字体覆盖度不能用渲染法测

用"渲染出来有没有像素"判断字形存在与否会给出**假阳性**：
.NET 的 `PrivateFontCollection` 在缺字形时会静默回退到系统字体，
你看到的像素来自系统字体。实测：57 KB 的示例子集被渲染测试判为"22/22 全覆盖"。

**正确做法是解析字体自己的 `cmap` 表**——那是字体声明的字符→字形映射，
不经过渲染引擎。`src/check-font.ps1` 实现了 cmap 格式 4/12/6/0 的解析。

### 7. UI 宽度预算 `Px` 不是为中文设的上限

`Px` 是"英文在这个框里放得下"的实测值。实测反例：原文
`Jetpack Pitch (modifier)`（32 字符）与译文 `喷气背包俯仰（修饰键）`（10 汉字），
按 Px 判会得出"中文超宽"——这不可能。

**校验器改用双条件**：译文既超 Px、又超英文原文宽度，才判超宽。

## 质量保证

`validate.ps1` 是质量闸门，带**反向测试夹具**证明它有效：

| 夹具 | 预期 | 实测 |
|---|---|---|
| 身份翻译（`zh = en`） | 结构性 0 违规 | ✅ 0 |
| 故意埋 6 个缺陷 | 全部抓到 | ✅ 6/6，零漏报 |
| 故意破坏 4 条换行 | 全部抓到 | ✅ 4/4，共 6 处 |

校验项目：占位符守恒（含 `{0:n1}` `{4:F1}` `{:.0}` 等 21 种形态）、富文本标签守恒、
id 集合一致、空译文、**换行形态守恒**、**前后空白守恒**、UI 宽度。

`pack.ps1` 生成 XML 后做**回环验证**：重新解析、逐条比对 `id→text`、
确认占位符未被转义破坏。另用与打包器不同的 `XmlDocument` 实现做过独立端到端验证。

## 授权

- **本语言包的译文**：由本项目翻译，按 [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) 发布
- **字体** `SansSC-Regular.otf`：Noto Sans SC，SIL Open Font License 1.1，
  完整授权见 [`ZH-CN/OFL.txt`](ZH-CN/OFL.txt)

本包**不含**游戏本体的任何原始资产、可执行文件或英文原文整表。
字符串 `id` 归 Jundroo 所有，本包只提供对应译文。

《Juno: New Origins》版权归 Jundroo, LLC 所有。本项目为非官方同人作品，
与 Jundroo 无隶属关系。

## 贡献

欢迎修正译文。提交前请跑一遍：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File src\validate.ps1 `
    -Original src\strings.json -Translated <你的译文文件>
```

**退出码必须是 0。** 结构性违规（占位符丢失、标签不匹配、换行形态改变）会直接
导致游戏显示崩坏，不会被合并。

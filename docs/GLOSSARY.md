# 术语标准（权威版）

> 本文件是《Juno: New Origins》简体中文语言包的**术语唯一真源**。
> 翻译时必须遵守；与直觉冲突时以本文件为准；发现错误时改本文件，不要各自另译。

## 来源

| 来源 | 说明 | 权威性 |
|---|---|---|
| `ksp-terms.json` | 从本机 KSP 官方中文字典 + 社区汉化补丁提取 | **高**（有英文↔中文直接对应） |
| `public-terms.json` | 公开航空航天标准（子任务产出） | 中（待收） |
| 本篇裁决 | 对冲突项的人工裁定，附证据 | **最高** |

**KSP 素材里最有价值的是"英文标签 // 中文"这种并排注释**——它直接给出了对应关系，
而不是靠猜。例如：

```
#MechJeb_Apoapsis = 远点                          // 键名即 Apoapsis
#LOC_SystemHeat_ToolbarPanel_VelocityTitle = 速度 // Velocity
@text = 高度警报                                  // ALTITUDE WARNING
```

## 先看事实：Juno 和 KSP 的词汇并不重合

**裁决必须基于 Juno 实际出现的词，不能照搬 KSP。** 对 9,271 条原文做了词频统计：

| 词 | KSP 有 | **Juno 里** | 结论 |
|---|---|---|---|
| `decoupler` | ✅ 分离器 | **0 处** | Juno 不用这个词 |
| `separator` | ✅ 切分器 | **0 处** | 同上 |
| `reaction wheel` | ✅ | **0 处** | Juno 用 `Gyroscope` |
| `probe core` | ✅ | **0 处** | Juno 用 `Command Chip`/`Command Disc` |
| `radiator` | ✅ | **0 处** | Juno 无此零件 |
| `action group` | ✅ | **0 处** | Juno 无此概念 |
| `quicksave` | ✅ | **0 处** | Juno 无此概念 |
| `craft` | 少 | **424 处** | **Juno 的主用词** |
| `vessel` | ✅ 主用词 | **2 处** | KSP 的主用词在 Juno 里几乎不用 |
| `engine` | ✅ | 182 处 | |
| `motor` | ✅ | 56 处 | **指电动机，不是火箭发动机** |
| `stage` | ✅ | 126 处 | 分级 |
| `biome` | ✅ | **143 处** | 核心概念（PlanetStudio） |
| `torque` | ✅ | 33 处 | 力矩 |
| `gyroscope` | ✅ | 18 处 | 姿态控制 |
| `gimbal` | ✅ | 7 处 | |
| `heat shield` | ✅ | 5 处 | |
| `sphere of influence` | ✅ | 11 处 | |
| `angle of attack` | ✅ | 3 处 | 仅 Vizzy 属性 |

**所以 KSP 术语表里 decoupler/separator/reaction wheel/probe core 那几条对本包无用。**
真正要紧的是 Juno 自己的零件体系。

## Juno 真实零件词汇（从 DesignerParts 实测）

```
Command Pod / Command Chip / Command Disc   指令舱 / 指令芯片 / 指令盘
Cockpit / Cockpit Base / Cockpit Canopy     座舱 / 座舱底座 / 座舱罩
Gyroscope                                   陀螺仪          ← 不是 reaction wheel
RCS Nozzle                                  反应控制喷口
Docking Port                                对接口
Interstage                                  级间段          ← 不是 decoupler
Fairing / Fairing Base / Fairing Nose Cone  整流罩 / 整流罩底座 / 整流罩头锥
Jettison (Spin / Speed)                     抛弃（自旋 / 速度）
Heat Shield                                 隔热盾
Fuel Tank / Fuel Adapter / Fuel Cell        燃料箱 / 燃料转接器 / 燃料电池
Electric Motor                              电动机          ← motor 是电动机
Solid Booster / Solid Motor                 固体助推器 / 固体发动机
Ion Engine / Apex Engine ...                离子引擎 / Apex 引擎 …
Landing Leg / Airplane Landing Gear         着陆支架 / 飞机起落架
Solar Panel / Battery Pack / Battery Tank   太阳能板 / 电池组 / 电池罐
Strut / Fin / Hinge Rotator / Cargo Bay     支柱 / 尾翼 / 铰链旋转器 / 货舱
```

## 单位符号不译（重要）

**`TP`、`m/s`、`km`、`kg`、`t`、`kN`、`°`、`Nm`、`Pa`、`B`、`y` 这类单位符号一律不译。**

理由是规则要一致：`{0:n1} days` 里的 `{0:n1}` 是格式化说明符，我们不译；
`{0}TP` 里的 `TP` 同理，是单位符号。

**实测教训**：Menu 批次曾把 `{0}TP` 译成 `{0} 科技点`，导致出现
`• 科技点：{0} 科技点` 这种重复。已改回 `• 科技点：{0}TP`。

反例（**要译**的）：`days`/`hours`/`years`/`meters`/`feet`/`bytes` 这类**单位全名**要译。
判据：**符号不译、全名译**。

## UI 与业务术语（Menu 批次确立，全包统一）

| 英文 | 中文 | 英文 | 中文 |
|---|---|---|---|
| craft | 飞行器 | contract | 合同 |
| vessel | 载具 | milestone | 里程碑 |
| command pod | 指令舱 | landmark | 地标 |
| command chip | 指令芯片 | tech tree | 科技树 |
| command disc | 指令盘 | tech points | 科技点 |
| cockpit | 座舱 | funds / money | 资金 |
| gyroscope | 陀螺仪 | planetary system | 行星系 |
| RCS nozzle | 反应控制喷口 | launch location | 发射地点 |
| docking port | 对接口 | debris | 残骸 |
| interstage | 级间段 | rover | 漫游车 |
| fairing | 整流罩 | stock craft | 预设飞行器 |
| jettison | 抛弃 | mod | 模组 |
| heat shield | 隔热盾 | sandbox | 沙盒 |
| fuel tank | 燃料箱 | career | 生涯 |
| fuel adapter | 燃料转接器 | resumable | 可恢复 |
| fuel cell | 燃料电池 | flight scene | 飞行场景 |
| electric motor | 电动机 | staging | 分级 |
| solid booster | 固体助推器 | stages（数量） | 级数 |
| ion engine | 离子引擎 | wet/dry mass | 湿质量 / 干质量 |
| landing leg | 着陆支架 | biome | 生物群系 |
| solar panel | 太阳能板 | sphere of influence | 引力影响范围 |
| battery pack | 电池组 | angle of attack | 迎角 |
| cargo bay | 货舱 | gimbal range | 矢量范围 |
| hinge rotator | 铰链旋转器 | center of mass | 质心 |

## 设置与图形术语（Settings 批次确立）

| 英文 | 中文 | 英文 | 中文 |
|---|---|---|---|
| modifier (key) | 修饰键 | ambient light | 环境光 |
| activation group | 激活组 | camera shake | 镜头震动 |
| flyout panel | 弹出面板 | chase camera | 追踪镜头 |
| prograde / retrograde | 顺行 / 逆行 | field of view | 视场角 |
| time warp | 时间加速 | normal map | 法线贴图 |
| fast forward / slow-mo | 快进 / 慢动作 | detail texture | 细节贴图 |
| nav sphere | 导航球 | ambient occlusion | 环境光遮蔽 |
| tether | 系绳 | anamorphic flare | 变形光晕 |
| strafe | 横移 | bloom | 泛光 |
| EVA | 舱外活动 | tonemapping | 色调映射 |
| nudge part | 微调零件 | anti-aliasing | 抗锯齿（FXAA/MSAA 保留原文） |
| paint tool | 涂装工具 | refresh rate | 刷新率 |
| collider | 碰撞体 | V-Sync | 垂直同步 |
| part fracturing | 零件碎裂 | resolution scale | 分辨率缩放 |
| debris retention | 残骸保留 | cubemap | 立方体贴图 |
| rag-doll physics | 布娃娃物理 | skybox | 天空盒 |
| tire tracks | 轮胎痕迹 | anisotropic filtering | 各向异性过滤 |
| heat distortion | 热浪扭曲 | analytics | 数据分析 |
| re-entry | 再入 | privacy options | 隐私选项 |
| vapor trail | 尾迹 | preset | 预设 |
| plasma | 等离子 | Mach | 马赫数 |
| structure（地形上的） | 设施 | | |

### quality 的分用（防歧义）

| 语境 | 译法 | 例子 |
|---|---|---|
| 图形/画质选项 | **画质** | 画质预设 |
| 其余语境 | **品质** | 碰撞体品质、粒子效果品质 |

**理由**：`mass` 已占「质量」，若 quality 也译「质量」会造成歧义。

### 档位词统一

```
Very Low → 极低    Low → 低     Medium → 中
High → 高          Very High → 极高    Ultra → 超高
Off → 关闭    On → 开启    None → 无
Disabled → 禁用（选项值） / 已禁用（状态值）
Enabled  → 启用（选项值） / 已启用（状态值）
```

### 按键名与设备名不译

`Settings.Controls.Key.*` 共 22 条（`Up` `Down` `Left` `Right` `Tab` `Space`
`Enter` `Esc` `Insert` `Home` `End` `Delete` `Caps Lock` `Backspace`
`Page Up` `Page Down` `Left|Right Shift` `Left|Right Ctrl` `Left|Right Alt`）
**一律保留英文原样**。

理由：这些是键帽上的实际印字，译成中文反而对不上键盘。同理 `Keyboard`
以及 `FXAA` / `MSAA` / `RCS` / `TP` 这类缩写也保留。

## 核心裁决：远点 / 近点（附证据）

这是整套术语里最重要也最容易翻错的一对。

| 英文 | 本包采用 | 备选 | 证据 |
|---|---|---|---|
| `apoapsis` | **远点** | 远地点 | `#MechJeb_Apoapsis = 远点`；`输入轨道远点: // Enter Orbit Apoapsis:` |
| `periapsis` | **近点** | 近地点 | `#autoLOC_AmpYear_1000298 = 输入轨道近点: // Enter Orbit Periapsis:` |

### 为什么不用"远地点/近地点"

两个词都有据可查，但**使用场合不同**，实测分布：

| 词形 | 在 KSP GameData 中出现 | 场合 |
|---|---|---|
| `远点` / `近点` | **59 次** | **UI 标签、数值显示、MechJeb 面板** |
| `远地点` / `近地点` | 26 次 | 专业发动机名（"双组元远地点发动机"）、轨道力学正文 |

**Juno 里的 `Apoapsis`/`Periapsis` 全部是 UI 标签和数值属性**（`Flight.MapView.Orbit.Apoapsis`、
`Vizzy.CraftProperty.Orbit.Apoapsis`、`Menu.ActiveCrafts.Details.Apoapsis` 等 60+ 处），
场合与 KSP 的 UI 用法完全一致。

UI 标签有宽度预算（`Px:` 限制），`远点` 比 `远地点` 少一个字，
在窄按钮上更安全。**体裁一致 + 宽度更优，采用简式。**

### 但正文里要说清楚

教程、任务描述等**正文**中出现时，若语境是科普性解释而非数值标签，
可以写"远点（远地点）"以便理解——**但数值标签一律只用"远点/近点"**。

## 已确证的术语（英文↔中文直接对应）

以下每一条都有 KSP 素材里的并排注释佐证，不再需要讨论：

| 英文 | 中文 | 证据来源 |
|---|---|---|
| apoapsis | 远点 | MechJeb zh-cn.cfg |
| periapsis | 近点 | AmpYear ZH_AmpYear.cfg |
| altitude | 高度 | ALTITUDE WARNING |
| velocity | 速度 | SystemHeat ToolbarPanel |
| inclination | 轨道倾角 | MechJeb inclination_label |
| thrust | 推力 | AIES 参考术语注释 |
| delta-v | Δv（保留原文） | KSP 正文沿用 deltaV |
| command pod | 指令舱 | KSP |
| fuel tank | 燃料箱 | KSP |
| decoupler | 分离器 | KSP |
| fairing | 整流罩 | KSP |
| nose cone | 头锥 | KSP |
| adapter | 转接器 | KSP |
| docking port | 对接口 | KSP |
| reaction wheel | 动量轮 | KSP |
| heat shield | 热防护罩 | KSP |
| radiator | 散热板 | KSP |
| parachute | 降落伞 | KSP |
| strut | 支柱 | KSP |
| staging | 分级 | KSP |
| throttle | 节流阀 | KSP-adjacent |
| orbit | 轨道 | KSP |

## 三组必须拆开的近义术语

KSP 素材自己承认这里有混用问题（`"Squad 在部分键上把两者混用，需注意区分"`），
所以必须人工拆开，否则 Juno 的零件列表会出现两个都叫"分离器"的东西。

### 1. `reaction wheel` → **反作用轮**（不用"动量轮"）

| 候选 | 出处 |
|---|---|
| 动量轮 | Squad dictionary.cfg |
| **反作用轮** | VABOrganizer `"Reaction Wheel Torque"` → `反作用轮扭矩` |

**采用"反作用轮"**：这是航天领域标准术语（全国科技名词审定委员会用词），
且在 KSP 里有英文↔中文的并排对应证据。`动量轮` 是航天器姿态控制的另一类装置
（CMG，控制力矩陀螺），严格说**不是同一种东西**，用作译名会造成技术性错误。

### 2. `decoupler` vs `separator` —— 必须区分

| 英文 | 采用 | 理由 |
|---|---|---|
| `decoupler` | **分离器** | 级间分离的标准叫法 |
| `separator` | **分离环** | 与上者区分；KSP 素材给"切分器"，但中文里"切分"偏向数学/文本语境，不适合零件名 |

素材同时给出 `decoupler` 的备选"分离环"，两者重叠。**裁决：以功能区分**
——`decoupler` 承担级间结构连接 → 分离器；`separator` 是主动分离机构 → 分离环。

### 3. `engine` —— 标签与正文分用

| 场合 | 用词 | 理由 |
|---|---|---|
| UI 标签、零件名 | **引擎** | KSP 社区惯用；且标签有宽度预算，"引擎"更短 |
| 教程/任务正文 | **发动机** | 正式文体 |

## 使用方式

翻译时把本文件作为**强约束**注入每个翻译批次：

1. 表中出现的词，**必须**用表中译法，不得同义替换
2. 同一英文词在全包内必须译法一致（校验器可查）
3. 遇到本表未覆盖的新术语，**先补进本表再翻译**，不要就地决定

## 变更记录

| 日期 | 变更 |
|---|---|
| 2026-10-02 | 建立；裁决 apoapsis/periapsis 采用简式，附 KSP 证据 |

# Vizzy 模块术语补充（本模块强约束）

> 本文件是 `GLOSSARY.md` 的 Vizzy 模块补充，由 Vizzy 批次译者建立。
> **优先级**：`GLOSSARY.md` 通用条款 > 本文件 > 直觉。冲突时以更严格的一方为准。
> 收尾时应把本文件的表格合并回 `GLOSSARY.md`。

## 0. Vizzy 的字符串分三类，处理方式不同

| 类型 | ctx / id 前缀 | 说明 |
|---|---|---|
| **积木块格式串** | `Vizzy.Toolbox.Format.*` | 图形化积木上显示的文字，含大量**运行时 token**，见 §2 |
| **UI 名称/标签** | `Vizzy.Instruction.*`、`Vizzy.CraftProperty.*`（短标签）、`Vizzy.Toolbox.Category.*`、`Vizzy.UI.*` | 正常翻译，注意宽度 |
| **说明与提示** | `Vizzy.*.Tooltip.*`、`Vizzy.UI.*.Message/Confirm/Error` | 自然中文，可稍长 |

## 1. 铁律（违反即整批作废）

1. 条目数与 `id` 与输入 `.todo.json` **完全一致**（大小写标点不许动，不许重排）。
2. `{0}` `{1}` `{0:n1}` `{0:F1}` 等花括号占位符**整串照抄**。
3. 富文本标签原样保留：`[highlight]` `[/highlight]` `<br>` `<color=...>` `</color>`
   `<size=...>` `</size>` `<b>` `</b>`。
4. 原文尾部有空格 → 译文尾部同样个数的空格（`format `、`join ` 就是靠这个空格拼接）。
5. `\n` 分两种，**不得互转**：
   - **真换行**（JSON 里写 `\n`）→ 译文同样位置保留真换行；
   - **字面反斜杠 + n**（JSON 里写 `\\n`）→ 译文保留字面 `\n` 两个字符。
6. **句子末尾标点跟原文对齐**：原文是完整句子并以 `.` 结尾 → 译文以 `。` 结尾
   （这是本项目既有约定，实测 `Modifier.p1.zh.json` 里 117 条中 116 条如此）；
   原文没有句号（按钮标题、积木标签、简短属性名）→ **不许自己加 `。`**。
   不删减信息、不改文体。
7. 数学函数名**保留原文小写**：`sin cos tan asin acos atan sqrt abs floor ceiling round ln log
   deg2rad rad2deg atan2 clamp cross dot dist norm project scale angle length min max x y z`。
   向量运算符同理不译。
8. 单位符号不译：`Hz` `m/s` `m/s2` `kg` `kg/m3` `N` `Pa` `K` `rad/s` `PCI` `AGL` `ASL` `SOI` `ID`
   `MFD` `PID` `Isp` `TWR` `Δv` `TP`。**单位全名要译**（seconds→秒、meters→米、kilograms→千克）。

## 2. 积木块里的运行时 token（**必须整串照抄，位置可调整**）

| token 形态 | 例 | 处理 |
|---|---|---|
| `(n)` `(n:Type)` | `(0)` `(1:ZeroOrMore)` `(0:Number)` `(2:OneOrMore)` `(1:ZeroToOne)` `(0:NegOneToPosOne)` | **原样保留**，只能挪位置 |
| `[x]` `[op]` `[waveform]` `[friendly]` | `altitude [x]`、`(0) [op] (1)` | **原样保留**（这是下拉选择内容的占位，不是正文，**不许译不许删**） |
| `\|Key.Name\|` | `\|Vizzy.EventVariable.Planet\|` | **原样保留**（这是对其他 id 的引用） |
| `\|i\|` | `for \|i\| from (0) to (1) by (2)` | **原样保留**（循环变量名） |

> `check-batch.ps1` **不检查** `(n:Type)`、`[x]`、`|Key|`，所以必须人工/脚本额外核对。
> 顺序可以按中文语序调整，例如 `atan2 of (0) and (1)` → `(0) 与 (1) 的 atan2`。

## 3. 保留英文原文的条目（不要译，这是工程决定）

以下不是"漏译"，是**故意保留**，因为它们是程序里的标识符或运行时名字：

- `Vizzy.EventVariable.*` 全套：`part` `planet` `craftA` `craftB` `other` `velocity` `impulse` `data`
  ——事件绑定的变量名，译成中文会让程序文本里的变量名非法（见 `Vizzy.UI.CreateVariable.Message`
  「只允许字母和数字」）。
- `Vizzy.Toolbox.Default.CraftName` = `CraftName`、`PartName` = `PartName`、
  `Item` = `item`、`Name` = `name`、`TextValue` = `text`、`Message` = `message`
  ——积木输入框的默认标识符。
- `Vizzy.Toolbox.Default.CommentText`（`Comment Text`）→ `注释文本`；
  `Vizzy.Toolbox.Default.MessagePrompt`（`Message Text…`）→ `消息文本…`
  ——这两条是纯提示文本，要译。
- `Vizzy.UI.*.Placeholder` / `PlaceholderText` 是输入框的幽灵提示文字，**要译**
  （`ParameterName`→`参数名称`、`VariableName`→`变量名称`、`PROGRAM NAME`→`程序名称`、
  `Expression Name`→`表达式名称`）。
- `Vizzy.Toolbox.Format.evaluate-expression` = `<color=#0f0>f<color=#f0f>U<color=#ff0>N<color=#f00>k (0)`
  ——彩色拼写的 "fUNk"，**整串原样保留**。
- 纯符号块：`(0:Number) + (1:Number)`、`-`、`*`、`/`、`%`、`^`、`=`、`>`、`>=`、`<`、`<=`、
  `(0) [op]`、`(0) [op] (1)` —— 译文与原文完全相同。
- `Vizzy.UI.CreateVariable.Message` 的首行 `CREATE VARIABLE` 是**标题**，要译成 `创建变量`
  （换行保留）；`Vizzy.UI.*.Label` 全大写是按钮标题，译成简短中文。

## 4. Vizzy 术语表（必须使用）

### 4.1 指令名（`Vizzy.Instruction.*`，显示在工具箱列表，宽度充裕但求短）

| en | zh | en | zh |
|---|---|---|---|
| Activate Stage | 激活分级 | Log Flight | 记录飞行日志 |
| Break | 跳出 | Log Message | 记录消息 |
| Broadcast Message | 广播消息 | Loop | 循环 |
| Call Custom Instruction | 调用自定义指令 | Play Beep | 播放蜂鸣 |
| Change Variable | 修改变量 | Program | 程序 |
| Comment | 注释 | Repeat | 重复 |
| Custom Instruction | 自定义指令 | Set Activation Group | 设置激活组 |
| Display Message | 显示消息 | Set Camera Property | 设置相机属性 |
| Else If | 否则如果 | Set Craft Input | 设置飞行器输入 |
| Event | 事件 | Set Craft Property | 设置飞行器属性 |
| For | 计数循环 | Set List | 设置列表 |
| If | 如果 | Set Target | 设置目标 |
| Lock Nav Sphere | 锁定导航球 | Set Target Heading | 设置目标航向 |
| Set Time Mode | 设置时间模式 | Speak | 朗读 |
| Set Variable | 设置变量 | User Input | 用户输入 |
| Switch Craft | 切换飞行器 | Wait Seconds | 等待秒数 |
| Wait Until | 等待直到 | While | 当 |

### 4.2 积木块标签（`Vizzy.Toolbox.Format.*`，逐条锁定，**照抄本表**）

| id | zh |
|---|---|
| activate-stage | `执行分级` |
| activation-group | `激活组 (0:OneOrMore)` |
| break | `跳出` |
| broadcast-msg | `广播 (0)，附带数据 (1)` |
| broadcast-msg-all-crafts | `向附近飞行器广播 (0)，附带数据 (1)` |
| broadcast-msg-craft | `向飞行器广播 (0)，附带数据 (1)` |
| change-soi | `当进入 \|Vizzy.EventVariable.Planet\| SOI`（宽度受限，用 SOI 缩写；正文里仍写「引力影响范围」） |
| change-variable | `将变量 (0) 改变 (1)` |
| comment | `# (0)` |
| conditional | `如果 (0) 则 (1) 否则 (2)` |
| contains | `(0) 包含 (1)` |
| craft | `飞行器 (0:ZeroOrMore) [x]` |
| craft-docked | `当 \|Vizzy.EventVariable.CraftA\| 与 \|Vizzy.EventVariable.CraftB\| 对接` |
| craft-id | `(0) 的飞行器 ID` |
| create-mfd-widget | `创建名为 (0) 的 [x] 控件` |
| destroy-all-mfd-widgets | `销毁所有控件` |
| destroy-mfd-widget | `销毁名为 (0) 的控件` |
| display | `显示 (0)` |
| else | `否则` |
| else-if | `否则如果 {0} 则` |
| false | `假` |
| flight-start | `当启动` |
| flightlog | `飞行日志 (0) {1}` |
| for | `循环 \|i\| 从 (0) 到 (1) 步长 (2)` |
| format | `格式化 `（**尾部一个空格**） |
| friendly | `友好 [friendly] (0)` |
| if | `如果 {0} 则` |
| join | `连接 `（**尾部一个空格**） |
| length | `(0) 的长度` |
| letter | `(1) 的第 (0:OneOrMore) 个字母` |
| list-add | `将 (1) 添加到 (0)` |
| list-clear | `清空 (0)` |
| list-create | `用 (0) 创建列表` |
| list-get | `(0) 的第 (1:OneOrMore) 项` |
| list-index | `(1) 在列表 (0) 中的序号` |
| list-init | `将列表 (0) 设为 (1)` |
| list-insert | `在 (0) 的第 (2:OneOrMore) 位插入 (1)` |
| list-length | `(0) 的长度` |
| list-remove | `从 (0) 中移除第 (1:OneOrMore) 项` |
| list-reverse | `反转 (0)` |
| list-set | `将 (0) 的第 (2:OneOrMore) 项设为 (1)` |
| list-sort | `排序 (0)` |
| lock-nav-sphere | `锁定航向于 [x]` |
| lock-nav-sphere-vector | `锁定航向于向量 (0)` |
| log | `本地日志 (0)` |
| note-frequency | `(0) 八度 (1:ZeroOrMore) 的频率` |
| op-add / op-div / op-eq / op-exp / op-gt / op-gte / op-lt / op-lte / op-mod / op-mul / op-sub | 原文照抄 |
| op-and | `{0} 且 {1}` |
| op-atan-2 | `(0) 与 (1) 的 atan2` |
| op-math | `(0:Number) 的 [x]` |
| op-max | `(0:Number) 与 (1:Number) 的较大值` |
| op-min | `(0:Number) 与 (1:Number) 的较小值` |
| op-not | `非 {0}` |
| op-or | `{0} 或 {1}` |
| op-rand | `(0:Number) 到 (1:Number) 的随机数` |
| part | `零件 (0:ZeroOrMore) [x]` |
| part-collision | `当 \|Vizzy.EventVariable.Part\| 与 \|Vizzy.EventVariable.Other\| 碰撞，速度 \|Vizzy.EventVariable.Velocity\|，冲量 \|Vizzy.EventVariable.Impulse\|` |
| part-explode | `当 \|Vizzy.EventVariable.Part\| 爆炸` |
| part-id | `(0) 的零件 ID` |
| part-transform | `零件 (0) [x] (1)` |
| planet | `行星 (0) [x]` |
| planet-to-lat-long-agl | `将 (0) 转换为纬度/经度/AGL` |
| planet-to-lat-long-asl | `将 (0) 转换为纬度/经度/ASL` |
| planet-to-position | `将 (0) 转换为位置` |
| planet-to-position-asl | `将 (0) 转换为海平面位置` |
| play-beep | `蜂鸣 (0:ZeroOrMore) Hz，音量 (1:ZeroToOne)，持续 (2:ZeroOrMore) 秒` |
| play-beep-waveform | `[waveform] 蜂鸣 (0:ZeroOrMore) Hz，音量 (1:ZeroToOne)，持续 (2:ZeroOrMore) 秒` |
| prop-altitude | `高度 [x]` |
| prop-atmosphere | `大气 [x]` |
| prop-fuel | `燃料 [x]` |
| prop-input | `输入 [x]` |
| prop-mfd-event | `获取控件 (0) 的 [x] 消息` |
| prop-mfd-gauge | `获取仪表 (0) 的 [x]` |
| prop-mfd-label | `获取标签 (0) 的 [x]` |
| prop-mfd-pos | `为 (0) 转换 (1) 的 [x]` |
| prop-mfd-sprite | `获取图元 (0) 的 [x]` |
| prop-mfd-texture-getpixel | `获取纹理 (0) 在 x=(1), y=(2) 处的像素` |
| prop-mfd-texture-getpixelalpha | `获取纹理 (0) 在 x=(1), y=(2) 处的像素透明度` |
| prop-mfd-widget | `获取控件 (0) 的 [x]` |
| prop-misc | `杂项 [x]` |
| prop-name | `[x] 的名称` |
| prop-nav | `导航 [x]` |
| prop-orbit | `轨道 [x]` |
| prop-performance | `性能 [x]` |
| prop-time | `时间 [x]` |
| prop-velocity | `速度 [x]` |
| raycast-query | `从 (0) 向 (1) 发射射线` |
| receive-msg | `接收 (0)，附带 \|Vizzy.EventVariable.Data\|` |
| repeat | `重复 (0:ZeroOrMore)` |
| set-ag | `将激活组 (0:OneOrMore) 设为 (1)` |
| set-camera | `将相机 [x] 设为 (0)` |
| set-heading | `将飞行器 [x] 设为 (0)` |
| set-input | `将 [x] 设为 (0:NegOneToPosOne)` |
| set-mfd-alignment | `将标签 (0) 的对齐设为 [x]` |
| set-mfd-anchor | `将控件 (0) 的锚点设为 [x]` |
| set-mfd-event | `将控件 (0) 在 [x] 时广播 (1)，附带数据 (2)` |
| set-mfd-gauge | `将仪表 (0) 的 [x] 设为 (1)` |
| set-mfd-label | `将标签 (0) 的 [x] 设为 (1)` |
| set-mfd-line | `将线条 (0) 的 [x] 设为 (1)` |
| set-mfd-line-points | `将线条 (0) 从 (1) 连到 (2)` |
| set-mfd-map | `将地图 (0) 的 [x] 设为 (1)` |
| set-mfd-navball | `将导航球 (0) 的 [x] 设为 (1)` |
| set-mfd-order-back | `将控件 (0) 置于 (1) 之后` |
| set-mfd-order-front | `将控件 (0) 置于 (1) 之前` |
| set-mfd-sprite | `将图元 (0) 的 [x] 设为 (1)` |
| set-mfd-texture-drawbox | `在纹理 (0) 中于 x1=(1), y1=(2) 与 x2=(3), y2=(4) 之间绘制矩形，色 (5)，透明度 (6)` |
| set-mfd-texture-drawline | `在纹理 (0) 中于 x1=(1), y1=(2) 与 x2=(3), y2=(4) 之间绘制直线，色 (5)，透明度 (6)` |
| set-mfd-texture-drawtri | `在纹理 (0) 中于 X=(1) Y=(2) 之间绘制三角形，色 (3)，透明度 (4)` |
| set-mfd-texture-initialize | `初始化纹理 (0)，宽 (1)，高 (2)` |
| set-mfd-texture-setpixel | `设置纹理 (0) 中 x=(1), y=(2) 处的像素为 (3)，透明度 (4)` |
| set-mfd-widget | `将控件 (0) 的 [x] 设为 (1)` |
| set-part | `将零件 (0) 的 [x] 设为 (1)` |
| set-target | `目标节点 (0)` |
| set-time-mode | `将时间模式设为 [x]` |
| set-variable | `将变量 (0) 设为 (1)` |
| speak | `朗读 (0)，音调 (1:ZeroOrMore) Hz，持续 (2:ZeroOrMore) 秒` |
| substring | `(2) 的第 (0:ZeroOrMore) 到 (1:ZeroOrMore) 个字母` |
| switch-craft | `切换到飞行器 (0:ZeroOrMore)` |
| terrain-query | `获取纬度/经度 (0) 处的地形 [x]` |
| true | `真` |
| user-input | `将变量 (0) 设为用户输入 (1)` |
| vec | `向量 (0),(1),(2)` |
| vec-op-color | `十六进制颜色 (0)` |
| wait-seconds | `等待 (0:ZeroOrMore) 秒` |
| wait-until | `等待直到 {0}` |
| while | `当 {0} 时` |
| evaluate-expression | 原文照抄 |

### 4.3 属性 / 变量 / 界面词（全模块统一）

| en | zh | en | zh |
|---|---|---|---|
| Apoapsis | 远点 | Apoapsis Time | 远点时间 |
| Periapsis | 近点 | Periapsis Time | 近点时间 |
| Altitude | 高度 | Inclination | 轨道倾角 |
| Velocity | 速度 | Eccentricity | 偏心率 |
| Pitch | 俯仰 | Mean Anomaly | 平近点角 |
| Yaw | 偏航 | Mean Motion | 平均运动 |
| Roll | 滚转 | True Anomaly | 真近点角 |
| Heading | 航向 | Argument of Periapsis | 近点幅角 |
| Throttle | 节流阀 | Right Ascension | 赤经 |
| Brake | 刹车 | Semi Major Axis | 半长轴 |
| Stage | 分级 | Semi Minor Axis | 半短轴 |
| Activation Group | 激活组 | Angle of Attack | 迎角 |
| Nav Sphere | 导航球 | Bank Angle | 倾侧角 |
| Target | 目标 | Side Slip | 侧滑角 |
| Variable | 变量 | Velocity / Speed | 速度 |
| List | 列表 | Acceleration | 加速度 |
| Expression | 表达式 | Angular Velocity | 角速度 |
| Instruction | 指令 | Gravity | 重力 |
| Program | 程序 | Drag | 阻力 |
| Custom Expression | 自定义表达式 | Mass | 质量 |
| Custom Instruction | 自定义指令 | Dry Mass | 干质量 |
| MFD / Multi-function Display | MFD / 多功能显示器 | Wet Mass | 湿质量 |
| Widget | 控件 | Thrust | 推力 |
| Label | 标签 | Specific Impulse | 比冲 |
| Gauge | 仪表 | Sphere of Influence | 引力影响范围 |
| Sprite | 图元 | Solid Ground | 固态地面 |
| Texture | 纹理 | Atmosphere | 大气 |
| Line | 线条 | Air Density | 大气密度 |
| Map | 地图 | Air Pressure | 气压 |
| Navball | 导航球 | Speed of Sound | 音速 |
| Alignment | 对齐 | Temperature | 温度 |
| Anchor | 锚点 | Composition | 成分 |
| Opacity | 不透明度 | Elements | 元素 |
| Pivot | 轴心 | Density | 密度 |
| Scale | 缩放比例 | Force | 力 |
| Size | 尺寸 | Energy | 能量 |
| Rotation | 旋转 | Power | 功率 |
| Position | 位置 | Pressure | 压强 |
| Raycast | 射线检测 | Coordinate | 坐标 |
| Occlusion / Visible | 可见 | Specific Impulse | 比冲 |
| AGL | AGL（对地高度） | ASL | ASL（海平面高度） |
| ASF | ASF（海床高度） | Altitude AGL/ASL/ASF | 对地高度 / 海平面高度 / 海床高度 |
| Time Warp | 时间加速 | Fast Forward | 快进 |
| Slow Motion | 慢动作 | Paused | 暂停 |
| Normal | 正常 | Waveform | 波形 |
| Sine / Saw / Square / Triangle / Noise | 正弦 / 锯齿 / 方波 / 三角 / 噪声 | Octave | 八度 |
| Beep | 蜂鸣 | Frequency | 频率 |
| Prograde | 顺行 | Retrograde | 逆行 |
| Burn Node | 点火节点 | SOI | 引力影响范围 |
| Input | 输入 | Slider | 滑块 |
| Translation Mode | 平移模式 | Translate Forward/Right/Up | 前移 / 右移 / 上移 |
| Auto Size | 自动尺寸 | Fill Amount | 填充量 |
| Fill Method | 填充方式 | Thickness | 粗细 |
| Icon | 图标 | Font Size | 字号 |
| Zoom | 缩放 | Tilt | 倾斜 |
| Camera | 相机 | Spawn / Create | 创建 |
| Destroy | 销毁 | Bring to Front | 置于顶层 |
| Send Behind | 置于底层 | Undo | 撤销 |
| Redo | 重做 | Grid | 网格 |
| Read-only | 只读 | Upgrade | 升级 |

> `PCI` = 行星中心惯性坐标系，**保留英文 PCI**。`CoM` 质心。

## 5. 宽度预算怎么算

- `px` 非空时，`check-batch.ps1` 会在「中文整串宽 > px×1.02 **且** > 英文整串宽」时报 width hit。
- 经验值：**中文 1 个字 ≈ `size` 像素**。`px=470, size=16` → 最多约 29 个汉字。
- `px=120, size=16`（大按钮）→ 最多约 7 个汉字 → 例如 `Create Variable` 用 `新建变量`。
- `px=85`（撤销/重做）→ 最多约 5 字 → `撤销` / `重做`。
- `px=92`（Grid）→ `网格`。
- `px=183`（菜单弹出按钮，全大写）→ 最多约 11 字 → `加载程序`、`保存到飞行器`。
- 积木块 `ctx` 里带 "N of it locked token text" 的，预算要**减去**那段锁定 token 宽度再算
  （例：`px=803` 减 323 ≈ 480px → 约 30 个汉字）。

## 6. 自检（必做）

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  src\check-batch.ps1 `
  -Todo batches\Vizzy.pN.todo.json `
  -Zh   batches\Vizzy.pN.zh.json
```

退出码 0 = 通过。此外还要额外核对 `(n:Type)`、`[x]`、`|Key|` 三类 token（闸门不查）：
见 `src\check-vizzy-tokens.ps1`。

## 7. 与全包其他模块的用词对齐（已逐条比对 `pack\strings.zh.json`）

### 已按"同英文同译法"对齐到既有译文

| en | 本模块采用 | 依据（既有译文） |
|---|---|---|
| Eccentricity | 偏心率 | Career / Flight.MapView / Menu 三处均为「偏心率」 |
| Air Density | 大气密度 | `Flight.Inspector.AirDensity` |
| Air Pressure | 气压 | `Parts.InspectorModel.AirPressure` |
| Activate Stage | 激活分级 | `Parts.InputBasedActivator` / `Settings.Controls.Action` |
| All Stages | 所有分级 | `Flight.Inspector.AllStages`（同语境：燃料范围） |
| Parent（天体语境） | 父天体 | `Flight.MapView.Orbit.Parent` |
| Value（仪表值） | 值 | `PlanetBrush.ValueLabel` / `Modifier.*.Value` |
| Battery（燃料组标签） | 电池 | `Flight.Inspector` / `Fuel` / `Parts` 四处均用「电池」 |
| Mono | 单组元 | `Flight.Inspector.Mono` |
| Throttle | 节流阀 | `Settings.Controls.Action.Throttle`；且 `GLOSSARY.md` 明文规定 |

### 刻意不跟（语境不同或规范明确）

| en | 本模块 | 全包另见 | 不跟的理由 |
|---|---|---|---|
| AGL / ASL / ASF | 原文保留 | Flight.AltitudeMode = 离地/海拔 | 缩写不译；且本模块另有 `纬度/经度/AGL` 等格式串要用同一缩写 |
| TWR | 原文保留 | Flight/Parts = 推重比 | `GLOSSARY.md`「保留原文」清单里有 TWR |
| Roll | 滚转 | Settings.Controls.Action.Roll = 翻滚 | 俯仰/偏航/滚转是成套三轴术语，用「翻滚」会破套 |
| Thickness（线条） | 粗细 | Parts.Wing/Suspension = 厚度 | 语境不同：UI 线条描边 vs 物理厚度 |
| Scale（MFD 控件） | 缩放比例 | Parts.KomodoNoseCone = 缩放 | 需与同组的「尺寸」对举，见 §4.3 |
| Multi-function Display | 多功能显示器 | Parts.MfdData = 多功能显示屏 | 2:1，`DesignerParts.Mfd1` 也用「多功能显示器」 |
| Drag | 阻力（物理）/ 拖拽（UI 事件） | — | 同一英文两种义项，必须分译 |
| Square / log / Normal / Paused | 方波 / log / 正常 / 暂停 | 方形 / 日志 / 法向 / 已暂停 | 语境不同；`log` 是数学函数名，按铁律保留原文 |
| Size（MFD 控件） | 尺寸 | Modifier/PhotoLibrary = 大小 | `parts.*.Size/Scale.Label` 绝大多数用「尺寸」（27:3） |

同英文不同译的**义项分用**是本文件承认的正常现象；发现新的冲突时，
**先查 `pack\strings.zh.json` 里同 `en` 的多数译法，再决定跟还是不跟，并把决定写进本表。**

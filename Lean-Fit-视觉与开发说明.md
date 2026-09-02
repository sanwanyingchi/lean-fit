# Lean Fit 视觉与交互开发说明

配套文件：`lean-fit-prototype.html`（可直接在浏览器打开的高保真交互原型）、`Lean-Fit-PRD.md`（产品需求）。

本文件说明视觉稿如何映射到 iOS 原生实现。原型是单文件 HTML/CSS/JavaScript，用于交互和视觉验收；生产端按 PRD 使用 SwiftUI、SwiftData 和 Swift Charts 实现，本文提供设计 token、组件规格、状态和动线的对照，便于开发直接落地。

## 1. 如何使用原型

直接双击 `lean-fit-prototype.html` 用现代浏览器打开即可。原型把多个页面和状态整合进一台 iPhone 15 Pro 画框，通过底部导航、中心加号和页面内入口切换，逻辑屏幕为 393×852pt。所有交互数据仅存在于内存，不写入本地存储，刷新页面即重置。

原型可体验的主要动线包括：进展首页、动作选择与自定义动作创建、训练进行与按组记录、重量/次数编辑、完成庆祝、训练记录时间轴与详情、趋势详情、身体数据更新、个人档案，以及首次空状态和训练草稿恢复弹窗。

## 2. 设计 Token

原型使用一层“种子 token”作为设计源，其余颜色由种子派生。生产端建议在 Asset Catalog 或 SwiftUI 中建立对应的语义颜色，浅色与深色各配一套，避免硬编码。

| Token | 原型值 | 语义 | iOS 对照 |
|---|---|---|---|
| `--seed-bg` | `#f2f2f7` | 页面背景 | systemGroupedBackground |
| `--seed-surface` | `#ffffff` | 卡片/列表面 | secondarySystemGroupedBackground |
| `--seed-fg` | `#1c1c1e` | 主文字 | label |
| `--seed-primary` | `#248a3d` | 训练绿，进步与完成 | 自定义 systemGreen 近似 |
| `--seed-accent` | `#007aff` | 系统蓝，可点操作 | systemBlue |
| `--danger` | `#ff3b30` | 破坏性、错误 | systemRed |
| `--warning` | `#ff9f0a` | 警示 | systemOrange |
| `--seed-radius` | `16px` | 卡片圆角基准 | 卡片 16，Sheet 28 |

派生规则：次级表面 `surface-2` 由 surface 与 bg 混合；`muted` 约为主文字 58% 透明度，`tertiary` 约 34%，`separator` 约 12%；`primary-soft` / `accent-soft` 为对应色约 11–13% 与表面混合，用于徽标和柔和高亮。卡片圆角 16，Sheet 圆角 28（`radius + 12`）。

外观通过替换种子 token 即可整体切换，原型已内置浅色、深色和高对比训练三套外观预设。生产端对应浅色/深色模式，以及可选的高对比场景。

## 3. 排版

单一系统字体族，对应 SF Pro（正文 SF Pro Text、标题 SF Pro Display），大数字使用等宽变体（`font-variant-numeric: tabular-nums`）表现重量、次数和统计值。字号建立层级而非全部加粗，字重集中在常规与半粗两档。

| 角色 | 原型字号 | 用途 | iOS 文本样式对照 |
|---|---|---|---|
| Large Title | 34 | 页面主标题 | largeTitle |
| Title | 30 | 训练动作名、关键数值 | title / title2 |
| Section | 21 | 卡片区块标题 | title3 |
| Body | 15–17 | 正文、列表主文本、按钮 | body / headline |
| Caption | 11–13 | 次级说明、单位、标签 | footnote / caption |
| Metric | 28–38 | 体重、体脂、编辑器数值 | 等宽大号数字 |

所有字号在原型中乘以 `--type-scale`，对应 iOS 的动态字体。生产端使用系统文本样式并允许 Dynamic Type 缩放。

## 4. 间距、圆角与阴影

采用 4/8 网格：常用间距为 8、12、16、24、32。卡片内边距约 16–20，页面横向边距 16。列表行和主要按钮最小高度 44pt，符合点击区域要求；组完成按钮和编辑器加减按钮为独立圆形触控区。

卡片和 Sheet 使用柔和阴影，避免生硬黑色投影。Sheet、Tab Bar 和 Alert 使用 `backdrop-filter` 材质模糊，对应 iOS 的原生材质层级（`.regularMaterial` / `.thinMaterial`），这是功能性玻璃层而非装饰背景。

## 5. 组件规格

页面框架由状态栏、Dynamic Island、内容滚动区、底部 Tab Bar 和 Home Indicator 组成。底部 Tab 为“进展 / ＋ / 记录”，中心加号是凸出的圆形主操作，不产生 Tab 选中态。

进展首页的趋势卡使用分段控件切换体重、体脂、力量，下方是可点击的迷你趋势图和“更新体重与体脂”入口；本周训练是七日圆点日历加目标进度；近期训练是两张训练卡。生产端趋势图用 Swift Charts，分段控件用原生 `Picker(.segmented)`，列表用 `List` 分组样式。

动作选择为原生 Sheet，包含搜索框、分类 chips、动作列表、常驻底部“已选 N/4 + 开始训练”操作坞。列表每行展示动作名、部位和上次表现，右侧圆形勾选。列表末尾常驻“创建自定义动作”入口；搜索无结果时展示专用空状态加创建入口。生产端用 `.sheet` + `.presentationDetents([.medium, .large])`。

训练页由进度条、动作标题与序号、上次表现与本次目标两栏、按组记录表和底部操作组成。每组是“序号 + 重量按钮 + 次数按钮 + 完成圆钮”。点按重量或次数弹出底部编辑 Sheet，支持直接输入、加减按钮、重量档位选择和“同步后续未完成组”。

完成庆祝页用训练绿背景、SF Symbol、大号结果数字和本周进度，提供“完成”返回进展。记录页是粘性月份分组的垂直时间轴，右上角使用轻量 `calendar.badge.plus` 进入手动打卡；打卡 Sheet 用单张表单卡组合日期、训练部位与备注，底部主按钮固定在安全区内，小屏时内容可滚动。详情页展示每组数据、与上次对比和突破徽标。个人档案使用分组表单和能量估算说明，不展示头像。

关键组件均带 `data-component` 标注（如 `Custom Exercise Form`、`Set Value Editor`），便于设计与开发对齐命名。

## 6. 自定义动作动线

动线为：动作选择 Sheet → 搜索动作 → 无结果或点击“创建自定义动作” → 填写动作信息 → 校验 → 创建并自动选中 → 返回动作选择 Sheet → 继续选满四个动作并开始训练。

表单字段为名称（必填）、别名、主要部位、器械、负重类型、默认次数范围和默认加重档位。交互规则包括：搜索词预填名称；名称去除多余空格；名称必填且不得与现有动作重复；次数为 1–100 正整数且最低不高于最高；负重类型切换时更新档位标签和说明文案；保存后加入动作库、自动选中并返回仍打开的选择 Sheet，Toast 提示“已创建并选中”；已选满四个动作时提示先取消一个。

自定义动作在列表中带“自定义”标签。按 PRD，历史记录需保存动作名称快照，即使动作后续被删除，历史仍可读。

## 7. 数值编辑与校验

重量与次数不在密集表格里直接长期显示键盘，而是点按后弹出底部编辑 Sheet。重量范围 0–500、最多一位小数；次数范围 1–100 的正整数。加减步进对重量可选 0.5 / 1 / 2.5kg（哑铃类默认 1，其余默认 2.5，自定义动作沿用其设置的档位），次数步进为 1。“同步后续未完成组”只影响尚未完成的组，已完成组保持不变但可再次编辑。校验不通过时在 Sheet 内就地提示，不关闭。

自重动作初始重量按 0 起，辅助动作按辅助重量语义起算，普通负重按合理基准起算，并使用各动作的默认次数下限生成初始组。

## 8. 动效与可访问性

组完成使用不超过约 400ms 的弹性点亮和数字过渡；训练完成使用约 1–2 秒的颜色扩散和轻量粒子，可立即跳过，且不阻塞数据保存。所有动效时长在原型中乘以 `--motion-scale`。

原型已实现 `prefers-reduced-motion` 降级：开启“减弱动态效果”时以淡入和颜色变化替代弹性与粒子。生产端需支持浅色/深色、动态字体、VoiceOver 和至少 44pt 点击区域，交互元素配可读的 `aria-label`（对应 iOS 的 accessibilityLabel）。

## 9. Logo 与开屏动画

Lean Fit Logo 不使用常见哑铃、闪电或健美剪影，而是将字母 L 与 F 抽象为连续的稳定支撑结构：左侧竖线与底部平台代表训练基准和稳定记录，中间向上折线代表逐组累积与渐进提升，右上节点代表新的个人基准。品牌珊瑚红 `#FF4B2B` 作为 App Icon 背景，与界面主操作保持一致；白色主路径保证小尺寸辨识，深梅色 `#6E405B` 只用于进步节点，在统一色调中保留 Logo 的记忆点。

矢量源文件为 `LeanFit/Resources/Assets.xcassets/LaunchLogo.imageset/LaunchLogo.svg`，采用 1024×1024 viewBox；`Tools/GenerateAppIcon.swift` 用同一组颜色与路径生成 App Icon。提交 App Store 的 1024×1024 PNG 不预裁系统圆角，由系统自动施加图标蒙版。64pt 以下只保留珊瑚红底、白色路径和深梅色节点，不加入字标或阴影。

启动体验分为系统 Launch Screen 与应用内品牌动画两层。iOS 系统 Launch Screen 必须保持静态，只显示与应用内首帧一致的背景色和静态 Logo，不能承担自定义动画；SwiftUI 根视图加载后，再覆盖应用内品牌动画，避免启动瞬间出现视觉跳变。

普通动画时间线约 1.6 秒：0–60ms 显示背景；60–580ms 图标轻微缩放并淡入；180–900ms 主路径从左下支撑结构向右上进阶节点描边；760–1120ms 深梅色节点点亮，同时 Lean Fit 字标和“记录每一次，稳步变强”依次淡入；约 1580ms 开始整体淡出，约 280ms 后移除覆盖层并进入进展首页。用户点按开屏任意位置可立即跳过。

原型通过 `playing`、`leaving`、`hidden` 三个类管理播放状态，并在重播前清除旧定时器，避免快速点按产生竞态。开启 `prefers-reduced-motion` 时，Logo、字标和短句直接静态显示，取消路径绘制、弹性缩放和位移，停留约 620ms 后短淡出。SwiftUI 使用 `@Environment(\.accessibilityReduceMotion)` 对应降级：普通模式以 `trim(from:to:)` 绘制 Shape，减弱动态效果模式直接显示最终状态，并取消退出转场。

原生工程已落地对应实现：`AppContainerView` 负责根页面与开屏覆盖层切换，`LaunchExperienceView` 管理单一可取消动画任务和点按跳过，`LeanFitLogoShape` 复用同一组 1024 坐标绘制路径。Asset Catalog 中的 `LaunchLogo` 与 `LaunchBackground` 用于系统静态 Launch Screen，App Icon 由 `Tools/GenerateAppIcon.swift` 生成无透明通道的 1024×1024 PNG。常规 UI 测试通过 `-uiTesting` 跳过动画；开屏专项测试使用 `-launchUITesting` 保留动画且改用内存数据库；开发调试可通过 `-skipLaunchAnimation` 单独跳过。

## 10. 与生产实现的差异

原型为单文件 Web，用于视觉和交互验收，与最终原生实现存在预期差异：数据仅在内存中、无 SwiftData 持久化、无 HealthKit、趋势图为静态示意而非 Swift Charts、材质模糊为 CSS 近似。开发时以本说明的 token、组件规格、动线和 PRD 的业务规则为准，视觉稿用于对齐布局层级、间距节奏和交互反馈，而非逐像素复刻 Web 渲染。

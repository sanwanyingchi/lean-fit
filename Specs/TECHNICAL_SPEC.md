# Lean Fit 技术方案

版本：1.0  
目标平台：iOS 17.0+  
工具链：Xcode 15.4、Swift 5.10  
产品依据：`Lean-Fit-PRD.md`、`Lean-Fit-视觉与开发说明.md`、`lean-fit-prototype.html`，以及后续确认的珊瑚色视觉稿

## 1. 技术目标

Lean Fit 是本地优先的个人力量训练记录 App。MVP 的第一质量目标不是联网能力，而是训练中任何一次输入都不会静默丢失；第二目标是所有趋势和“进步”提示都能从原始记录稳定重算；第三目标是在 iPhone 上以原生 SwiftUI 交互完成视觉和可访问性要求。

成功条件：

- 无网络时所有核心流程完整可用。
- 每次组记录编辑后显式保存，App 进后台时再次保存。
- 同一动作仅通过稳定 ID 关联历史，不通过名称模糊匹配。
- 编辑、删除训练后，趋势、突破和周打卡都从事实数据重算。
- 所有庆祝动效发生在保存成功之后，且不阻塞导航。

## 2. 范围挑战

### MVP 必须实现

- 进展、中心加号、记录三个底部入口。
- 内置动作库、自定义动作、四动作选择。
- 训练草稿、逐组重量/次数、动作完成、训练完成。
- 上次表现、双进步目标、真实突破判定。
- 周训练日、手动打卡、记录时间轴和详情。
- 个人档案、身体数据、REE/TDEE 估算。
- 体重、体脂、单动作力量趋势。
- 深色模式、动态字体、VoiceOver、减弱动态效果。

### NOT in scope

- 账号、后端和云同步：本地优先 MVP 不需要网络失败面。
- HealthKit：PRD 明确为后续能力，首版只保留数据来源字段。
- Apple Watch：不阻塞手机端闭环。
- 通知、社交、排行榜、金币和连续签到惩罚：与当前克制激励原则冲突。
- 自动生成完整训练计划：产品只给“本次目标/下次可尝试”。
- 常用四动作模板：数据结构可预留，但 UI 延后。
- 自定义图标库、第三方图表或动画框架：SF Symbols、Swift Charts 和 SwiftUI 动画足够。

## 3. 架构

采用单 App Target、单本地数据库、按 Feature 分目录的轻量架构。简单页面直接使用 `@Query`；规则复杂的部分放进无副作用的 Engine，避免为每个 View 创建空壳 ViewModel。

```text
SwiftUI Views
  │  用户输入 / 导航 / 可访问性
  ▼
Feature State (@State, @Observable)
  │  只管理当前交互状态
  ├──────────────► Pure Engines
  │                ProgressEngine
  │                TargetEngine
  │                EnergyEngine
  │                CalendarEngine
  │
  ▼
SwiftData ModelContext
  │  唯一事实来源，显式 save
  ▼
Local Store

Swift Charts ◄──── Pure Engines 的派生序列
```

### 当前源码边界

```text
LeanFit/
  LeanFitApp.swift      App 入口、启动体验、Root 与导航
  Models.swift          SwiftData 实体、枚举和值对象
  SeedData.swift        32 个内置动作及演示数据
  Engines.swift         进步、目标、能量和日历纯计算规则
  Theme.swift           语义颜色和共享原生组件
  WorkoutFeature.swift  动作选择、自定义动作、训练与庆祝
  ProgressFeature.swift 首页、打卡和趋势
  ProfileFeature.swift  个人档案与身体数据
  RecordsFeature.swift  记录时间轴、详情、编辑和删除
  Resources/            Asset Catalog、启动与 App 图标资源
LeanFitTests/       规则和持久化测试
LeanFitUITests/     核心用户旅程
```

## 4. 训练状态机

```text
         选择第一个动作
empty ───────────────────► draft
                              │ 开始训练
                              ▼
                         inProgress
                         │    │    │
                编辑组 ──┘    │    └── 放弃确认 ──► abandoned
                              │
                  完成/跳过动作
                              │
                              ▼
                          completed
                              │
                              ▼
                    保存完成 → 计算反馈 → 动效
```

规则：

- 同一时刻最多存在一个 `draft` 或 `inProgress` Session。
- `draft`、`inProgress`、`abandoned`、已软删除记录不参与历史和趋势。
- 所有四个动作完成时可直接结束；存在未完成动作时二次确认并标记为 skipped。
- 训练完成事务顺序：更新状态与结束时间 → 保存 → 创建/更新 CheckIn → 保存 → 计算反馈 → 展示动效。

## 5. 关键数据流

### 开始与恢复训练

```text
点中心 +
  ├─ 存在 active session ─► 恢复对话框 ─► 继续 / 放弃
  └─ 不存在 ─► 动作 Sheet ─► 选满 4 个 ─► 建立 draft
                                      └─ 开始 ─► inProgress
```

### 完成一组

```text
编辑 Sheet 校验
  ├─ 非法：原位错误，不关闭
  └─ 合法：更新 SetEntry
             ├─ 可选同步后续未完成组
             ├─ modelContext.save()
             └─ 触感 + <=400ms 状态动效
```

### 趋势重算

```text
BodyMeasurement / completed WorkoutSession / CheckIn
                 │
                 ▼
        查询 + 过滤有效记录
                 │
      ┌──────────┼──────────┐
      ▼          ▼          ▼
  身体趋势    动作趋势    周训练日集合
      │          │          │
      └──────────┴──────────┘
                 ▼
             SwiftUI/Charts
```

## 6. 规则 Engine

### ProgressEngine

- `estimatedOneRepMax(weight:reps:)`：仅 1...10 次组，使用 Epley `weight × (1 + reps / 30)`，结果只用于同动作纵向比较。
- `trainingVolume`：普通负重和可量化附加负重按 `Σ weight × reps`；纯自重不伪造体重训练量。
- `compare(current:previous:loadType:)`：按估算力量、重量、次数、训练量优先级返回一个主反馈和可选次反馈。
- 辅助动作的“重量突破”方向相反：辅助重量更低更好；同辅助重量比较次数。

### TargetEngine

- 无历史：按动作默认次数下限生成 4 组，普通负重从 0 或用户输入开始，自重为 0，辅助动作需要用户确认辅助重量。
- 有历史：复制最近一次有效工作组作为输入基线。
- 所有有效主工作组达到次数上限：重量增加一个默认档位，次数回到下限。
- 未全部达到上限：保持重量，将目标总次数增加 1，并从较低次数组开始分配。
- 当前训练明显低于历史时不惩罚或降低目标，只给“下次保持目标”。

### EnergyEngine

- 年龄按出生日期和记录当天计算。
- 采用 Mifflin–St Jeor；缺少出生日期、生理性别、身高或当前体重时返回 nil。
- TDEE = REE × 活动系数；展示时四舍五入到 10 kcal，并始终标注估算。

## 7. 保存与一致性

- App 启动使用一个 `ModelContainer`，Preview/Test 使用内存容器。
- 对训练输入、身体数据、档案、自定义动作、手动打卡执行显式 `save()`。
- 监听 `scenePhase == .background`，对未完成训练再次保存。
- 保存失败时保留当前编辑值并显示可恢复错误，不播放成功动效。
- 身体数据按 `localDayKey` upsert；同一天更新已有记录。
- CheckIn 按 `localDayKey + source + workoutID` 去重；周训练天数使用唯一 dayKey 集合。
- 历史条目保存动作名称、部位和负重类型快照；删除 Exercise 不影响历史。

## 8. 导航与呈现

- 系统 Launch Screen 使用静态品牌首帧；SwiftUI 加载后由 `AppContainerView` 覆盖可跳过的品牌动效，并为 Reduce Motion 提供简化路径。
- Root 使用自定义 `safeAreaInset` Tab Bar，只有“进展”和“记录”具有选中态，中间 `+` 只触发 Sheet。
- Feature 内使用 `NavigationStack`。
- 动作选择使用 `.sheet` 和 `.presentationDetents([.medium, .large])`。
- 自定义动作、组数值编辑、身体数据更新均使用原生 Sheet。
- 破坏性操作使用 `confirmationDialog` 或 Alert。
- 完成页是覆盖层或独立 Navigation Destination，但不能控制保存流程。

## 9. 生产失败模式

| 路径 | 真实失败 | 防护 | 用户可见反馈 |
|---|---|---|---|
| 组记录保存 | 本地存储空间不足 | 捕获 save 错误，保留编辑状态 | “未能保存，请释放空间后重试” |
| 草稿恢复 | 多个异常 active session | 选择最近一个，其他标记 abandoned | 提示恢复最近训练 |
| 自定义动作 | 名称重复或并发创建 | 规范化名称后查询并唯一约束 | 就地错误，不关闭 Sheet |
| 完成训练 | CheckIn 保存失败 | Session 已保存后重试 CheckIn，首页按 Session 兜底计日 | 非阻塞警告 |
| 趋势 | 历史记录被编辑/删除 | 每次查询后纯函数重算 | 不展示陈旧缓存 |
| 跨午夜/时区 | Date 被重新解释 | 完成时保存 localDayKey | 打卡保持完成地当天 |
| 动效 | 开启减弱动态效果 | 环境值切换为淡入/颜色 | 功能不受影响 |

## 10. 性能

- MVP 数据规模按 10 年、每周 5 次、每次 20 组估算，约 52,000 个 SetEntry，本地 SwiftData 足够。
- 首页只查询当前时间范围和最近两次训练；记录页按月/批次加载。
- 图表使用下采样后的派生点，1 年身体趋势最多约 366 点。
- 不缓存可快速重算的进步结果，避免编辑历史后缓存失效。
- 动作搜索对名称和别名规范化后在内存过滤，动作库规模远低于需要全文索引的阈值。

## 11. 构建与分发

- App Target：`LeanFit`，Bundle ID 默认 `com.leanfit.app`。
- Unit Test Target：`LeanFitTests`；UI Test Target：`LeanFitUITests`。
- `-demoData` 仅用于 UI 测试与视觉验收；正常 Debug/Release 均从空用户数据开始，只播种动作库。
- CI 建议运行：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project LeanFit.xcodeproj \
  -scheme LeanFit -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' build
```

- 工程已包含正式 1024×1024 App Icon、静态 Launch 资源和无网络本地数据声明；提交 App Store 前仍需在开发者账号中配置签名、版本元数据并按届时平台要求复核隐私清单。

## 12. 并行与实施顺序

| Lane | 内容 | 依赖 |
|---|---|---|
| A | Models → SeedData → Engines → Unit Tests | 无 |
| B | Theme → Shared Components → Root Navigation | 无 |
| C | Workout Flow → Draft Recovery → Celebration | A、B |
| D | Progress/Profile/Charts | A、B |
| E | Records/CheckIn/Edit/Delete | A、B |
| F | Accessibility → UI Tests → Visual QA | C、D、E |

先并行完成 A+B，再推进 C/D/E，最后统一做 F。所有 Feature 会共享 Models，因此在模型稳定前不并行修改实体定义。

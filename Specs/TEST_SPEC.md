# Lean Fit 测试与验收 Spec

版本：1.0

## 1. 测试分层

- `LeanFitTests`：纯规则、数据校验、SwiftData 内存容器、删除/重算。
- `LeanFitUITests`：完整用户路径、Sheet、导航、恢复、错误反馈。
- Preview/截图检查：iPhone 15 Pro、小屏、深色、Dynamic Type、Reduce Motion。
- 每个 bug 修复必须先补回归测试。

## 2. 代码路径覆盖

```text
动作选择
  ├─ 0...3 个动作 → 开始按钮禁用
  ├─ 4 个不同动作 → 可开始 [UI]
  ├─ 第 5 个动作 → 提示先取消 [UI]
  ├─ 重复动作 → 不重复加入 [UNIT]
  └─ 搜索无结果 → 可新建并自动选中 [UI]

自定义动作
  ├─ 空名称 / 重名 → 就地错误 [UNIT+UI]
  ├─ 次数边界 / min > max → 错误 [UNIT]
  ├─ 普通 / 自重 / 辅助 → 正确默认语义 [UNIT]
  └─ 删除动作后历史快照仍可读 [PERSISTENCE]

训练状态
  ├─ draft → inProgress → completed [PERSISTENCE+UI]
  ├─ inProgress → abandoned [PERSISTENCE+UI]
  ├─ 未完成一组 → 动作不可完成 [UI]
  ├─ 未完成动作结束 → skipped + 二次确认 [UI]
  └─ App 重启 → 恢复最近 active session [PERSISTENCE+UI]

数值编辑
  ├─ 重量 0 / 500 / 一位小数 [UNIT]
  ├─ 非法小数 / >500 / reps 0 / 101 [UNIT+UI]
  ├─ 同步后续未完成组 [UNIT]
  └─ 已完成组保持不变 [UNIT]

进步判定
  ├─ 估算力量突破 [UNIT]
  ├─ 重量 / 次数 / 训练量突破 [UNIT]
  ├─ 辅助动作重量方向相反 [UNIT]
  ├─ 自重动作次数与附加重量 [UNIT]
  └─ 无真实突破 → 完成/周目标文案 [UNIT]

身体与能量
  ├─ 同日 upsert / 单项更新 [PERSISTENCE]
  ├─ 0/1/2+ 趋势点 [UNIT+UI]
  ├─ 男/女 Mifflin 公式 [UNIT]
  └─ 档案缺项 → 不显示估算 [UNIT+UI]

记录与打卡
  ├─ 同日多练只计 1 天 [UNIT]
  ├─ 手动+自动同日只计 1 天 [UNIT]
  ├─ 编辑训练 → 趋势重算 [PERSISTENCE]
  ├─ 删除 → 周统计重算 [PERSISTENCE]
  └─ 撤销 → 恢复完整对象图 [PERSISTENCE+UI]
```

## 3. 单元测试清单

### ProgressEngineTests

- 1RM 只接受 1...10 次；0kg 返回 nil。
- 同重量更多次数、相同次数更高重量分别判定。
- 优先级：估算力量 > 重量 > 次数 > 训练量。
- 辅助动作 40kg → 35kg 判定改善，35kg → 40kg 不判定。
- draft、abandoned、skipped 和未完成组不进入输入集合。

### TargetEngineTests

- 无历史生成 4 组和默认次数。
- 未到上限时只增加总次数 1。
- 全部达到上限时只增加一个档位并回到次数下限。
- 同步后续组不修改已完成组。

### EnergyEngineTests

- 男性和女性公式使用 PRD 示例固定输入断言。
- 闰年生日、生日当天、缺字段、非法字段。
- 五个活动系数和 10kcal 展示舍入。

### CalendarEngineTests

- 周一为一周起点。
- 同日多个 Session/CheckIn 去重。
- 跨午夜完成使用保存的 localDayKey。
- 时区变化不改写历史 dayKey。

### ValidationTests

- 动作名 trim、连续空格、大小写/全半角重复。
- 重量、次数、体脂、身高和周目标边界。

## 4. SwiftData 集成测试

使用 `ModelConfiguration(isStoredInMemoryOnly: true)`：

- 播种动作重复执行幂等，内置 stableID 唯一，数量 ≥32，每个胸/背/腿/肩 ≥8。
- 建立 Session → Entry → Set 后重建查询，数据完整。
- 每次 set 编辑显式保存后重新获取值一致。
- 删除 Exercise 不影响 ExerciseEntry 快照。
- 删除 Session 级联删除 Entry/Set，并移除自动 CheckIn。
- BodyMeasurement 同日保存更新原记录而非新增。
- 只存在一个 active session；异常多个时选择最近一个。

## 5. UI 测试关键路径

1. 首次启动 → 跳过目标 → 点击 + → 选 4 动作 → 开始训练。
2. 搜索不存在动作 → 新建 → 自动选中 → 继续选满 4 个。
3. 修改重量 → 同步后续组 → 完成一组 → 结束并确认跳过。
4. 完成四动作 → 看到真实反馈 → 返回进展 → 当天点亮。
5. 训练中终止并重启 → 继续草稿 → 数据仍在。
6. 更新体重/体脂 → 首页和趋势立即刷新。
7. 手动打卡 → 记录出现 → 周训练日增加。
8. 删除训练 → 撤销 → 记录和统计恢复。
9. 档案补齐 → 显示预计每日消耗；清空必要字段后隐藏。
10. 启动品牌动效出现 → 点按跳过 → 进入进展首页；常规 UI 测试参数可跳过动画。
11. 记录页右上角手动打卡 → Sheet 标题、取消、单张表单卡和底部 CTA 无重叠；iPhone 15 Pro 与 iPhone SE 均可点击“完成打卡”。

## 6. 错误与恢复

| 故障 | 测试方法 | 预期 |
|---|---|---|
| SwiftData save 抛错 | 注入失败 Saver | 不关闭编辑器，不播放成功，显示可恢复错误 |
| 重复点击保存 | UI 连点 | 只创建一条记录 |
| 结束训练连点 | UI 连点 | 只生成一个 CheckIn |
| 历史为空 | 空内存库 | 显示“首次训练，建立你的基准” |
| 图表只有一个点 | 单记录 | 显示点，不绘制误导趋势线 |
| Reduce Motion | 启动参数 | 无弹性和粒子，保存/导航不变 |

任何失败若“无测试 + 无错误处理 + 用户无反馈”，按阻断发布处理。

## 7. 构建门禁

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project LeanFit.xcodeproj -scheme LeanFit \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -project LeanFit.xcodeproj -scheme LeanFit \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -parallel-testing-enabled NO
```

发布前必须满足：编译 0 error、测试 0 failure、无新增 warning、核心 UI 路径可完成、浅色/深色/大字体/Reduce Motion 截图验收完成。

## 8. 当前自动化验收记录

- Xcode Scheme：串行 19/19 通过，其中规则/持久化 13 项、UI 6 项；新增记录页手动打卡 Sheet 的标题、取消按钮和底部 CTA 可达性回归。
- Swift Package 核心测试：13/13 通过。
- Release generic iOS 无签名构建：通过，0 error。
- 视觉路径：iPhone 15 Pro 浅色、iPhone 15 Pro 深色、iPhone SE 小屏均已完成截图核对；产物保存在 `Artifacts/VisualQA/`。
- 辅助功能大字号通过页面渲染与滚动截图核对；四动作连续点击不纳入自动化门禁，因为 XCUITest 会把被 SwiftUI `safeAreaInset` 底栏覆盖的行误报为可点击。该限制不影响 VoiceOver 标签或用户滚动操作。

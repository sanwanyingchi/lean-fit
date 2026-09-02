# Lean Fit 数据模型与业务不变量

版本：1.0  
持久化：SwiftData，iOS 17+

## 1. 枚举

```text
BiologicalSex       male | female | unspecified
ActivityLevel       sedentary | light | moderate | veryActive | extraActive
BodyPart            chest | back | legs | shoulders | arms | core | other
LoadType            weighted | bodyweight | assisted
WorkoutStatus       draft | inProgress | completed | abandoned
EntryStatus         pending | completed | skipped
CheckInSource       workout | manual
MeasurementSource   manual
ProgressKind        estimatedStrength | weight | reps | volume | weeklyGoal | completion
TrendMetric         weight | bodyFat | strength
```

枚举以字符串 raw value 存储，UI 文案通过本地计算属性提供，避免把中文展示文案写进业务判断。

## 2. 实体

### UserProfile

| 字段 | 类型 | 约束 |
|---|---|---|
| id | UUID | 单例记录 |
| birthDate | Date? | 只保存日期语义 |
| biologicalSexRaw | String | 默认 unspecified |
| heightCm | Double? | 80...250 |
| activityLevelRaw | String | 默认 moderate |
| weeklyGoal | Int | 1...7，默认 3 |
| lastTrendMetricRaw | String | 默认 weight |
| hasSeenOnboarding | Bool | 默认 false |
| createdAt/updatedAt | Date | 自动维护 |

当前体重和体脂不冗余保存在 Profile，从最新 BodyMeasurement 读取。

### BodyMeasurement

| 字段 | 类型 | 约束 |
|---|---|---|
| id | UUID | 主键 |
| recordedAt | Date | 用户选择日期 |
| localDayKey | String | `yyyy-MM-dd`，应用时区生成，逻辑唯一 |
| weightKg | Double? | 20...400；体重/体脂至少一项存在 |
| bodyFatPercent | Double? | 1...75 |
| sourceRaw | String | MVP 为 manual |
| createdAt/updatedAt | Date | 自动维护 |

同一 localDayKey 保存时执行 upsert，不创建重复日期点。

### Exercise

| 字段 | 类型 | 约束 |
|---|---|---|
| id | UUID | SwiftData 主键 |
| stableID | String | 唯一；内置使用固定 slug，自定义使用 UUID 字符串 |
| name | String | 规范化后不重复，1...24 字符 |
| aliasesCSV | String | 逗号分隔，搜索时拆分 |
| primaryBodyPartRaw | String | 必填 |
| secondaryBodyPartsCSV | String | 可空 |
| equipment | String | 可空 |
| loadTypeRaw | String | weighted/bodyweight/assisted |
| defaultRepMin | Int | 1...100 |
| defaultRepMax | Int | min...100 |
| defaultIncrementKg | Double | 0.5...20 |
| isCustom | Bool | 内置 false |
| isArchived | Bool | 删除自定义动作为 true 或物理删除；列表不展示 |
| lastUsedAt | Date? | 最近排序 |

名称重复校验：trim → 合并连续空白 → 使用大小写/全半角不敏感比较。内置 stableID 永不变化。

### WorkoutSession

| 字段 | 类型 | 约束 |
|---|---|---|
| id | UUID | 主键 |
| startedAt | Date | 建立 draft 时写入 |
| endedAt | Date? | completed/abandoned 时写入 |
| localDayKey | String | 完成/打卡归属日 |
| statusRaw | String | 状态机约束 |
| focusBodyPartsCSV | String | 从 entry 快照派生并保存 |
| notes | String? | 可选 |
| entries | [ExerciseEntry] | cascade delete |
| createdAt/updatedAt | Date | 自动维护 |

仅允许一个 `draft` 或 `inProgress`。`duration` 从 startedAt/endedAt 计算。

### ExerciseEntry

| 字段 | 类型 | 约束 |
|---|---|---|
| id | UUID | 主键 |
| orderIndex | Int | 0...3，同 Session 唯一 |
| exerciseStableID | String | 历史关联键 |
| exerciseNameSnapshot | String | 永久可读 |
| bodyPartSnapshotRaw | String | 永久可读 |
| loadTypeSnapshotRaw | String | 永久可读 |
| statusRaw | String | pending/completed/skipped |
| sets | [SetEntry] | cascade delete |

同一 WorkoutSession 内 `exerciseStableID` 不可重复。只有 completed entry 参与力量趋势。

### SetEntry

| 字段 | 类型 | 约束 |
|---|---|---|
| id | UUID | 主键 |
| orderIndex | Int | 从 0 连续编号 |
| weightKg | Double | 0...500，最多一位小数 |
| reps | Int | 1...100 |
| isCompleted | Bool | 只有 true 才是有效工作组 |
| completedAt | Date? | 完成时写入 |
| updatedAt | Date | 编辑时更新 |

普通负重 0kg 合法但不计算估算力量；自重动作 0 表示无附加负重；辅助动作 weight 表示辅助重量。

### CheckIn

| 字段 | 类型 | 约束 |
|---|---|---|
| id | UUID | 主键 |
| occurredAt | Date | 打卡时间 |
| localDayKey | String | 周训练日去重键 |
| sourceRaw | String | workout/manual |
| workoutID | UUID? | 自动打卡必填，手动为空 |
| bodyPartRaw | String | 手动选择或训练主部位 |
| notes | String? | 手动打卡可填 |

周训练天数 = 时间范围内 CheckIn 和 completed Session 的 localDayKey 唯一集合。Session 是自动打卡缺失时的兜底事实来源。

## 3. 关系与删除

```text
WorkoutSession 1 ─────── * ExerciseEntry 1 ─────── * SetEntry

Exercise ──(stableID 文本关联)── ExerciseEntry
WorkoutSession ──(UUID 文本关联)── CheckIn

UserProfile                 BodyMeasurement
    单例                      独立时间序列
```

- Session 删除时级联删除 Entry 和 Set，并删除关联自动 CheckIn。
- Exercise 不使用 SwiftData 强关系连接历史，避免删除自定义动作破坏记录。
- 删除记录提供短暂撤销，撤销对象必须包含 Session → Entry → Set 和 CheckIn 完整快照。
- 编辑历史后不修改名称快照，除非用户明确编辑历史动作名称。

## 4. 查询定义

### 最近有效表现

```text
session.status == completed
AND session.id != currentSessionID
AND entry.exerciseStableID == targetStableID
AND entry.status == completed
AND entry.sets contains isCompleted == true
ORDER BY session.endedAt DESC
LIMIT 1
```

### 力量趋势点

- 普通负重：每次 Session 取有效 1...10 次组的最高估算 1RM。
- 自重：取单组最高次数，同时独立保留最大附加重量。
- 辅助：取最低辅助重量；相同辅助重量取最高次数。
- skipped、pending、draft、abandoned 记录全部过滤。

### 周训练日

- 周起点固定为用户日历的周一。
- 同一 localDayKey 仅计 1 天。
- 自动训练和手动打卡同时存在也只计 1 天。

## 5. 迁移策略

- Schema V1 包含上述实体。
- 修改展示文案不迁移数据。
- 新增可选字段使用轻量迁移。
- stableID、状态 raw value、关系删除规则发生变化时创建显式 `VersionedSchema` 和迁移计划。
- Debug/Preview 数据只能写入内存容器，禁止污染用户数据库。


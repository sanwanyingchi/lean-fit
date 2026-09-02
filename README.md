# Lean Fit

Lean Fit 是一个完全使用 SwiftUI、SwiftData 与 Swift Charts 构建的本地优先 iOS 力量训练记录 App。产品围绕两件事：让每个动作的下一次训练有明确参考，以及用体重、体脂和单动作力量趋势观察长期变化。

## 打开与运行

1. 使用 Xcode 15.4 或更新版本打开 `LeanFit.xcodeproj`。
2. 选择 iOS 17+ 模拟器或真机。
3. 运行 `LeanFit` Scheme。

App 不依赖第三方库、账号、网络或后端。首次启动会在设备本地播种 32 个常用动作。

启动时会播放可点按跳过的原生品牌动效；开启“减弱动态效果”后会自动使用简化过渡。训练、身体数据和档案均保存在本机。

## 测试

在安装 iOS Simulator runtime 后执行：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -project LeanFit.xcodeproj -scheme LeanFit \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -parallel-testing-enabled NO
```

无 Simulator runtime 时，可先在 macOS 上运行核心规则与 SwiftData 内存库测试：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

当前交付版本已经通过 19 项串行 Xcode 测试（13 项规则/持久化测试、6 项 UI 测试）及无签名 Release 构建；视觉截图覆盖 iPhone 15 Pro、iPhone SE 和深色模式，位于 `Artifacts/VisualQA/`。

## 文档

- `Lean-Fit-PRD.md`：产品需求
- `Specs/TECHNICAL_SPEC.md`：架构、状态流与失败策略
- `Specs/DATA_MODEL_SPEC.md`：SwiftData 数据模型与约束
- `Specs/DESIGN_SPEC.md`：确认后的视觉 Token、组件与验收标准
- `Specs/TEST_SPEC.md`：测试矩阵与发布门禁
- `Artifacts/VisualQA/`：浅色、深色和小屏视觉验收截图

## 隐私

训练、打卡、档案和身体数据全部保存在本机 SwiftData 数据库中，当前版本不进行网络上传。

## 开发者指南

本项目为 iOS 16+ SwiftUI 应用，支持离线运行，核心为 Core Data + CloudKit（可选）与本地 AI（Qwen-1.8B 计划）。

### 一、如何运行
1. 打开 `ios/StudyPlanner.xcodeproj`。
2. 在 Target → Signing & Capabilities：
   - Team: 选择你的开发团队；
   - Bundle Id: 改为唯一值（如 `com.yourco.studyplanner`）；
   - iCloud: 可保留占位容器，或改为你自己的容器 ID；
3. 选择设备（模拟器或真机）→ Run。

应用内验证：
- 首启完成 Onboarding；
- 设置 → 申请日历访问并写入示例事件；
- 设置 → 启用 Face ID 上锁并“立即锁定”，退至后台再回到前台测试解锁；
- 设置 → 下载离线模型（占位进度）。

### 二、Face ID 集成指南
相关文件：`StudyPlanner/LockManager.swift`、`StudyPlanner/ContentView.swift`、`StudyPlanner/main.swift`

关键点：
- Info.plist 需包含 `NSFaceIDUsageDescription`；
- 使用 `LocalAuthentication` 框架，通过 `LAContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, ...)` 调用；
- 应用进入后台自动锁定：在 `StudyPlannerApp` 中监听 `scenePhase`，进入 `.background` 时 `lockManager.lock()`。

示例：
```swift
@StateObject private var lockManager = LockManager()
@Environment(\.scenePhase) private var scenePhase

.onChange(of: scenePhase) { newPhase in
  if newPhase == .background { lockManager.lock() }
}
```

在 UI 中触发解锁：
```swift
Button("使用 Face ID 解锁") {
  Task { _ = await lockManager.unlockWithBiometrics() }
}
```

### 三、模型与 ODR（Qwen-1.8B）接入
相关文件：`AI/ModelDownloadManager.swift`、`AI/LocalAIPlanner.swift`

当前为占位：通过 `ModelDownloadManager` 模拟下载流程，`LocalAIPlanner` 使用规则模板生成计划。正式接入步骤：
1. 模型准备：
   - 选择 Qwen-1.8B 指令微调版，采用 INT4/INT8 量化；
   - 转换为 Core ML 格式（可用 `coremltools` 或现成转换脚本）。
2. 包体管理：
   - 使用 On-Demand Resources (ODR) 托管模型分片；
   - 在 Xcode 的 Build Phases → Copy Bundle Resources 中为模型文件设置 ODR Tag；
   - 运行时通过 `NSBundleResourceRequest(tags:)` 申请下载并监听进度；
3. 推理接入：
   - 在 `LocalAIPlanner.generatePlan` 中加载 Core ML 模型并执行推理；
   - 控制上下文长度与模板，将“拆解/估时/排期”以规则主导、模型补全细节。

ODR 代码示例（要点）：
```swift
let request = NSBundleResourceRequest(tags: ["qwen18b"])
request.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
request.beginAccessingResources { error in
  // 资源可用后加载模型
}
```

实际接入（本项目）
- Info.plist 占位：
  - `StudyPlannerModelODRTag`：ODR 标签（默认 `qwen18b`）
  - `StudyPlannerModelResourceName`：模型目录/文件名前缀（默认 `Qwen18B`，即打包后 `Qwen18B.mlmodelc`）
- `AI/ModelDownloadManager`：使用 `NSBundleResourceRequest` 申请资源并上报进度（已加中文注释，可直接替换标签）。
- `AI/CoreMLModelProvider`：从 Bundle 中加载 `.mlmodelc` 并提供 `generate(text:)` 占位；实际需替换为模型真实签名的输入/输出。
- `AI/LocalAIPlanner`：模型已下载则尝试加载与调用，否则回退规则模板。

### 四、日历写入
相关文件：`StudyPlanner/CalendarService.swift`

流程：请求权限 → 获取/创建专属日历 → 写入/更新/删除事件。
示例写入：
```swift
try await CalendarService.shared.requestAccess()
let id = try CalendarService.shared.addEvent(
  title: "学习任务",
  start: Date(),
  end: Date().addingTimeInterval(3600),
  notes: "备注"
)
```

冲突规避与空档搜索：
- `findNextFreeSlot(startingAt:durationMinutes:searchHorizonDays:)` 会忽略本应用专属日历，仅与系统/其他日历冲突对齐；
- 调度服务 `SchedulingService` 在写入前会调用空档搜索尽量避开冲突。

### 五、Core Data + CloudKit
相关文件：`StudyPlanner/PersistenceController.swift`

- 使用 `NSPersistentCloudKitContainer`，容器 ID 目前为占位 `iCloud.com.example.studyplanner`；
- 生产环境请在开发者后台创建 CloudKit 容器并替换；
- 默认本地可用，CloudKit 作为可选同步。

### 六、调试与常见问题
- 模拟器 Face ID：Hardware → Face ID → Enrolled；
- 日历权限被拒：系统设置 → 隐私与安全 → 日历，允许本 App；
- iCloud 不生效：需真机登录同一 iCloud，确保网络可用，并使用真实容器 ID；
- ODR 无法下载：检查 Tag、网络与 `ENABLE_ON_DEMAND_RESOURCES=YES` 设置。

### 八、本地通知与后台重排
- 通知权限：设置页“请求通知权限”。
- 触发方式：当任务写入日历时，会自动安排开始前 5 分钟提醒（可在 `SchedulingService` 调整）。
- 后台任务：`BackgroundTaskManager` 使用标识 `com.example.studyplanner.refresh`（可替换）注册每日刷新，激活时自动尝试为未安排任务找空档并写入日历。
- 替换项：在 `Info.plist` 的 `BGTaskSchedulerPermittedIdentifiers` 中替换为你的前缀。

### 七、周视图与排期
- `WeekView.swift`：展示本周 `ScheduleBlock`，支持 +/− 15 分钟位移与删除，自动同步到 EventKit。
- `PlannerView`：提供打开周视图入口与“批量写入未安排任务”，学生一键生成复习曲线并写入日历、职场建议会议准备并写入日历。



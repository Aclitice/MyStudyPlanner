## StudyPlanner iOS

- iOS 16+，SwiftUI，Core Data + CloudKit（占位容器 `iCloud.com.example.studyplanner`）
- EventKit 写入专属日历；Face ID 上锁；本地 AI 与 ODR 下载占位

### 运行
1. 打开 `ios/StudyPlanner.xcodeproj`。
2. 选择团队与 Bundle Id（替换 `com.example.studyplanner` 与 `DEVELOPMENT_TEAM`）。
3. 运行到模拟器/真机。

### 权限
- 日历：`NSCalendarsUsageDescription`、`NSCalendarsWriteOnlyAccess`（可写）
- Face ID：`NSFaceIDUsageDescription`
- iCloud：`StudyPlanner.entitlements` 内 CloudKit 占位容器

### 功能点
- 设置页：申请日历访问并创建示例事件；下载离线模型（占位）
- Onboarding：学生/职场人选择
- Face ID：设置页可开启并立即锁定

### 可替换占位（Info.plist）
- `StudyPlannerICloudContainerId`: iCloud 容器 ID（默认 `iCloud.com.example.studyplanner`）
- `StudyPlannerEnableCloudKit`: 是否启用 CloudKit（默认 true）
- `StudyPlannerModelODRTag`: 模型 ODR 标签（默认 `qwen18b`）
- `StudyPlannerCommunityAPIBaseURL`: 社区 API 基址（默认占位 `https://api.example.com`）

### 后续
- 将 Qwen-1.8B 转 Core ML 并通过 ODR 下载
- 填充 Home/计划视图与 Core Data 交互
- 社区模块与“用 Apple 登录”（仅在线）

更多细节请见 `DEVELOPMENT.md`（运行、Face ID、模型/ODR 接入指南）。


import Foundation
import UIKit

// 模型下载状态（通过 ODR 请求资源）
enum ModelDownloadState: Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case failed(error: String)
}

final class ModelDownloadManager: ObservableObject {
    @Published var state: ModelDownloadState = .notDownloaded
    private var request: NSBundleResourceRequest?

    // 通过 AppConfig.modelODRTag 请求按需资源（ODR），资源内应包含已编译的 Core ML 模型目录（.mlmodelc）
    // 替换项：Info.plist 的 StudyPlannerModelODRTag 与 StudyPlannerModelResourceName
    func startDownloadIfNeeded() async {
        guard case .notDownloaded = state else { return }
        await MainActor.run { self.state = .downloading(progress: 0.0) }

        let tag = AppConfig.modelODRTag
        let req = NSBundleResourceRequest(tags: Set([tag]))
        self.request = req
        req.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent

        // 使用 Progress 监听进度
        let progress = req.progress
        progress.totalUnitCount = 100
        let observation = progress.observe(\.
            fractionCompleted
        ) { [weak self] prog, _ in
            Task { @MainActor in
                self?.state = .downloading(progress: prog.fractionCompleted)
            }
        }

        do {
            try await req.beginAccessingResources()
            observation.invalidate()
            await MainActor.run { self.state = .downloaded }
        } catch {
            observation.invalidate()
            await MainActor.run { self.state = .failed(error: error.localizedDescription) }
        }
    }

    // 可在需要时释放 ODR 资源
    func endAccess() {
        request?.endAccessingResources()
        request = nil
    }
}



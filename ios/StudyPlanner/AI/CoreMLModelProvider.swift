import Foundation
import CoreML

// 负责加载 Core ML 模型（已通过 ODR 下载到本地），并提供简单的推理接口占位
// 替换项：Info.plist -> StudyPlannerModelResourceName（模型目录名/文件名前缀）
final class CoreMLModelProvider {
    static let shared = CoreMLModelProvider()
    private var model: MLModel?

    // 加载 .mlmodelc 目录中的模型文件
    func loadModelIfNeeded() throws {
        if model != nil { return }
        let resourceName = (Bundle.main.object(forInfoDictionaryKey: "StudyPlannerModelResourceName") as? String) ?? "Qwen18B"
        // 约定：ODR 资源中包含名为 resourceName 的 .mlmodelc 目录
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "mlmodelc") else {
            throw NSError(domain: "CoreMLModelProvider", code: 1, userInfo: [NSLocalizedDescriptionKey: "未找到模型资源 \(resourceName).mlmodelc，请确认 ODR 资源与 Info.plist 配置"])
        }
        model = try MLModel(contentsOf: url)
    }

    // 简化的推理占位：实际应根据模型签名构造输入与解析输出
    func generate(text: String) throws -> String {
        // 占位实现：真实接入时用 model?.prediction(...) 并解析输出
        return "[Qwen 推理占位] \(text.prefix(64))..."
    }
}



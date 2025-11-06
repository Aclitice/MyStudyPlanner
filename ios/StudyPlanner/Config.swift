import Foundation

enum AppConfig {
    static var iCloudContainerId: String {
        (Bundle.main.object(forInfoDictionaryKey: "StudyPlannerICloudContainerId") as? String) ?? "iCloud.com.example.studyplanner"
    }

    static var enableCloudKit: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "StudyPlannerEnableCloudKit") as? Bool) ?? true
    }

    static var modelODRTag: String {
        (Bundle.main.object(forInfoDictionaryKey: "StudyPlannerModelODRTag") as? String) ?? "qwen18b"
    }

    static var communityAPIBaseURL: String {
        // 示例：仅占位，未来用于“社区/分享”模块
        (Bundle.main.object(forInfoDictionaryKey: "StudyPlannerCommunityAPIBaseURL") as? String) ?? "https://api.example.com"
    }
}



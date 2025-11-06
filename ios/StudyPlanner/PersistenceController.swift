import Foundation
import CoreData

final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        let model = Self.makeModel()
        container = NSPersistentCloudKitContainer(name: "Model", managedObjectModel: model)

        if let description = container.persistentStoreDescriptions.first {
            if inMemory {
                description.url = URL(fileURLWithPath: "/dev/null")
            }
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
            if AppConfig.enableCloudKit {
                let options = NSPersistentCloudKitContainerOptions(containerIdentifier: AppConfig.iCloudContainerId)
                description.cloudKitContainerOptions = options
            }
        } else {
            let description = NSPersistentStoreDescription()
            description.type = NSSQLiteStoreType
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
            if AppConfig.enableCloudKit {
                description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: AppConfig.iCloudContainerId)
            }
            container.persistentStoreDescriptions = [description]
        }

        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Unresolved error loading persistent stores: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // UserProfile
        let userProfile = NSEntityDescription()
        userProfile.name = "UserProfile"
        userProfile.managedObjectClassName = "NSManagedObject"
        userProfile.properties = [
            attribute(name: "id", type: .UUIDAttributeType, isOptional: false, defaultValue: UUID()),
            attribute(name: "persona", type: .stringAttributeType, isOptional: false, defaultValue: "student"),
            attribute(name: "enableFaceId", type: .booleanAttributeType, isOptional: false, defaultValue: true),
            attribute(name: "createdAt", type: .dateAttributeType, isOptional: false, defaultValue: Date())
        ]

        // Goal
        let goal = NSEntityDescription()
        goal.name = "Goal"
        goal.managedObjectClassName = "NSManagedObject"
        goal.properties = [
            attribute(name: "id", type: .UUIDAttributeType, isOptional: false, defaultValue: UUID()),
            attribute(name: "title", type: .stringAttributeType),
            attribute(name: "targetLevel", type: .stringAttributeType, isOptional: true),
            attribute(name: "deadline", type: .dateAttributeType, isOptional: true),
            attribute(name: "priority", type: .integer16AttributeType, isOptional: false, defaultValue: 0),
            attribute(name: "createdAt", type: .dateAttributeType, isOptional: false, defaultValue: Date())
        ]

        // Task
        let task = NSEntityDescription()
        task.name = "Task"
        task.managedObjectClassName = "NSManagedObject"
        task.properties = [
            attribute(name: "id", type: .UUIDAttributeType, isOptional: false, defaultValue: UUID()),
            attribute(name: "title", type: .stringAttributeType),
            attribute(name: "estimatedMinutes", type: .integer32AttributeType, isOptional: false, defaultValue: 60),
            attribute(name: "difficulty", type: .integer16AttributeType, isOptional: false, defaultValue: 1),
            attribute(name: "status", type: .stringAttributeType, isOptional: false, defaultValue: "todo"),
            attribute(name: "type", type: .stringAttributeType, isOptional: false, defaultValue: "study"),
            attribute(name: "dueDate", type: .dateAttributeType, isOptional: true),
            attribute(name: "goalId", type: .UUIDAttributeType, isOptional: true),
            attribute(name: "order", type: .integer32AttributeType, isOptional: false, defaultValue: 0)
        ]

        // ScheduleBlock
        let block = NSEntityDescription()
        block.name = "ScheduleBlock"
        block.managedObjectClassName = "NSManagedObject"
        block.properties = [
            attribute(name: "id", type: .UUIDAttributeType, isOptional: false, defaultValue: UUID()),
            attribute(name: "taskId", type: .UUIDAttributeType, isOptional: true),
            attribute(name: "start", type: .dateAttributeType),
            attribute(name: "end", type: .dateAttributeType),
            attribute(name: "locked", type: .booleanAttributeType, isOptional: false, defaultValue: false),
            attribute(name: "eventIdentifier", type: .stringAttributeType, isOptional: true)
        ]
        
        // StudyStats (NEW)
        let studyStats = NSEntityDescription()
        studyStats.name = "StudyStats"
        studyStats.managedObjectClassName = "NSManagedObject"
        studyStats.properties = [
            attribute(name: "id", type: .UUIDAttributeType, isOptional: false, defaultValue: UUID()),
            attribute(name: "date", type: .dateAttributeType, isOptional: false, defaultValue: Date()),
            attribute(name: "taskId", type: .UUIDAttributeType, isOptional: true),
            attribute(name: "goalId", type: .UUIDAttributeType, isOptional: true),
            attribute(name: "plannedMinutes", type: .integer32AttributeType, isOptional: false, defaultValue: 0),
            attribute(name: "actualMinutes", type: .integer32AttributeType, isOptional: false, defaultValue: 0),
            attribute(name: "completionStatus", type: .stringAttributeType, isOptional: false, defaultValue: "completed"),
            attribute(name: "focusScore", type: .doubleAttributeType, isOptional: true), // 0.0-1.0
            attribute(name: "notes", type: .stringAttributeType, isOptional: true)
        ]

        model.entities = [userProfile, goal, task, block, studyStats]
        return model
    }

    static func attribute(name: String, type: NSAttributeType, isOptional: Bool = false, defaultValue: Any? = nil) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = type
        attr.isOptional = isOptional
        attr.isIndexed = true
        if let defaultValue = defaultValue {
            attr.defaultValue = defaultValue
        }
        return attr
    }
}



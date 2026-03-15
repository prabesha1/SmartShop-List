import Foundation
import CoreData

/// Programmatic Core Data stack — no .xcdatamodeld file needed.
/// Both Windows (Cursor editing) and macOS (Xcode building) devs can work
/// on this project without any platform-specific configuration.
enum PersistenceController {

    // MARK: - Production store (SQLite on disk)

    static let shared: NSPersistentContainer = {
        let model = Self.makeModel()
        let container = NSPersistentContainer(name: "SmartShopModel", managedObjectModel: model)

        // Enable lightweight migration so adding new attributes never crashes.
        if let description = container.persistentStoreDescriptions.first {
            description.setOption(true as NSNumber,
                                  forKey: NSMigratePersistentStoresAutomaticallyOption)
            description.setOption(true as NSNumber,
                                  forKey: NSInferMappingModelAutomaticallyOption)
        }

        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Unresolved Core Data error: \(error)")
            }
            container.viewContext.automaticallyMergesChangesFromParent = true
            container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        }
        return container
    }()

    // MARK: - In-memory store for SwiftUI Previews only

    static let preview: NSPersistentContainer = {
        let model = Self.makeModel()
        let container = NSPersistentContainer(name: "SmartShopModel", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Preview Core Data error: \(error)")
            }
        }

        let context = container.viewContext

        // Seed a sample group + items so previews have something to render.
        let demoGroup = GroupEntity(context: context)
        demoGroup.id = UUID()
        demoGroup.name = "Weekly Groceries"
        demoGroup.createdAt = Date()

        let sampleItems: [(String, Double, Bool)] = [
            ("Milk", 4.79, false),
            ("Bread", 3.29, true),
            ("Eggs", 5.49, false),
            ("Butter", 6.99, false),
            ("Apples", 3.99, true)
        ]
        for (name, price, done) in sampleItems {
            let item = ItemEntity(context: context)
            item.id = UUID()
            item.name = name
            item.price = price
            item.isCompleted = done
            item.createdAt = Date()
            item.group = demoGroup
        }
        try? context.save()
        return container
    }()

    // MARK: - Programmatic model definition

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // ── GroupEntity ──────────────────────────────────────
        let groupEntity = NSEntityDescription()
        groupEntity.name = "GroupEntity"
        groupEntity.managedObjectClassName = NSStringFromClass(GroupEntity.self)

        let groupId = NSAttributeDescription()
        groupId.name = "id"
        groupId.attributeType = .UUIDAttributeType
        groupId.isOptional = false

        let groupName = NSAttributeDescription()
        groupName.name = "name"
        groupName.attributeType = .stringAttributeType
        groupName.isOptional = false

        let groupCreatedAt = NSAttributeDescription()
        groupCreatedAt.name = "createdAt"
        groupCreatedAt.attributeType = .dateAttributeType
        groupCreatedAt.isOptional = false

        let groupIsArchived = NSAttributeDescription()
        groupIsArchived.name = "isArchived"
        groupIsArchived.attributeType = .booleanAttributeType
        groupIsArchived.isOptional = false
        groupIsArchived.defaultValue = false

        let groupIsTemplate = NSAttributeDescription()
        groupIsTemplate.name = "isTemplate"
        groupIsTemplate.attributeType = .booleanAttributeType
        groupIsTemplate.isOptional = false
        groupIsTemplate.defaultValue = false

        let groupBudget = NSAttributeDescription()
        groupBudget.name = "budget"
        groupBudget.attributeType = .doubleAttributeType
        groupBudget.isOptional = false
        groupBudget.defaultValue = 0.0

        let groupDueDate = NSAttributeDescription()
        groupDueDate.name = "dueDate"
        groupDueDate.attributeType = .dateAttributeType
        groupDueDate.isOptional = true

        let groupReminderEnabled = NSAttributeDescription()
        groupReminderEnabled.name = "reminderEnabled"
        groupReminderEnabled.attributeType = .booleanAttributeType
        groupReminderEnabled.isOptional = false
        groupReminderEnabled.defaultValue = false

        let groupLastBudgetAlertLevel = NSAttributeDescription()
        groupLastBudgetAlertLevel.name = "lastBudgetAlertLevel"
        groupLastBudgetAlertLevel.attributeType = .integer16AttributeType
        groupLastBudgetAlertLevel.isOptional = false
        groupLastBudgetAlertLevel.defaultValue = 0

        let groupBudgetHistoryData = NSAttributeDescription()
        groupBudgetHistoryData.name = "budgetHistoryData"
        groupBudgetHistoryData.attributeType = .binaryDataAttributeType
        groupBudgetHistoryData.isOptional = true
        groupBudgetHistoryData.allowsExternalBinaryDataStorage = true

        // ── ItemEntity ───────────────────────────────────────
        let itemEntity = NSEntityDescription()
        itemEntity.name = "ItemEntity"
        itemEntity.managedObjectClassName = NSStringFromClass(ItemEntity.self)

        let itemId = NSAttributeDescription()
        itemId.name = "id"
        itemId.attributeType = .UUIDAttributeType
        itemId.isOptional = false

        let itemName = NSAttributeDescription()
        itemName.name = "name"
        itemName.attributeType = .stringAttributeType
        itemName.isOptional = false

        let itemPrice = NSAttributeDescription()
        itemPrice.name = "price"
        itemPrice.attributeType = .doubleAttributeType
        itemPrice.isOptional = false

        let itemIsCompleted = NSAttributeDescription()
        itemIsCompleted.name = "isCompleted"
        itemIsCompleted.attributeType = .booleanAttributeType
        itemIsCompleted.isOptional = false
        itemIsCompleted.defaultValue = false

        let itemCreatedAt = NSAttributeDescription()
        itemCreatedAt.name = "createdAt"
        itemCreatedAt.attributeType = .dateAttributeType
        itemCreatedAt.isOptional = false

        let itemQuantity = NSAttributeDescription()
        itemQuantity.name = "quantity"
        itemQuantity.attributeType = .doubleAttributeType
        itemQuantity.isOptional = false
        itemQuantity.defaultValue = 1.0

        let itemUnit = NSAttributeDescription()
        itemUnit.name = "unit"
        itemUnit.attributeType = .stringAttributeType
        itemUnit.isOptional = true

        let itemNote = NSAttributeDescription()
        itemNote.name = "note"
        itemNote.attributeType = .stringAttributeType
        itemNote.isOptional = true

        let itemSortOrder = NSAttributeDescription()
        itemSortOrder.name = "sortOrder"
        itemSortOrder.attributeType = .integer64AttributeType
        itemSortOrder.isOptional = false
        itemSortOrder.defaultValue = 0

        // ── Relationships ────────────────────────────────────
        let itemsRelationship = NSRelationshipDescription()
        itemsRelationship.name = "items"
        itemsRelationship.destinationEntity = itemEntity
        itemsRelationship.minCount = 0
        itemsRelationship.maxCount = 0          // 0 == to-many
        itemsRelationship.deleteRule = .cascadeDeleteRule
        itemsRelationship.isOptional = true
        itemsRelationship.isOrdered = false

        let groupRelationship = NSRelationshipDescription()
        groupRelationship.name = "group"
        groupRelationship.destinationEntity = groupEntity
        groupRelationship.minCount = 1
        groupRelationship.maxCount = 1
        groupRelationship.deleteRule = .nullifyDeleteRule
        groupRelationship.isOptional = false
        groupRelationship.isOrdered = false

        itemsRelationship.inverseRelationship = groupRelationship
        groupRelationship.inverseRelationship = itemsRelationship

        groupEntity.properties  = [groupId, groupName, groupCreatedAt, groupIsArchived, groupIsTemplate, groupBudget, groupDueDate, groupReminderEnabled, groupLastBudgetAlertLevel, groupBudgetHistoryData, itemsRelationship]
        itemEntity.properties   = [itemId, itemName, itemPrice, itemIsCompleted, itemCreatedAt, itemQuantity, itemUnit, itemNote, itemSortOrder, groupRelationship]

        model.entities = [groupEntity, itemEntity]
        return model
    }
}

// MARK: - Managed-Object Subclasses

@objc(GroupEntity)
final class GroupEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var createdAt: Date
    @NSManaged var isArchived: Bool
    @NSManaged var isTemplate: Bool
    @NSManaged var budget: Double
    @NSManaged var dueDate: Date?
    @NSManaged var reminderEnabled: Bool
    @NSManaged var lastBudgetAlertLevel: Int16
    @NSManaged var budgetHistoryData: Data?
    @NSManaged var items: Set<ItemEntity>?

    var sortedItems: [ItemEntity] {
        (items ?? []).sorted { $0.createdAt < $1.createdAt }
    }
}

@objc(ItemEntity)
final class ItemEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var price: Double
    @NSManaged var isCompleted: Bool
    @NSManaged var createdAt: Date
    @NSManaged var quantity: Double
    @NSManaged var unit: String?
    @NSManaged var note: String?
    @NSManaged var sortOrder: Int64
    @NSManaged var group: GroupEntity
}

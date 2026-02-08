import Foundation
import CoreData

/// Programmatic Core Data stack so we don't rely on an .xcdatamodeld file.
enum PersistenceController {
    static let shared: NSPersistentContainer = {
        let model = Self.makeModel()
        let container = NSPersistentContainer(name: "SmartShopModel", managedObjectModel: model)
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Unresolved Core Data error: \(error)")
            }
            container.viewContext.automaticallyMergesChangesFromParent = true
            container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        }
        return container
    }()

    /// In-memory store used by previews.
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
        // Seed a sample group and items for SwiftUI previews.
        let demoGroup = GroupEntity(context: context)
        demoGroup.id = UUID()
        demoGroup.name = "Weekly Groceries"
        demoGroup.createdAt = Date()
        let sampleItems: [(String, Double, Bool)] = [
            ("Milk", 4.79, false),
            ("Bread", 3.29, true),
            ("Eggs", 5.49, false)
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

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // Group entity
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

        // Item entity
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

        // Relationships
        let itemsRelationship = NSRelationshipDescription()
        itemsRelationship.name = "items"
        itemsRelationship.destinationEntity = itemEntity
        itemsRelationship.minCount = 0
        itemsRelationship.maxCount = 0 // 0 == no max
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

        groupEntity.properties = [groupId, groupName, groupCreatedAt, itemsRelationship]
        itemEntity.properties = [itemId, itemName, itemPrice, itemIsCompleted, itemCreatedAt, groupRelationship]

        model.entities = [groupEntity, itemEntity]
        return model
    }
}

// MARK: - Managed Object subclasses

@objc(GroupEntity)
final class GroupEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var createdAt: Date
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
    @NSManaged var group: GroupEntity
}

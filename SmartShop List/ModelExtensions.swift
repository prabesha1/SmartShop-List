import Foundation
import CoreData

extension GroupEntity: Identifiable {}
extension ItemEntity: Identifiable {}

extension NSManagedObjectContext {
    func saveIfNeeded() {
        guard hasChanges else { return }
        do {
            try save()
        } catch {
            assertionFailure("Core Data save error: \(error)")
        }
    }
}

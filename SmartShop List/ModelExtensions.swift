import Foundation
import CoreData

// MARK: - Identifiable conformance for SwiftUI ForEach / List

extension GroupEntity: Identifiable {}
extension ItemEntity: Identifiable {}

// MARK: - Convenience save helper

extension NSManagedObjectContext {
    /// Saves only when there are uncommitted changes, and handles errors gracefully.
    func saveIfNeeded() {
        guard hasChanges else { return }
        do {
            try save()
        } catch {
            assertionFailure("Core Data save error: \(error)")
        }
    }
}

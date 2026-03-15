import Foundation
import CoreData

// MARK: - Identifiable conformance for SwiftUI ForEach / List

extension GroupEntity: Identifiable {}
extension ItemEntity: Identifiable {}

// MARK: - Computed helpers

extension ItemEntity {
    var totalPrice: Double {
        let qty = max(quantity, 0)
        return price * qty
    }
}

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

struct BudgetSnapshot: Codable {
    let date: Date
    let total: Double
}

extension GroupEntity {
    var budgetHistory: [BudgetSnapshot] {
        get {
            guard let data = budgetHistoryData else { return [] }
            return (try? JSONDecoder().decode([BudgetSnapshot].self, from: data)) ?? []
        }
        set {
            budgetHistoryData = try? JSONEncoder().encode(newValue)
        }
    }

    func recordBudgetSnapshot(total: Double) {
        var history = budgetHistory
        history.append(BudgetSnapshot(date: Date(), total: total))
        // Keep last 30 entries to bound storage
        if history.count > 30 {
            history.removeFirst(history.count - 30)
        }
        budgetHistory = history
    }
}

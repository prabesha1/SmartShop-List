// SmartShop List
// Team - G20
// Prabesh Shrestha — 101538718
// Moksh Chhetri — 101515045

import Foundation
import CoreData

extension GroupEntity: Identifiable {}
extension ItemEntity: Identifiable {}

extension ItemEntity {
    var totalPrice: Double {
        let qty = max(quantity, 0)
        return price * qty
    }
}

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
        let now = Date()

        if let last = history.last {
            let delta = abs(last.total - total)
            let elapsed = now.timeIntervalSince(last.date)

            // Skip near-duplicate points and replace very recent ones to reduce write churn.
            if delta < 0.01, elapsed < 60 {
                return
            }
            if elapsed < 20 {
                history[history.count - 1] = BudgetSnapshot(date: now, total: total)
                budgetHistory = history
                return
            }
        }

        history.append(BudgetSnapshot(date: now, total: total))
        // Keep last 30 entries to bound storage
        if history.count > 30 {
            history.removeFirst(history.count - 30)
        }
        budgetHistory = history
    }
}

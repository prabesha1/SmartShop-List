// SmartShop List
// Team - G20
// Prabesh Shrestha — 101538718
// Moksh Chhetri — 101515045

import SwiftUI
import CoreData

@main
struct SmartShop_ListApp: App {
    private let container = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, container.viewContext)
        }
    }
}

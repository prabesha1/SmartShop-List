//
//  SmartShop_ListApp.swift
//  SmartShop List
//
//  Created by Prabesh Shrestha on 2026-02-08.
//

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

# SmartShop List

## Team - G20

- Prabesh Shrestha — 101538718
- Moksh Chhetri — 101515045

SmartShop List is an iOS shopping list app built with SwiftUI and Core Data.  
It helps you organize lists by category, track item costs, monitor totals with tax, and stay within budget while shopping.

## What the app does

- Create multiple shopping lists (for example: groceries, pharmacy, electronics)
- Add items with price, quantity, unit, and optional notes
- Mark items as completed and track progress
- View subtotal, tax, and total in real time
- Set optional budget limits with visual budget status
- Archive and unarchive lists
- Set due-date reminders for lists
- Export list data to CSV and copy checklist text for external apps

## Built with

- SwiftUI for the interface
- Core Data for local persistence
- UserNotifications for reminder scheduling
- Xcode project (no external package dependencies required)

## Running the project

1. Open `SmartShop List.xcodeproj` in Xcode.
2. Select an iOS Simulator or a connected iPhone.
3. Build and run the `SmartShop List` scheme.

## Project structure

- `SmartShop List/ContentView.swift`  
  Main list screen, list management, search, archive filter, and profile sheet entry.
- `SmartShop List/GroupDetailView.swift`  
  Item-level operations, completion tracking, totals, budget checks, and reminders.
- `SmartShop List/Persistence.swift`  
  Programmatic Core Data model and persistent container setup.
- `SmartShop List/ModelExtensions.swift`  
  Helper methods for model calculations and context save utilities.



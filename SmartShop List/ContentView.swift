//
//  ContentView.swift
//  SmartShop List
//
//  Created by Prabesh Shrestha on 2026-02-08.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \GroupEntity.createdAt, ascending: true)],
        animation: .default
    )
    private var groups: FetchedResults<GroupEntity>

    @State private var showingAddGroup = false

    var body: some View {
        NavigationStack {
            Group {
                if groups.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(groups) { group in
                            NavigationLink {
                                GroupDetailView(group: group)
                            } label: {
                                GroupRow(group: group)
                            }
                        }
                        .onDelete(perform: deleteGroups)
                    }
                }
            }
            .navigationTitle("SmartShop")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddGroup = true
                    } label: {
                        Label("Add list", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddGroup) {
                AddGroupSheet { name in
                    addGroup(named: name)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "cart.fill.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            Text("Start a shopping list")
                .font(.headline)
            Text("Create categories like Groceries, Electronics, or Pharmacy.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    private func addGroup(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let group = GroupEntity(context: context)
        group.id = UUID()
        group.name = trimmed
        group.createdAt = Date()
        context.saveIfNeeded()
    }

    private func deleteGroups(at offsets: IndexSet) {
        for index in offsets {
            context.delete(groups[index])
        }
        context.saveIfNeeded()
    }
}

private struct GroupRow: View {
    @ObservedObject var group: GroupEntity

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.headline)
                Text("\(itemCount) item\(itemCount == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if let subtotal = group.items?.reduce(0, { $0 + $1.price }), subtotal > 0 {
                Text(subtotal, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(.vertical, 6)
    }

    private var itemCount: Int {
        group.items?.count ?? 0
    }
}

private struct AddGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    var onSave: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Category name") {
                    TextField("e.g., Weekly Food", text: $name)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                }
            }
            .navigationTitle("New Category")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}

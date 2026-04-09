//
//  ContentView.swift
//  SmartShop List
//
//  Created by Prabesh Shrestha on 2026-02-08.
//

import SwiftUI
import CoreData
import UIKit

// MARK: - Main Content View

struct ContentView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \GroupEntity.createdAt, ascending: false)],
        animation: .smooth
    )
    private var groups: FetchedResults<GroupEntity>

    @State private var showingAddGroup = false
    @State private var searchText = ""
    @State private var showArchived = false
    @State private var renamingGroup: GroupEntity?
    @State private var renameText = ""

    private var filteredGroups: [GroupEntity] {
        let base = groups.filter { showArchived ? true : !$0.isArchived }
        if searchText.isEmpty { return Array(base) }
        return base.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    private var hasArchivedGroups: Bool {
        groups.contains(where: \.isArchived)
    }
    private var isArchiveFilterHidingResults: Bool {
        !showArchived && searchText.isEmpty && filteredGroups.isEmpty && hasArchivedGroups
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundView

                if groups.isEmpty {
                    emptyStateView
                } else if isArchiveFilterHidingResults {
                    hiddenArchivedStateView
                } else if filteredGroups.isEmpty {
                    emptySearchStateView
                } else {
                    groupsScrollView
                }
            }
            .navigationTitle("SmartShop")
            .searchable(text: $searchText, prompt: "Search lists…")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAddGroup = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.tint)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Toggle("Show archived", isOn: $showArchived)
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.title3)
                            .foregroundStyle(.tint)
                    }
                }
            }
            .sheet(isPresented: $showingAddGroup) {
                AddGroupSheet { name in addGroup(named: name) }
                    .presentationDetents([.medium])
                    .presentationCornerRadius(24)
                    .presentationBackground(.ultraThinMaterial)
            }
            .alert("Rename List", isPresented: Binding(get: { renamingGroup != nil }, set: { if !$0 { renamingGroup = nil } })) {
                TextField("Name", text: $renameText)
                Button("Save", action: applyRename)
                Button("Cancel", role: .cancel) { renamingGroup = nil }
            } message: {
                Text("Update the list name.")
            }
        }
    }

    // MARK: - Background

    private var backgroundView: some View {
        LinearGradient(
            colors: [
                Color(.systemGroupedBackground),
                Color.blue.opacity(0.04),
                Color.purple.opacity(0.03),
                Color(.systemGroupedBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Groups List

    private var groupsScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredGroups, id: \.objectID) { group in
                    NavigationLink {
                        GroupDetailView(group: group)
                    } label: {
                        GlassGroupCard(group: group)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            startRenaming(group)
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }

                        Button {
                            duplicate(group)
                        } label: {
                            Label("Duplicate", systemImage: "doc.on.doc")
                        }

                        Button {
                            toggleArchive(group)
                        } label: {
                            Label(group.isArchived ? "Unarchive" : "Archive", systemImage: "archivebox")
                        }

                        Button {
                            group.isTemplate.toggle()
                            context.saveIfNeeded()
                        } label: {
                            Label(group.isTemplate ? "Unmark Template" : "Mark as Template", systemImage: "bookmark")
                        }

                        if let url = csvURL(for: group) {
                            ShareLink(item: url) {
                                Label("Export CSV", systemImage: "square.and.arrow.up")
                            }
                        }

                        Button {
                            copyChecklistToPasteboard(group)
                        } label: {
                            Label("Copy for Reminders", systemImage: "text.badge.plus")
                        }

                        Button(role: .destructive) {
                            withAnimation(.smooth) { deleteGroup(group) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 110, height: 110)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                .linearGradient(
                                    colors: [.blue.opacity(0.3), .purple.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )

                Image(systemName: "cart.fill.badge.plus")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(
                        .linearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.pulse)
            }

            VStack(spacing: 8) {
                Text("Start Shopping Smarter")
                    .font(.title3.weight(.semibold))

                Text("Create categories like Groceries,\nElectronics, or Pharmacy.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showingAddGroup = true
            } label: {
                Label("Create First List", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                .linearGradient(
                                    colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.5
                            )
                    )
                    .shadow(color: .blue.opacity(0.15), radius: 12, y: 6)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(32)
    }

    private var emptySearchStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("No matching lists")
                .font(.headline)
            Text("Try a different keyword or clear search.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
        )
        .padding(.horizontal, 24)
    }

    private var hiddenArchivedStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "archivebox")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Archived lists are hidden")
                .font(.headline)
            Text("Enable \"Show archived\" from the filter menu to view them.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
        )
        .padding(.horizontal, 24)
    }

    // MARK: - Actions

    private func addGroup(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation(.smooth) {
            let group = GroupEntity(context: context)
            group.id = UUID()
            group.name = trimmed
            group.createdAt = Date()
            context.saveIfNeeded()
        }
    }

    private func deleteGroup(_ group: GroupEntity) {
        context.delete(group)
        context.saveIfNeeded()
    }

    private func startRenaming(_ group: GroupEntity) {
        renamingGroup = group
        renameText = group.name
    }

    private func applyRename() {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let group = renamingGroup, !trimmed.isEmpty else { return }
        withAnimation(.smooth) {
            group.name = trimmed
            context.saveIfNeeded()
            renamingGroup = nil
        }
    }

    private func toggleArchive(_ group: GroupEntity) {
        withAnimation(.smooth) {
            group.isArchived.toggle()
            context.saveIfNeeded()
        }
    }

    private func duplicate(_ group: GroupEntity) {
        withAnimation(.smooth) {
            let copy = GroupEntity(context: context)
            copy.id = UUID()
            copy.name = "\(group.name) Copy"
            copy.createdAt = Date()
            copy.isTemplate = group.isTemplate
            copy.budget = group.budget
            copy.isArchived = false

            for (idx, item) in group.sortedItems.enumerated() {
                let newItem = ItemEntity(context: context)
                newItem.id = UUID()
                newItem.name = item.name
                newItem.price = item.price
                newItem.quantity = item.quantity
                newItem.unit = item.unit
                newItem.note = item.note
                newItem.isCompleted = false
                newItem.createdAt = Date()
                newItem.sortOrder = Int64(idx)
                newItem.group = copy
            }
            context.saveIfNeeded()
        }
    }

    private func csvURL(for group: GroupEntity) -> URL? {
        let header = "Name,Quantity,Unit,Price,Total,Note,Completed\n"
        let rows = group.sortedItems.map { item -> String in
            let note = item.note?.replacingOccurrences(of: ",", with: " ") ?? ""
            let unit = item.unit?.replacingOccurrences(of: ",", with: " ") ?? ""
            return "\"\(item.name)\",\(item.quantity),\"\(unit)\",\(item.price),\(item.totalPrice),\"\(note)\",\(item.isCompleted)"
        }.joined(separator: "\n")
        let csv = header + rows
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(group.name)-export.csv")

        guard let data = csv.data(using: .utf8) else { return nil }
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    private func copyChecklistToPasteboard(_ group: GroupEntity) {
        let lines = group.sortedItems.map { item in
            let check = item.isCompleted ? "[x]" : "[ ]"
            return "\(check) \(item.name)"
        }.joined(separator: "\n")
        UIPasteboard.general.string = lines
    }
}

// MARK: - Glass Group Card

private struct GlassGroupCard: View {
    @ObservedObject var group: GroupEntity

    private var itemCount: Int { group.items?.count ?? 0 }
    private var completedCount: Int { group.items?.filter(\.isCompleted).count ?? 0 }
    private var subtotal: Double {
        group.items?.reduce(0.0, { (sum: Double, item: ItemEntity) -> Double in
            sum + item.totalPrice
        }) ?? 0.0
    }
    private var progress: Double {
        guard itemCount > 0 else { return 0 }
        return Double(completedCount) / Double(itemCount)
    }

    private var categoryIcon: String {
        let n = group.name.lowercased()
        if n.contains("grocer") || n.contains("food") || n.contains("market") { return "cart.fill" }
        if n.contains("pharma") || n.contains("health") || n.contains("medic") { return "cross.case.fill" }
        if n.contains("electro") || n.contains("tech") || n.contains("gadget") { return "desktopcomputer" }
        if n.contains("cloth") || n.contains("fashion") || n.contains("wear") { return "tshirt.fill" }
        if n.contains("home") || n.contains("house") || n.contains("furni") { return "house.fill" }
        if n.contains("book") || n.contains("school") || n.contains("office") { return "book.fill" }
        return "bag.fill"
    }

    private var iconColors: [Color] {
        let n = group.name.lowercased()
        if n.contains("grocer") || n.contains("food") { return [.green, .mint] }
        if n.contains("pharma") || n.contains("health") { return [.red, .pink] }
        if n.contains("electro") || n.contains("tech") { return [.blue, .cyan] }
        if n.contains("cloth") || n.contains("fashion") { return [.orange, .yellow] }
        return [.indigo, .purple]
    }

    var body: some View {
        HStack(spacing: 14) {
            // Category icon
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(width: 48, height: 48)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                    )

                Image(systemName: categoryIcon)
                    .font(.title3)
                    .foregroundStyle(
                        .linearGradient(
                            colors: iconColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            // Name & count
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("\(itemCount) item\(itemCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if completedCount > 0 {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text("\(completedCount) done")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }

            Spacer()

            // Price & progress
            VStack(alignment: .trailing, spacing: 6) {
                if subtotal > 0 {
                    Text(subtotal, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .font(.subheadline.weight(.semibold))
                        .contentTransition(.numericText())
                }

                if itemCount > 0 {
                    ProgressView(value: progress)
                        .tint(progress >= 1.0 ? .green : .blue)
                        .frame(width: 48)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    .linearGradient(
                        colors: [.white.opacity(0.25), .white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }
}

// MARK: - Add Group Sheet

private struct AddGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool
    @State private var name = ""
    var onSave: (String) -> Void

    private let suggestions: [(String, String)] = [
        ("🛒", "Groceries"),
        ("💊", "Pharmacy"),
        ("📱", "Electronics"),
        ("👕", "Clothing"),
        ("🏠", "Home"),
        ("📚", "Office")
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                // Name input
                VStack(alignment: .leading, spacing: 8) {
                    Text("LIST NAME")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)

                    TextField("e.g., Weekly Groceries", text: $name)
                        .textInputAutocapitalization(.words)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                        )
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit { save() }
                }

                // Quick suggestions
                VStack(alignment: .leading, spacing: 10) {
                    Text("QUICK START")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                        spacing: 10
                    ) {
                        ForEach(suggestions, id: \.1) { emoji, label in
                            Button {
                                name = label
                            } label: {
                                Text("\(emoji) \(label)")
                                    .font(.caption.weight(.medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 11)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("New List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { save() }
                        .font(.headline)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear { focused = true }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSave(trimmed)
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}

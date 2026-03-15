//
//  GroupDetailView.swift
//  SmartShop List
//
//  Created by Prabesh Shrestha on 2026-02-08.
//

import SwiftUI
import CoreData
import UserNotifications

// MARK: - Group Detail View

struct GroupDetailView: View {
    @ObservedObject var group: GroupEntity
    @Environment(\.managedObjectContext) private var context
    @FetchRequest private var items: FetchedResults<ItemEntity>

    @State private var showingAddItem = false
    @State private var showingTaxSheet = false
    @State private var showingBudgetSheet = false
    @State private var showingReminderSheet = false
    @State private var sortingMode: SortingMode = .manual
    @State private var showUncheckedOnly = false
    @State private var hasSentBudgetAlert = false
    @AppStorage("taxRate") private var taxRate: Double = 0.13

    init(group: GroupEntity) {
        self.group = group
        _items = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \ItemEntity.createdAt, ascending: true)],
            predicate: NSPredicate(format: "group == %@", group),
            animation: .smooth
        )
    }

    enum SortingMode: String, CaseIterable, Identifiable {
        case manual = "Manual"
        case price = "Price"
        case completion = "Completion"

        var id: String { rawValue }
    }

    private var groupBudget: Double? {
        // Treat zero as "no budget" so UI can clear the value while the Core Data field stays non-optional
        group.budget == 0 ? nil : group.budget
    }
    private var completedCount: Int { items.filter(\.isCompleted).count }
    private var subtotal: Double { items.reduce(0.0) { $0 + $1.totalPrice } }
    private var progress: Double {
        guard !items.isEmpty else { return 0 }
        return Double(completedCount) / Double(items.count)
    }

    private var totalWithTax: Double { subtotal * (1 + taxRate) }
    // threshold helpers computed inline when evaluating alerts

    private var visibleItems: [ItemEntity] {
        let base: [ItemEntity] = Array(items)
        let sorted: [ItemEntity]
        switch sortingMode {
        case .manual:
            sorted = base.sorted { $0.sortOrder < $1.sortOrder }
        case .price:
            sorted = base.sorted { $0.totalPrice > $1.totalPrice }
        case .completion:
            sorted = base.sorted {
                ($0.isCompleted ? 1 : 0, $0.createdAt) <
                ($1.isCompleted ? 1 : 0, $1.createdAt)
            }
        }
        return showUncheckedOnly ? sorted.filter { !$0.isCompleted } : sorted
    }

    var body: some View {
        ZStack {
            backgroundView

            List {
                // Progress summary section
                if !items.isEmpty {
                    Section {
                        SummaryCard(
                            itemCount: items.count,
                            completedCount: completedCount,
                            progress: progress
                        )
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                }

                // Items section
                Section {
                    if items.isEmpty {
                        emptyItemsView
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(visibleItems) { item in
                            GlassItemRow(item: item, toggle: toggleCompletion)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
                        }
                        .onDelete(perform: deleteItems)
                        .onMove(perform: moveItems)
                        .moveDisabled(sortingMode != .manual || showUncheckedOnly)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(group.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingAddItem = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.tint)
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    Section("Sort") {
                        Picker("Sort Mode", selection: $sortingMode) {
                            ForEach(SortingMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                    }

                    Toggle("Show unchecked only", isOn: $showUncheckedOnly)

                    Section("Settings") {
                        Button {
                            showingTaxSheet = true
                        } label: {
                            Label("Tax: \(String(format: "%.1f", taxRate * 100))%", systemImage: "percent")
                        }
                        Button {
                            showingBudgetSheet = true
                        } label: {
                            Label("Budget", systemImage: "dollarsign.circle")
                        }
                        Button {
                            showingReminderSheet = true
                        } label: {
                            Label(group.reminderEnabled ? "Edit Reminder" : "Add Reminder", systemImage: "bell")
                        }
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3)
                        .foregroundStyle(.tint)
                }
            }
            ToolbarItem(placement: .bottomBar) {
                EditButton()
            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddItemSheet { name, price, quantity, unit, note in
                addItem(name: name, price: price, quantity: quantity, unit: unit, note: note)
            }
            .presentationDetents([.medium])
            .presentationCornerRadius(24)
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showingTaxSheet) {
            TaxRateSheet(taxRate: $taxRate)
                .presentationDetents([.medium])
                .presentationCornerRadius(24)
                .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showingBudgetSheet) {
            BudgetSheet(
                currentBudget: groupBudget,
                onSave: { saveBudget($0) }
            )
            .presentationDetents([.medium])
            .presentationCornerRadius(24)
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showingReminderSheet) {
            ReminderSheet(currentDate: group.dueDate, isEnabled: group.reminderEnabled) { date, enabled in
                saveReminder(date: date, enabled: enabled)
            }
            .presentationDetents([.medium])
            .presentationCornerRadius(24)
            .presentationBackground(.ultraThinMaterial)
        }
        .safeAreaInset(edge: .bottom) {
            if !items.isEmpty {
                GlassTotalsFooter(subtotal: subtotal, taxRate: taxRate, budget: groupBudget, dueDate: group.dueDate, budgetHistory: group.budgetHistory)
            }
        }
        .onChange(of: subtotal) { _, _ in
            group.recordBudgetSnapshot(total: totalWithTax)
            evaluateBudgetAlert()
        }
    }

    // MARK: - Background

    private var backgroundView: some View {
        LinearGradient(
            colors: [
                Color(.systemGroupedBackground),
                Color.blue.opacity(0.03),
                Color(.systemGroupedBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Empty State

    private var emptyItemsView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 80, height: 80)

                Image(systemName: "checklist")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(.secondary)
                    .symbolEffect(.pulse)
            }

            VStack(spacing: 6) {
                Text("No items yet")
                    .font(.headline)
                Text("Tap + to add your first item.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    // MARK: - Actions

    private func addItem(name: String, price: Double, quantity: Double, unit: String?, note: String?) {
        withAnimation(.smooth) {
            let item = ItemEntity(context: context)
            item.id = UUID()
            item.name = name
            item.price = price
            item.quantity = max(quantity, 0)
            item.unit = unit?.isEmpty == true ? nil : unit
            item.note = note?.isEmpty == true ? nil : note
            item.isCompleted = false
            item.createdAt = Date()
            let maxOrder = items.map { $0.sortOrder }.max() ?? -1
            item.sortOrder = maxOrder + 1
            item.group = group
            context.saveIfNeeded()
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        withAnimation(.smooth) {
            for index in offsets { context.delete(items[index]) }
            let remaining = items.sorted { $0.sortOrder < $1.sortOrder }.enumerated()
            for (idx, item) in remaining {
                item.sortOrder = Int64(idx)
            }
            context.saveIfNeeded()
        }
    }

    private func toggleCompletion(_ item: ItemEntity) {
        withAnimation(.smooth) {
            item.isCompleted.toggle()
            context.saveIfNeeded()
        }
    }

    private func moveItems(from offsets: IndexSet, to destination: Int) {
        guard sortingMode == .manual, !showUncheckedOnly else { return }
        var current = visibleItems
        current.move(fromOffsets: offsets, toOffset: destination)
        for (index, item) in current.enumerated() {
            item.sortOrder = Int64(index)
        }
        context.saveIfNeeded()
    }

    private func saveBudget(_ value: Double?) {
        withAnimation(.smooth) {
            if let value, value > 0 {
                group.budget = value
            } else {
                group.budget = 0
            }
             context.saveIfNeeded()
        }
    }

    private func evaluateBudgetAlert() {
        guard let budget = groupBudget else { return }
        let total = totalWithTax

        let level: Int16
        if total >= budget {
            level = 2
        } else if total >= budget * 0.8 {
            level = 1
        } else {
            level = 0
        }

        if level > group.lastBudgetAlertLevel {
            switch level {
            case 1:
                notifyBudgetWarning(total: total, budget: budget, threshold: "80%")
            case 2:
                notifyBudgetExceeded(total: total, budget: budget)
            default:
                break
            }
            group.lastBudgetAlertLevel = level
            context.saveIfNeeded()
        } else if level == 0 && group.lastBudgetAlertLevel != 0 {
            group.lastBudgetAlertLevel = 0
            context.saveIfNeeded()
        }
    }

    private func notifyBudgetExceeded(total: Double, budget: Double) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Budget exceeded"
            content.body = String(format: "This list is at $%.2f, over your $%.2f budget.", total, budget)
            let request = UNNotificationRequest(identifier: UUID().uuidString,
                                                content: content,
                                                trigger: nil)
            center.add(request)
        }
    }

    private func notifyBudgetWarning(total: Double, budget: Double, threshold: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Budget nearing limit"
            content.body = String(format: "This list is at $%.2f (~%@ of $%.2f budget).", total, threshold, budget)
            let request = UNNotificationRequest(identifier: UUID().uuidString,
                                                content: content,
                                                trigger: nil)
            center.add(request)
        }
    }

    private func saveReminder(date: Date?, enabled: Bool) {
        withAnimation(.smooth) {
            group.dueDate = date
            group.reminderEnabled = enabled && date != nil
            context.saveIfNeeded()
        }

        guard enabled, let date else { cancelReminder(); return }
        scheduleReminder(for: date)
    }

    private func scheduleReminder(for date: Date) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "List due today"
            content.body = "\(group.name) is due."
            let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            let request = UNNotificationRequest(identifier: "due-\(group.id.uuidString)", content: content, trigger: trigger)
            center.add(request)
        }
    }

    private func cancelReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["due-\(group.id.uuidString)"])
    }
}

// MARK: - Summary Card

private struct SummaryCard: View {
    let itemCount: Int
    let completedCount: Int
    let progress: Double

    var body: some View {
        HStack(spacing: 16) {
            // Circular progress ring
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 5)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        progress >= 1.0
                            ? AnyShapeStyle(.green.gradient)
                            : AnyShapeStyle(.blue.gradient),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth, value: progress)

                Text("\(Int(progress * 100))%")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .contentTransition(.numericText())
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 6) {
                Text("\(completedCount) of \(itemCount) completed")
                    .font(.subheadline.weight(.medium))
                    .contentTransition(.numericText())

                Text(progress >= 1.0 ? "All done! 🎉" : "Keep going!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
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

// MARK: - Glass Item Row

private struct GlassItemRow: View {
    @ObservedObject var item: ItemEntity
    var toggle: (ItemEntity) -> Void

    var body: some View {
        Button {
            toggle(item)
        } label: {
            HStack(spacing: 12) {
                // Animated checkbox
                ZStack {
                    Circle()
                        .fill(item.isCompleted ? Color.green.opacity(0.15) : Color.clear)
                        .frame(width: 32, height: 32)

                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(item.isCompleted ? .green : .secondary)
                        .contentTransition(.symbolEffect(.replace))
                }

                // Item info
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.body)
                        .strikethrough(item.isCompleted, color: .secondary)
                        .foregroundStyle(item.isCompleted ? .secondary : .primary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text("\(item.quantity, format: .number) ×")
                        Text(item.price, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        if let unit = item.unit, !unit.isEmpty {
                            Text(unit)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if let note = item.note, !note.isEmpty {
                        Text(note)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(item.totalPrice, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(item.isCompleted ? .secondary : .primary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(item.isCompleted ? 0.6 : 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Glass Totals Footer

private struct GlassTotalsFooter: View {
    var subtotal: Double
    var taxRate: Double
    var budget: Double?
    var dueDate: Date?
    var budgetHistory: [BudgetSnapshot]

    private var taxAmount: Double { subtotal * taxRate }
    private var total: Double { subtotal + taxAmount }
    private var currencyCode: String { Locale.current.currency?.identifier ?? "USD" }

    private var statusColor: Color {
        guard let budget else { return .blue }
        if total > budget { return .red }
        if total > budget * 0.9 { return .orange }
        return .green
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Subtotal")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(subtotal, format: .currency(code: currencyCode))
                    .contentTransition(.numericText())
            }
            .font(.subheadline)

            HStack {
                Text("Tax (\(String(format: "%.1f", taxRate * 100))%)")
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(taxAmount, format: .currency(code: currencyCode))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            .font(.caption)

            Divider()
                .padding(.vertical, 2)

            HStack {
                Text("Total")
                    .font(.headline)
                Spacer()
                Text(total, format: .currency(code: currencyCode))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .contentTransition(.numericText())
                    .foregroundStyle(statusColor)
            }

            if let budget {
                HStack {
                    Text("Budget")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(budget, format: .currency(code: currencyCode))
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }

            if let dueDate {
                HStack {
                    Label("Reminder", systemImage: "bell")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(dueDate, style: .date)
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }

            if !budgetHistory.isEmpty {
                BudgetSparkline(points: budgetHistory.map { $0.total }, color: statusColor)
                    .frame(height: 34)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(statusColor.opacity(0.12))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        )
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

private struct BudgetSparkline: View {
    let points: [Double]
    let color: Color

    var normalized: [Double] {
        guard let minVal = points.min(), let maxVal = points.max(), maxVal - minVal > 0 else {
            return points.map { _ in 0.5 }
        }
        return points.map { ($0 - minVal) / (maxVal - minVal) }
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let step = max(width / CGFloat(max(points.count - 1, 1)), 1)

            Path { path in
                guard !normalized.isEmpty else { return }
                let firstY = height * (1 - CGFloat(normalized[0]))
                path.move(to: CGPoint(x: 0, y: firstY))
                for (idx, value) in normalized.enumerated() where idx > 0 {
                    let x = CGFloat(idx) * step
                    let y = height * (1 - CGFloat(value))
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(color.gradient, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .shadow(color: color.opacity(0.2), radius: 3, y: 2)
        }
    }
}

private struct ReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    @State private var enabled: Bool
    var onSave: (Date?, Bool) -> Void

    init(currentDate: Date?, isEnabled: Bool, onSave: @escaping (Date?, Bool) -> Void) {
        _date = State(initialValue: currentDate ?? Date().addingTimeInterval(3600 * 4))
        _enabled = State(initialValue: isEnabled)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Toggle("Enable reminder", isOn: $enabled)
                DatePicker("Due date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    .disabled(!enabled)
            }
            .navigationTitle("Reminder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(enabled ? date : nil, enabled)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Add Item Sheet

private struct AddItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    var onSave: (String, Double, Double, String?, String?) -> Void

    @State private var name = ""
    @State private var priceText = ""
    @State private var quantityText = "1"
    @State private var unit = ""
    @State private var note = ""
    @State private var showValidation = false

    enum Field { case name, price, quantity, note }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 18) {
                    // Product name
                    VStack(alignment: .leading, spacing: 6) {
                        Text("PRODUCT")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)

                        TextField("Product name", text: $name)
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
                            .focused($focusedField, equals: .name)
                    }

                    // Price
                    VStack(alignment: .leading, spacing: 6) {
                        Text("PRICE")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)

                        TextField("0.00", text: $priceText)
                            .keyboardType(.decimalPad)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(.ultraThinMaterial)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                            )
                            .focused($focusedField, equals: .price)
                    }

                    // Quantity & unit
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("QTY")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)
                            TextField("1", text: $quantityText)
                                .keyboardType(.decimalPad)
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                                )
                                .focused($focusedField, equals: .quantity)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("UNIT")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)
                            TextField("pcs, kg, pack…", text: $unit)
                                .textInputAutocapitalization(.never)
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                                )
                        }
                    }

                    // Note
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NOTE")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)

                        TextField("Optional note or brand", text: $note, axis: .vertical)
                            .lineLimit(1...2)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(.ultraThinMaterial)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                            )
                            .focused($focusedField, equals: .note)
                    }
                }

                if showValidation {
                    Label("Enter a valid name and price.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { validateAndSave() }
                        .font(.headline)
                }
            }
        }
        .onAppear { focusedField = .name }
    }

    private func validateAndSave() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedPrice = priceText.replacingOccurrences(of: ",", with: ".")
        let sanitizedQty = quantityText.replacingOccurrences(of: ",", with: ".")
        guard !trimmedName.isEmpty,
              let price = Double(sanitizedPrice),
              price >= 0,
              let qty = Double(sanitizedQty),
              qty >= 0
        else {
            withAnimation(.smooth) { showValidation = true }
            return
        }
        onSave(trimmedName, price, qty, unit, note)
        dismiss()
    }
}

// MARK: - Tax Rate Sheet

private struct TaxRateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var taxRate: Double
    @State private var tempRateText: String

    init(taxRate: Binding<Double>) {
        _taxRate = taxRate
        _tempRateText = State(initialValue: String(format: "%.2f", taxRate.wrappedValue * 100))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("TAX RATE (%)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)

                    TextField("13.00", text: $tempRateText)
                        .keyboardType(.decimalPad)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                        )
                }

                // Preview
                HStack {
                    Text("Preview:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let rate = Double(tempRateText.replacingOccurrences(of: ",", with: ".")), rate >= 0 {
                        Text("$100 → $\(String(format: "%.2f", 100 + rate)) incl. tax")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 4)

                Spacer()
            }
            .padding(20)
            .navigationTitle("Tax Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveRate() }
                        .font(.headline)
                }
            }
        }
    }

    private func saveRate() {
        let cleaned = tempRateText.replacingOccurrences(of: ",", with: ".")
        guard let percent = Double(cleaned), percent >= 0 else { return }
        taxRate = percent / 100
        dismiss()
    }
}

// MARK: - Budget Sheet

private struct BudgetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var tempBudgetText: String
    var onSave: (Double?) -> Void

    init(currentBudget: Double?, onSave: @escaping (Double?) -> Void) {
        _tempBudgetText = State(initialValue: {
            if let value = currentBudget { return String(format: "%.2f", value) }
            return ""
        }())
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("BUDGET")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)

                    TextField("Optional, e.g. 120.00", text: $tempBudgetText)
                        .keyboardType(.decimalPad)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                        )
                }

                if let preview = Double(tempBudgetText.replacingOccurrences(of: ",", with: ".")), preview > 0 {
                    Text("We'll warn you when the total goes past \(String(format: "$%.2f", preview)).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("Leave empty to remove the budget.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .font(.headline)
                }
            }
        }
    }

    private func save() {
        let cleaned = tempBudgetText.replacingOccurrences(of: ",", with: ".")
        if cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            onSave(nil)
        } else if let value = Double(cleaned), value >= 0 {
            onSave(value)
        }
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        GroupDetailView(group: {
            let ctx = PersistenceController.preview.viewContext
            return ctx.registeredObjects.compactMap { $0 as? GroupEntity }.first!
        }())
    }
    .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}

//
//  GroupDetailView.swift
//  SmartShop List
//
//  Created by Prabesh Shrestha on 2026-02-08.
//

import SwiftUI
import CoreData

// MARK: - Group Detail View

struct GroupDetailView: View {
    @ObservedObject var group: GroupEntity
    @Environment(\.managedObjectContext) private var context
    @FetchRequest private var items: FetchedResults<ItemEntity>

    @State private var showingAddItem = false
    @State private var showingTaxSheet = false
    @AppStorage("taxRate") private var taxRate: Double = 0.13

    init(group: GroupEntity) {
        self.group = group
        _items = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \ItemEntity.createdAt, ascending: true)],
            predicate: NSPredicate(format: "group == %@", group),
            animation: .smooth
        )
    }

    private var completedCount: Int { items.filter(\.isCompleted).count }
    private var subtotal: Double { items.reduce(0.0) { $0 + $1.price } }
    private var progress: Double {
        guard !items.isEmpty else { return 0 }
        return Double(completedCount) / Double(items.count)
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
                        ForEach(items) { item in
                            GlassItemRow(item: item, toggle: toggleCompletion)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
                        }
                        .onDelete(perform: deleteItems)
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
                Button { showingTaxSheet = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "percent")
                        Text(String(format: "%.1f", taxRate * 100))
                    }
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                    )
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddItemSheet { name, price in
                addItem(name: name, price: price)
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
        .safeAreaInset(edge: .bottom) {
            if !items.isEmpty {
                GlassTotalsFooter(subtotal: subtotal, taxRate: taxRate)
            }
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

    private func addItem(name: String, price: Double) {
        withAnimation(.smooth) {
            let item = ItemEntity(context: context)
            item.id = UUID()
            item.name = name
            item.price = price
            item.isCompleted = false
            item.createdAt = Date()
            item.group = group
            context.saveIfNeeded()
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        withAnimation(.smooth) {
            for index in offsets { context.delete(items[index]) }
            context.saveIfNeeded()
        }
    }

    private func toggleCompletion(_ item: ItemEntity) {
        withAnimation(.smooth) {
            item.isCompleted.toggle()
            context.saveIfNeeded()
        }
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
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.body)
                        .strikethrough(item.isCompleted, color: .secondary)
                        .foregroundStyle(item.isCompleted ? .secondary : .primary)
                        .lineLimit(1)

                    Text(item.price, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
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

    private var taxAmount: Double { subtotal * taxRate }
    private var total: Double { subtotal + taxAmount }
    private var currencyCode: String { Locale.current.currency?.identifier ?? "USD" }

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
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

// MARK: - Add Item Sheet

private struct AddItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    var onSave: (String, Double) -> Void

    @State private var name = ""
    @State private var priceText = ""
    @State private var showValidation = false

    enum Field { case name, price }

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
        guard !trimmedName.isEmpty,
              let price = Double(sanitizedPrice),
              price >= 0
        else {
            withAnimation(.smooth) { showValidation = true }
            return
        }
        onSave(trimmedName, price)
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

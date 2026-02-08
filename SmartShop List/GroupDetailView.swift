import SwiftUI
import CoreData

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
            animation: .default
        )
    }

    var body: some View {
        List {
            Section {
                if items.isEmpty {
                    Text("No items yet. Add your first one.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(items) { item in
                        ItemRow(item: item, toggle: toggleCompletion)
                    }
                    .onDelete(perform: deleteItems)
                }
            }
        }
        .navigationTitle(group.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddItem = true
                } label: {
                    Label("Add item", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingTaxSheet = true
                } label: {
                    Label("Tax", systemImage: "percent")
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddItemSheet(group: group) { name, price in
                addItem(name: name, price: price)
            }
        }
        .sheet(isPresented: $showingTaxSheet) {
            TaxRateSheet(taxRate: $taxRate)
        }
        .safeAreaInset(edge: .bottom) {
            TotalsFooter(subtotal: subtotal, taxRate: taxRate)
        }
    }

    private var subtotal: Double {
        items.reduce(0) { $0 + $1.price }
    }

    private func addItem(name: String, price: Double) {
        let item = ItemEntity(context: context)
        item.id = UUID()
        item.name = name
        item.price = price
        item.isCompleted = false
        item.createdAt = Date()
        item.group = group
        context.saveIfNeeded()
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            context.delete(items[index])
        }
        context.saveIfNeeded()
    }

    private func toggleCompletion(_ item: ItemEntity) {
        item.isCompleted.toggle()
        context.saveIfNeeded()
    }
}

private struct ItemRow: View {
    @ObservedObject var item: ItemEntity
    var toggle: (ItemEntity) -> Void

    var body: some View {
        Button {
            toggle(item)
        } label: {
            HStack {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isCompleted ? .green : .secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .strikethrough(item.isCompleted)
                        .foregroundColor(item.isCompleted ? .secondary : .primary)
                    Text(item.price, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }
}

private struct TotalsFooter: View {
    var subtotal: Double
    var taxRate: Double

    private var taxAmount: Double { subtotal * taxRate }
    private var total: Double { subtotal + taxAmount }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Subtotal")
                Spacer()
                Text(subtotal, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
            }
            HStack {
                Text("Tax (\(Int(taxRate * 100))%)")
                Spacer()
                Text(taxAmount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
            }
            .foregroundColor(.secondary)
            Divider()
            HStack {
                Text("Total")
                    .font(.headline)
                Spacer()
                Text(total, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .font(.headline)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

private struct AddItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    var group: GroupEntity
    var onSave: (String, Double) -> Void

    @State private var name: String = ""
    @State private var priceText: String = ""
    @State private var showValidation = false

    enum Field {
        case name, price
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Product name", text: $name)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .name)
                    TextField("Price", text: $priceText)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .price)
                }
                if showValidation {
                    Text("Enter a name and valid price.")
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("Add Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { validateAndSave() }
                }
            }
        }
        .onAppear {
            focusedField = .name
        }
    }

    private func validateAndSave() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedPrice = priceText.replacingOccurrences(of: ",", with: ".")
        guard
            !trimmedName.isEmpty,
            let price = Double(sanitizedPrice),
            price >= 0
        else {
            showValidation = true
            return
        }
        onSave(trimmedName, price)
        dismiss()
    }
}

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
            Form {
                Section("Tax rate (%)") {
                    TextField("13", text: $tempRateText)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Tax Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveRate() }
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

#Preview {
    NavigationStack {
        GroupDetailView(group: PersistenceController.preview.viewContext.registeredObjects.compactMap { $0 as? GroupEntity }.first!)
    }
    .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}

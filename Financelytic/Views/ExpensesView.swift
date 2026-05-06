import SwiftUI
import SwiftData

struct ExpensesView: View {
    @Query private var expenses: [Expense]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAdd = false
    @State private var filter: ExpenseFilter = .upcoming
    @State private var selectedCategory: ExpenseCategory? = nil

    enum ExpenseFilter: String, CaseIterable {
        case upcoming = "Upcoming"
        case overdue  = "Overdue"
        case all      = "All"
        case paid     = "Paid"
    }

    private var filteredExpenses: [Expense] {
        var result: [Expense]
        switch filter {
        case .upcoming: result = expenses.filter { $0.isDueSoon && !$0.isPaid }
        case .overdue:  result = expenses.filter { $0.isOverdue }
        case .all:      result = expenses.filter { !$0.isPaid }
        case .paid:     result = expenses.filter { $0.isPaid }
        }
        if let cat = selectedCategory { result = result.filter { $0.category == cat } }
        return result.sorted { $0.dueDate < $1.dueDate }
    }

    private var totalShown: Double { filteredExpenses.reduce(0) { $0 + $1.amount } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ExpenseFilter.allCases, id: \.self) { f in
                            chip(f.rawValue, selected: filter == f) { filter = f }
                        }
                        Rectangle().fill(.white.opacity(0.1)).frame(width: 1, height: 18)
                        chip("All", selected: selectedCategory == nil) { selectedCategory = nil }
                        ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                            chip(cat.rawValue, selected: selectedCategory == cat) {
                                selectedCategory = selectedCategory == cat ? nil : cat
                            }
                        }
                    }
                    .padding(.horizontal, 18).padding(.vertical, 12)
                }
                .background(.ultraThinMaterial)

                // Content
                if filteredExpenses.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "tray.fill")
                            .font(.system(size: 48)).foregroundStyle(.secondary)
                        Text("No Expenses").font(.title3.bold())
                        Text("No expenses match your current filter.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            // Summary header
                            HStack {
                                Text("\(filteredExpenses.count) expense\(filteredExpenses.count == 1 ? "" : "s")")
                                    .font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Text("Total: \(totalShown.currencyFormatted)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(LinearGradient.accent)
                            }
                            .padding(.horizontal, 18)
                            .padding(.top, 12)

                            ForEach(filteredExpenses) { expense in
                                NavigationLink {
                                    ExpenseDetailView(expense: expense)
                                        .premiumBackground()
                                        .preferredColorScheme(.dark)
                                } label: {
                                    ExpenseRowView(expense: expense)
                                }
                                .padding(.horizontal, 18)
                                .contextMenu {
                                    if !expense.isPaid {
                                        Button { withAnimation { expense.isPaid = true } } label: {
                                            Label("Mark as Paid", systemImage: "checkmark.circle.fill")
                                        }
                                    }
                                    Button(role: .destructive) {
                                        modelContext.delete(expense)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    if !expense.isPaid {
                                        Button { withAnimation { expense.isPaid = true } } label: {
                                            Label("Paid", systemImage: "checkmark.circle.fill")
                                        }
                                        .tint(.appGreen)
                                    }
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) { modelContext.delete(expense) } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                            Spacer().frame(height: 20)
                        }
                    }
                }
            }
            .premiumBackground()
            .navigationTitle("Expenses")
            .premiumNavBar()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: {
                        ZStack {
                            Circle().fill(.ultraThinMaterial).frame(width: 34, height: 34)
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(LinearGradient.accent)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddExpenseView()
                    .preferredColorScheme(.dark)
            }
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(selected ? AnyShapeStyle(LinearGradient.accent) : AnyShapeStyle(Color.white.opacity(0.08)))
                .foregroundStyle(selected ? .black : .primary)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(selected ? .clear : .white.opacity(0.12), lineWidth: 1))
        }
    }
}

// MARK: - Expense Row

struct ExpenseRowView: View {
    let expense: Expense

    private var statusColor: Color {
        if expense.isPaid    { return .appGreen }
        if expense.isOverdue { return Color(red: 0.9, green: 0.2, blue: 0.3) }
        if expense.isDueSoon { return .appGold }
        return .primary
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(expense.isPaid ? 0.08 : 0.14))
                    .frame(width: 42, height: 42)
                Image(systemName: expense.category.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(statusColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(expense.name).font(.subheadline.weight(.medium))
                    if expense.isRecurring {
                        Image(systemName: "repeat").font(.caption2).foregroundStyle(Color.appTeal)
                    }
                }
                HStack(spacing: 4) {
                    Text(expense.category.rawValue).font(.caption).foregroundStyle(.secondary)
                    if !expense.isPaid {
                        Text("·").foregroundStyle(.tertiary)
                        if expense.isOverdue {
                            Text("Overdue").font(.caption)
                                .foregroundStyle(Color(red: 0.9, green: 0.2, blue: 0.3))
                        } else {
                            Text(expense.dueDate, style: .date).font(.caption).foregroundStyle(.secondary)
                        }
                    } else {
                        Text("·").foregroundStyle(.tertiary)
                        Text("Paid").font(.caption).foregroundStyle(Color.appGreen)
                    }
                }
            }
            Spacer()
            Text(expense.amount.currencyFormatted)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.white.opacity(expense.isPaid ? 0.04 : 0.1), lineWidth: 1)
        )
        .opacity(expense.isPaid ? 0.55 : 1)
    }
}

// MARK: - Expense Detail

struct ExpenseDetailView: View {
    @Bindable var expense: Expense
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Hero card
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient.accent.opacity(0.15))
                            .frame(width: 72, height: 72)
                        Image(systemName: expense.category.icon)
                            .font(.system(size: 28)).foregroundStyle(LinearGradient.accent)
                    }
                    Text(expense.name).font(.title2.bold())
                    Text(expense.amount.currencyFormatted)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(LinearGradient.accent)
                    statusBadge
                }
                .frame(maxWidth: .infinity)
                .glassCard()
                .accentGlow(color: .appTeal, radius: 20)

                // Details
                VStack(spacing: 0) {
                    detailRow("Category", expense.category.rawValue)
                    Divider().background(.white.opacity(0.08))
                    detailRow("Due Date", expense.dueDate.formatted(date: .long, time: .omitted))
                    if expense.isRecurring {
                        Divider().background(.white.opacity(0.08))
                        detailRow("Recurring", expense.recurringFrequency?.rawValue ?? "Yes")
                        if let start = expense.recurringStartDate {
                            Divider().background(.white.opacity(0.08))
                            detailRow("Start", start.formatted(date: .abbreviated, time: .omitted))
                        }
                        if let end = expense.recurringEndDate {
                            Divider().background(.white.opacity(0.08))
                            detailRow("End", end.formatted(date: .abbreviated, time: .omitted))
                        }
                    }
                }
                .glassCard()

                if !expense.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes").font(.caption).foregroundStyle(.secondary)
                        Text(expense.notes).font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()
                }

                // Toggle paid
                Toggle(isOn: $expense.isPaid) {
                    Label(expense.isPaid ? "Marked as Paid" : "Mark as Paid",
                          systemImage: expense.isPaid ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(expense.isPaid ? Color.appGreen : Color.primary)
                }
                .tint(.appGreen)
                .glassCard()

                // Delete
                Button(role: .destructive) {
                    modelContext.delete(expense)
                    dismiss()
                } label: {
                    Label("Delete Expense", systemImage: "trash")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .glassCard()
            }
            .padding(.horizontal, 18).padding(.vertical, 16)
        }
        .navigationTitle("Expense")
        .navigationBarTitleDisplayMode(.inline)
        .premiumNavBar()
    }

    @ViewBuilder
    private var statusBadge: some View {
        if expense.isPaid {
            Label("Paid", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold)).foregroundStyle(Color.appGreen)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(Color.appGreen.opacity(0.15)).clipShape(Capsule())
        } else if expense.isOverdue {
            Label("Overdue", systemImage: "exclamationmark.circle.fill")
                .font(.caption.weight(.semibold)).foregroundStyle(Color(red:0.9,green:0.2,blue:0.3))
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(Color(red:0.9,green:0.2,blue:0.3).opacity(0.15)).clipShape(Capsule())
        } else if expense.isDueSoon {
            Label("Due Soon", systemImage: "clock.fill")
                .font(.caption.weight(.semibold)).foregroundStyle(Color.appGold)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(Color.appGold.opacity(0.15)).clipShape(Capsule())
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Add Expense

struct AddExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var category: ExpenseCategory = .other
    @State private var amount = ""
    @State private var dueDate = Date()
    @State private var isRecurring = false
    @State private var recurringFrequency: PaymentFrequency = .monthly
    @State private var recurringStartDate = Date()
    @State private var recurringEndDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var notes = ""

    private var isValid: Bool { !name.isEmpty && Double(amount) != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Expense Info") {
                    TextField("Expense Name", text: $name)
                    Picker("Category", selection: $category) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                        }
                    }
                    HStack {
                        Text("$").foregroundStyle(.secondary)
                        TextField("Amount", text: $amount).keyboardType(.decimalPad)
                    }
                }
                Section("Due Date") {
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                }
                Section {
                    Toggle("Recurring Transaction", isOn: $isRecurring.animation())
                } footer: {
                    Text("Enable for subscriptions, bills, and other regular payments.")
                }
                if isRecurring {
                    Section("Recurring Settings") {
                        Picker("Frequency", selection: $recurringFrequency) {
                            ForEach(PaymentFrequency.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        DatePicker("Start Date", selection: $recurringStartDate, displayedComponents: .date)
                        DatePicker("End Date", selection: $recurringEndDate,
                                   in: recurringStartDate..., displayedComponents: .date)
                    }
                }
                Section("Notes (optional)") {
                    TextField("Any additional details...", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBg)
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .premiumNavBar()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }.fontWeight(.semibold)
                        .foregroundStyle(isValid ? AnyShapeStyle(LinearGradient.accent) : AnyShapeStyle(Color.secondary))
                        .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        let expense = Expense(
            name: name, category: category,
            amount: Double(amount) ?? 0, dueDate: dueDate,
            isRecurring: isRecurring,
            recurringStartDate: isRecurring ? recurringStartDate : nil,
            recurringEndDate: isRecurring ? recurringEndDate : nil,
            recurringFrequency: isRecurring ? recurringFrequency : nil,
            notes: notes
        )
        modelContext.insert(expense)
        dismiss()
    }
}

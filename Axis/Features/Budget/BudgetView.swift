import ComposableArchitecture
import SwiftUI

struct BudgetView: View {
    @Bindable var store: StoreOf<BudgetReducer>

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Month selector
                    monthSelector

                    // Income card
                    incomeCard

                    // Summary card
                    summaryCard

                    // Bills grouped by category
                    billsList
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Budget & Bills")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(.green)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            store.send(.exportBills)
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(.green)
                        }
                        Button {
                            store.send(.showAddBillSheet)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { store.showAddBill },
                set: { if !$0 { store.send(.dismissAddBill) } }
            )) {
                addBillSheet
            }
            .onAppear {
                store.send(.onAppear)
            }
        }
    }

    // MARK: - Month Selector

    private var monthSelector: some View {
        HStack {
            Button {
                store.send(.changeMonth(-1))
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            }

            Spacer()

            Text(store.monthLabel)
                .font(.title3)
                .fontWeight(.bold)

            Spacer()

            Button {
                store.send(.changeMonth(1))
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Income Card

    private var incomeCard: some View {
        GlassCard {
            HStack(spacing: 12) {
                Image(systemName: "banknote.fill")
                    .font(.title3)
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Monthly Income")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("$0.00", value: Binding(
                        get: { store.monthlyIncome },
                        set: { store.send(.updateIncome($0)) }
                    ), format: .currency(code: "USD"))
                    .font(.title3)
                    .fontWeight(.bold)
                    .keyboardType(.decimalPad)
                }

                Spacer()
            }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        GlassCard {
            VStack(spacing: 12) {
                HStack {
                    Text("Summary")
                        .font(.headline)
                    Spacer()
                }

                HStack(spacing: 0) {
                    summaryItem(title: "Total Bills", value: store.totalBills, color: .primary)
                    summaryItem(title: "Paid", value: store.totalPaid, color: .green)
                    summaryItem(title: "Unpaid", value: store.totalUnpaid, color: .red)
                    summaryItem(title: "Remaining", value: store.remaining, color: store.remaining >= 0 ? .green : .red)
                }
            }
        }
    }

    private func summaryItem(title: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("$\(String(format: "%.0f", abs(value)))")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bills List

    private var billsList: some View {
        VStack(spacing: 12) {
            if store.bills.isEmpty {
                GlassCard {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.secondary)
                        Text("No bills for this month. Tap + to add one.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            } else {
                ForEach(store.groupedBills, id: \.category) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        // Category header
                        HStack(spacing: 6) {
                            Image(systemName: BudgetReducer.State.categoryIcon(group.category))
                                .font(.caption)
                                .foregroundStyle(categoryColor(group.category))
                            Text(group.category.capitalized)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                            let catTotal = group.bills.reduce(0.0) { $0 + $1.amount }
                            Text("$\(String(format: "%.2f", catTotal))")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 4)

                        ForEach(group.bills) { bill in
                            billRow(bill)
                        }
                    }
                }

                // Running total
                GlassCard {
                    HStack {
                        Text("Total Bills")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Spacer()
                        Text("$\(String(format: "%.2f", store.totalBills))")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
    }

    private func billRow(_ bill: BudgetReducer.State.BillState) -> some View {
        let today = Calendar.current.component(.day, from: Date())
        let currentMonth = Calendar.current.component(.month, from: Date())
        let currentYear = Calendar.current.component(.year, from: Date())
        let isCurrentMonth = store.selectedMonth == currentMonth && store.selectedYear == currentYear
        let isOverdue = isCurrentMonth && !bill.isPaid && bill.dueDay < today
        let isUpcoming = isCurrentMonth && !bill.isPaid && bill.dueDay >= today && bill.dueDay <= today + 3

        return GlassCard {
            HStack(spacing: 12) {
                // Paid toggle
                Button {
                    store.send(.togglePaid(bill.id))
                } label: {
                    Image(systemName: bill.isPaid ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(bill.isPaid ? .green : isOverdue ? .red : .secondary)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(bill.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .strikethrough(bill.isPaid)
                        .foregroundStyle(bill.isPaid ? .secondary : .primary)
                    HStack(spacing: 6) {
                        Text("Due: \(ordinal(bill.dueDay))")
                            .font(.caption)
                            .foregroundStyle(isOverdue ? .red : isUpcoming ? Color.axisGold : .secondary)
                        if isOverdue {
                            Text("OVERDUE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.red)
                                .clipShape(Capsule())
                        }
                        if isUpcoming {
                            Text("SOON")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.axisGold)
                                .clipShape(Capsule())
                        }
                    }
                }

                Spacer()

                Text("$\(String(format: "%.2f", bill.amount))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(bill.isPaid ? .green : .primary)

                Button {
                    store.send(.deleteBill(bill.id))
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func ordinal(_ day: Int) -> String {
        let suffix: String
        switch day {
        case 1, 21, 31: suffix = "st"
        case 2, 22: suffix = "nd"
        case 3, 23: suffix = "rd"
        default: suffix = "th"
        }
        return "\(day)\(suffix)"
    }

    private func categoryColor(_ category: String) -> Color {
        switch BudgetReducer.State.categoryColor(category) {
        case "blue": return .blue
        case "yellow": return .yellow
        case "orange": return .orange
        case "teal": return .teal
        case "purple": return .purple
        case "red": return .red
        case "green": return .green
        case "pink": return .pink
        case "indigo": return .indigo
        default: return .gray
        }
    }

    // MARK: - Add Bill Sheet

    private var addBillSheet: some View {
        NavigationStack {
            Form {
                Section("Bill Details") {
                    TextField("Bill name", text: $store.newBillName.sending(\.newBillNameChanged))

                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("$0.00", value: $store.newBillAmount.sending(\.newBillAmountChanged), format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    Picker("Due Day", selection: $store.newBillDueDay.sending(\.newBillDueDayChanged)) {
                        ForEach(1...31, id: \.self) { day in
                            Text("\(day)").tag(day)
                        }
                    }

                    Picker("Category", selection: $store.newBillCategory.sending(\.newBillCategoryChanged)) {
                        ForEach(BudgetReducer.State.categories, id: \.self) { cat in
                            Label(cat.capitalized, systemImage: BudgetReducer.State.categoryIcon(cat)).tag(cat)
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("New Bill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { store.send(.dismissAddBill) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { store.send(.addBill) }
                        .fontWeight(.semibold)
                        .disabled(store.newBillName.trimmingCharacters(in: .whitespaces).isEmpty || store.newBillAmount <= 0)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

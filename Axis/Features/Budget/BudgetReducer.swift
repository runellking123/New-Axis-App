import ComposableArchitecture
import Foundation
import UIKit

@Reducer
struct BudgetReducer {
    @ObservableState
    struct State: Equatable {
        var bills: [BillState] = []
        var selectedMonth: Int = Calendar.current.component(.month, from: Date())
        var selectedYear: Int = Calendar.current.component(.year, from: Date())
        var monthlyIncome: Double = 0
        var showAddBill: Bool = false
        var newBillName: String = ""
        var newBillAmount: Double = 0
        var newBillDueDay: Int = 1
        var newBillCategory: String = "other"

        struct BillState: Equatable, Identifiable {
            let id: UUID
            var name: String
            var amount: Double
            var dueDay: Int
            var category: String
            var isPaid: Bool
        }

        static let categories = [
            "housing", "utilities", "transportation", "insurance",
            "subscriptions", "debt", "food", "childcare", "phone", "other"
        ]

        static func categoryIcon(_ category: String) -> String {
            switch category {
            case "housing": return "house.fill"
            case "utilities": return "bolt.fill"
            case "transportation": return "car.fill"
            case "insurance": return "shield.fill"
            case "subscriptions": return "tv.fill"
            case "debt": return "creditcard.fill"
            case "food": return "fork.knife"
            case "childcare": return "figure.and.child.holdinghands"
            case "phone": return "iphone"
            case "other": return "ellipsis.circle.fill"
            default: return "dollarsign.circle.fill"
            }
        }

        static func categoryColor(_ category: String) -> String {
            switch category {
            case "housing": return "blue"
            case "utilities": return "yellow"
            case "transportation": return "orange"
            case "insurance": return "teal"
            case "subscriptions": return "purple"
            case "debt": return "red"
            case "food": return "green"
            case "childcare": return "pink"
            case "phone": return "indigo"
            case "other": return "gray"
            default: return "gray"
            }
        }

        var totalBills: Double {
            bills.reduce(0) { $0 + $1.amount }
        }

        var totalPaid: Double {
            bills.filter(\.isPaid).reduce(0) { $0 + $1.amount }
        }

        var totalUnpaid: Double {
            bills.filter { !$0.isPaid }.reduce(0) { $0 + $1.amount }
        }

        var remaining: Double {
            monthlyIncome - totalBills
        }

        var monthLabel: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            var components = DateComponents()
            components.month = selectedMonth
            components.year = selectedYear
            components.day = 1
            guard let date = Calendar.current.date(from: components) else { return "" }
            return formatter.string(from: date)
        }

        var groupedBills: [(category: String, bills: [BillState])] {
            let categories = Set(bills.map(\.category))
            return categories.sorted().map { cat in
                (category: cat, bills: bills.filter { $0.category == cat }.sorted { $0.dueDay < $1.dueDay })
            }
        }
    }

    enum Action: Equatable {
        case onAppear
        case loadBills
        case billsLoaded([State.BillState])
        case addBill
        case deleteBill(UUID)
        case togglePaid(UUID)
        case changeMonth(Int) // +1 or -1
        case updateIncome(Double)
        case exportBills
        case showAddBillSheet
        case dismissAddBill
        case newBillNameChanged(String)
        case newBillAmountChanged(Double)
        case newBillDueDayChanged(Int)
        case newBillCategoryChanged(String)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // Load income from UserDefaults
                state.monthlyIncome = UserDefaults.standard.double(forKey: "axis_monthly_income")
                return .send(.loadBills)

            case .loadBills:
                let month = state.selectedMonth
                let year = state.selectedYear
                let persistence = PersistenceService.shared
                let stored = persistence.fetchBills(month: month, year: year)
                let mapped = stored.map { b in
                    State.BillState(
                        id: b.uuid,
                        name: b.name,
                        amount: b.amount,
                        dueDay: b.dueDay,
                        category: b.category,
                        isPaid: b.isPaid
                    )
                }
                state.bills = mapped.sorted { $0.dueDay < $1.dueDay }
                return .none

            case let .billsLoaded(bills):
                state.bills = bills
                return .none

            case .addBill:
                let trimmed = state.newBillName.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty, state.newBillAmount > 0 else { return .none }
                let bill = BillEntry(
                    name: trimmed,
                    amount: state.newBillAmount,
                    dueDay: state.newBillDueDay,
                    category: state.newBillCategory,
                    month: state.selectedMonth,
                    year: state.selectedYear
                )
                PersistenceService.shared.saveBill(bill)
                state.bills.append(State.BillState(
                    id: bill.uuid,
                    name: bill.name,
                    amount: bill.amount,
                    dueDay: bill.dueDay,
                    category: bill.category,
                    isPaid: bill.isPaid
                ))
                state.bills.sort { $0.dueDay < $1.dueDay }
                state.showAddBill = false
                state.newBillName = ""
                state.newBillAmount = 0
                state.newBillDueDay = 1
                state.newBillCategory = "other"
                HapticService.notification(.success)
                return .none

            case let .deleteBill(id):
                state.bills.removeAll { $0.id == id }
                PersistenceService.shared.deleteBill(id)
                return .none

            case let .togglePaid(id):
                if let index = state.bills.firstIndex(where: { $0.id == id }) {
                    state.bills[index].isPaid.toggle()
                    let persistence = PersistenceService.shared
                    let stored = persistence.fetchBills(month: state.selectedMonth, year: state.selectedYear)
                    if let match = stored.first(where: { $0.uuid == id }) {
                        match.isPaid = state.bills[index].isPaid
                        persistence.updateBills()
                    }
                    HapticService.impact(.light)
                }
                return .none

            case let .changeMonth(delta):
                var month = state.selectedMonth + delta
                var year = state.selectedYear
                if month > 12 { month = 1; year += 1 }
                if month < 1 { month = 12; year -= 1 }
                state.selectedMonth = month
                state.selectedYear = year
                return .send(.loadBills)

            case let .updateIncome(income):
                state.monthlyIncome = income
                UserDefaults.standard.set(income, forKey: "axis_monthly_income")
                return .none

            case .exportBills:
                var csv = "AXIS Budget & Bills Report\n"
                csv += "\(state.monthLabel)\n\n"
                csv += "Category,Name,Due Day,Amount,Status\n"
                for bill in state.bills.sorted(by: { $0.dueDay < $1.dueDay }) {
                    csv += "\(bill.category.capitalized),\(bill.name),\(bill.dueDay),$\(String(format: "%.2f", bill.amount)),\(bill.isPaid ? "Paid" : "Unpaid")\n"
                }
                csv += "\nIncome,$\(String(format: "%.2f", state.monthlyIncome))\n"
                csv += "Total Bills,$\(String(format: "%.2f", state.totalBills))\n"
                csv += "Remaining,$\(String(format: "%.2f", state.remaining))\n"

                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Budget_\(state.monthLabel.replacingOccurrences(of: " ", with: "_")).csv")
                try? csv.write(to: tempURL, atomically: true, encoding: .utf8)
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let vc = scene.windows.first?.rootViewController {
                    var top = vc
                    while let p = top.presentedViewController { top = p }
                    top.present(UIActivityViewController(activityItems: [tempURL], applicationActivities: nil), animated: true)
                }
                return .none

            case .showAddBillSheet:
                state.showAddBill = true
                state.newBillName = ""
                state.newBillAmount = 0
                state.newBillDueDay = 1
                state.newBillCategory = "other"
                return .none

            case .dismissAddBill:
                state.showAddBill = false
                return .none

            case let .newBillNameChanged(name):
                state.newBillName = name
                return .none

            case let .newBillAmountChanged(amount):
                state.newBillAmount = amount
                return .none

            case let .newBillDueDayChanged(day):
                state.newBillDueDay = day
                return .none

            case let .newBillCategoryChanged(cat):
                state.newBillCategory = cat
                return .none
            }
        }
    }
}

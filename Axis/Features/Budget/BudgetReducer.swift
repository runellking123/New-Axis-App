import ComposableArchitecture
import Foundation
import Vision

#if os(iOS)
import UIKit
#endif

@Reducer
struct BudgetReducer {
    @ObservableState
    struct State: Equatable {
        var bills: [BillState] = []
        var selectedMonth: Int = Calendar.current.component(.month, from: Date())
        var selectedYear: Int = Calendar.current.component(.year, from: Date())
        var monthlyIncome: Double = 0
        var showAddBill: Bool = false
        var showScanBill: Bool = false
        var isScanning: Bool = false
        var scanResult: String = ""
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
        // Bill scanning
        case showScanBillSheet
        case dismissScanBill
        case scanImage(Data)
        case scanCompleted(name: String, amount: Double, dueDay: Int, category: String)
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
                PlatformServices.share(items: [tempURL])
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

            case .showScanBillSheet:
                state.showScanBill = true
                state.isScanning = false
                state.scanResult = ""
                return .none

            case .dismissScanBill:
                state.showScanBill = false
                return .none

            case let .scanImage(imageData):
                state.isScanning = true
                return .run { send in
                    let result = await Self.performOCR(imageData: imageData)
                    await send(.scanCompleted(
                        name: result.name,
                        amount: result.amount,
                        dueDay: result.dueDay,
                        category: result.category
                    ))
                }

            case let .scanCompleted(name, amount, dueDay, category):
                state.isScanning = false
                state.showScanBill = false
                // Pre-fill the add bill form
                state.newBillName = name
                state.newBillAmount = amount
                state.newBillDueDay = dueDay
                state.newBillCategory = category
                state.showAddBill = true
                return .none
            }
        }
    }

    // MARK: - OCR Bill Scanning

    private static func performOCR(imageData: Data) async -> (name: String, amount: Double, dueDay: Int, category: String) {
        #if os(iOS)
        guard let image = UIImage(data: imageData),
              let cgImage = image.cgImage else {
            return ("", 0, 1, "other")
        }

        let text = await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage)
            try? handler.perform([request])
        }

        return parseBillText(text)
        #else
        return ("", 0, 1, "other")
        #endif
    }

    private static func parseBillText(_ text: String) -> (name: String, amount: Double, dueDay: Int, category: String) {
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        var name = ""
        var amount: Double = 0
        var dueDay = 1
        var category = "other"

        // Find the largest dollar amount (likely the total/amount due)
        let amountPattern = try? NSRegularExpression(pattern: "\\$([0-9,]+\\.?\\d{0,2})")
        var amounts: [(Double, String)] = []
        for line in lines {
            let nsLine = line as NSString
            let matches = amountPattern?.matches(in: line, range: NSRange(location: 0, length: nsLine.length)) ?? []
            for match in matches {
                let numStr = nsLine.substring(with: match.range(at: 1)).replacingOccurrences(of: ",", with: "")
                if let val = Double(numStr), val > 0 {
                    amounts.append((val, line))
                }
            }
        }

        // Use keywords to find the "amount due" or "total" line, otherwise largest amount
        let amountKeywords = ["amount due", "total due", "total amount", "balance due", "pay this amount", "minimum due", "current charges", "total"]
        for keyword in amountKeywords {
            for (val, line) in amounts {
                if line.lowercased().contains(keyword) {
                    amount = val
                    break
                }
            }
            if amount > 0 { break }
        }
        if amount == 0, let largest = amounts.max(by: { $0.0 < $1.0 }) {
            amount = largest.0
        }

        // Find due date
        let datePatterns = [
            "due\\s*(?:date)?\\s*:?\\s*(\\d{1,2})[/\\-](\\d{1,2})",
            "(\\d{1,2})[/\\-](\\d{1,2})[/\\-](\\d{2,4})",
        ]
        for pattern in datePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                for line in lines {
                    let nsLine = line as NSString
                    if let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) {
                        let dayStr = nsLine.substring(with: match.range(at: match.numberOfRanges > 2 ? 2 : 1))
                        if let day = Int(dayStr), day >= 1, day <= 31 {
                            dueDay = day
                            break
                        }
                    }
                }
            }
            if dueDay > 1 { break }
        }

        // Extract company/bill name from first few lines
        let nameKeywords = ["statement", "bill", "invoice", "account"]
        for line in lines.prefix(10) {
            let lower = line.lowercased()
            if lower.contains("$") || lower.count < 3 { continue }
            for keyword in nameKeywords {
                if lower.contains(keyword) {
                    name = line.replacingOccurrences(of: "(?i)statement|bill|invoice|account|summary|for", with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                }
            }
            if !name.isEmpty { break }
        }
        if name.isEmpty {
            // Use first substantial line as name
            for line in lines.prefix(5) {
                if line.count > 3 && !line.contains("$") && !line.lowercased().contains("page") {
                    name = String(line.prefix(40))
                    break
                }
            }
        }

        // Guess category
        let lower = text.lowercased()
        if lower.contains("electric") || lower.contains("gas") || lower.contains("water") || lower.contains("sewer") || lower.contains("utility") {
            category = "utilities"
        } else if lower.contains("mortgage") || lower.contains("rent") || lower.contains("lease") || lower.contains("hoa") {
            category = "housing"
        } else if lower.contains("insurance") || lower.contains("geico") || lower.contains("state farm") || lower.contains("allstate") {
            category = "insurance"
        } else if lower.contains("t-mobile") || lower.contains("verizon") || lower.contains("at&t") || lower.contains("sprint") || lower.contains("phone") || lower.contains("wireless") {
            category = "phone"
        } else if lower.contains("netflix") || lower.contains("hulu") || lower.contains("spotify") || lower.contains("disney") || lower.contains("subscription") {
            category = "subscriptions"
        } else if lower.contains("car") || lower.contains("auto") || lower.contains("toyota") || lower.contains("honda") || lower.contains("ford") {
            category = "transportation"
        } else if lower.contains("visa") || lower.contains("mastercard") || lower.contains("credit") || lower.contains("loan") || lower.contains("payment") {
            category = "debt"
        } else if lower.contains("daycare") || lower.contains("childcare") || lower.contains("tuition") {
            category = "childcare"
        }

        return (name, amount, dueDay, category)
    }
}

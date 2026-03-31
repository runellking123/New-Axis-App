import ComposableArchitecture
import SwiftUI

struct EAPlannerView: View {
    @Bindable var store: StoreOf<EAPlannerReducer>

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segment picker
                Picker("View", selection: $store.selectedView.sending(\.switchView)) {
                    ForEach(EAPlannerReducer.State.PlanView.allCases, id: \.self) { view in
                        Text(view.rawValue).tag(view)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                // Stale plan warning
                if store.isPlanStale {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Plan may be outdated")
                            .font(.caption)
                        Spacer()
                        Button("Refresh") { store.send(.replan) }
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.axisGold)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.orange.opacity(0.1))
                }

                switch store.selectedView {
                case .day:
                    dayView
                case .week:
                    weekView
                }
            }
            .background(Color(.systemGroupedBackground))
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Planner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { store.send(.showAddBlockSheet) } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.axisGold)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { store.send(.replan) } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(Color.axisGold)
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { store.showAddBlock },
                set: { _ in store.send(.dismissAddBlockSheet) }
            )) {
                addBlockSheet
            }
            .onAppear { store.send(.onAppear) }
        }
    }

    // MARK: - Day View

    private var dayView: some View {
        ScrollView {
            VStack(spacing: 0) {
                if store.isGenerating {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading your schedule...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else if let plan = store.dailyPlan {
                    // Date header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedDateString())
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text(plan.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Text("\(plan.timeBlocks.count) blocks")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.axisGold.opacity(0.15))
                            .foregroundStyle(Color.axisGold)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                    if plan.timeBlocks.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "calendar.badge.checkmark")
                                .font(.system(size: 40))
                                .foregroundStyle(.green)
                            Text("Nothing scheduled today")
                                .font(.headline)
                            Text("Enjoy your free time or add tasks to plan your day.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        // Timeline
                        VStack(spacing: 0) {
                            ForEach(Array(plan.timeBlocks.enumerated()), id: \.element.id) { index, block in
                                // Gap indicator between blocks
                                if index > 0 {
                                    let prevEnd = plan.timeBlocks[index - 1].endTime
                                    let gap = block.startTime.timeIntervalSince(prevEnd)
                                    if gap > 10 * 60 { // Show gap if > 10 min
                                        HStack(spacing: 8) {
                                            Rectangle()
                                                .fill(Color(.systemGray4))
                                                .frame(height: 1)
                                            Text("\(Int(gap / 60)) min free")
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                                .fixedSize()
                                            Rectangle()
                                                .fill(Color(.systemGray4))
                                                .frame(height: 1)
                                        }
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 4)
                                    }
                                }

                                timeBlockRow(block)
                                    .contextMenu {
                                        Button {
                                            store.send(.showAddBlockSheet)
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }

                                        Button {
                                            store.send(.convertBlockToTask(block.id))
                                        } label: {
                                            Label("Convert to Task", systemImage: "checklist")
                                        }

                                        Button {
                                            openMessagesWithBlockDetails(block)
                                        } label: {
                                            Label("Text Details", systemImage: "message")
                                        }

                                        Button {
                                            copyBlockDetails(block)
                                        } label: {
                                            Label("Copy Details", systemImage: "doc.on.doc")
                                        }

                                        Divider()

                                        Button(role: .destructive) {
                                            store.send(.deleteBlock(block.id))
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            store.send(.deleteBlock(block.id))
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        .tint(.red)
                                    }
                            }
                        }
                        .padding(.top, 4)
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No schedule loaded")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Load Schedule") { store.send(.generatePlan) }
                            .buttonStyle(.bordered)
                            .tint(Color.axisGold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                }
            }
            .padding(.bottom, 100)
        }
    }

    private func timeBlockRow(_ block: EAPlannerReducer.State.TimeBlockState) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // Time column
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatTime(block.startTime))
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)
                Text(formatTime(block.endTime))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 60, alignment: .trailing)
            .padding(.trailing, 8)

            // Color bar
            RoundedRectangle(cornerRadius: 3)
                .fill(blockColor(block.blockType))
                .frame(width: 4)
                .padding(.vertical, 2)

            // Content card
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: blockIcon(block.blockType))
                        .font(.caption)
                        .foregroundStyle(blockColor(block.blockType))
                    Text(block.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                }

                HStack(spacing: 12) {
                    Label("\(block.durationMinutes)m", systemImage: "clock")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(blockTypeLabel(block.blockType))
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(blockColor(block.blockType).opacity(0.12))
                        .foregroundStyle(blockColor(block.blockType))
                        .clipShape(Capsule())
                }

                if let location = block.location, !location.isEmpty {
                    Label(location, systemImage: "mappin")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let reasoning = block.aiReasoning, !reasoning.isEmpty {
                    Text(reasoning)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .italic()
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(blockColor(block.blockType).opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.leading, 8)
        }
        .padding(.horizontal)
        .padding(.vertical, 3)
    }

    // MARK: - Week View

    private var weekView: some View {
        ScrollView {
            VStack(spacing: 8) {
                if store.weekDaySummaries.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading week overview...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                }

                ForEach(store.weekDaySummaries) { day in
                    Button { store.send(.selectDate(day.date)) } label: {
                        HStack(spacing: 12) {
                            // Date column
                            VStack(spacing: 2) {
                                Text(dayAbbrev(day.date))
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Calendar.current.isDateInToday(day.date) ? Color.axisGold : .secondary)
                                Text(dayNumber(day.date))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Calendar.current.isDateInToday(day.date) ? Color.axisGold : .primary)
                            }
                            .frame(width: 44)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(dayFullLabel(day.date))
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                HStack(spacing: 12) {
                                    if day.eventCount > 0 {
                                        Label("\(day.eventCount) event\(day.eventCount == 1 ? "" : "s")", systemImage: "calendar")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    if day.taskCount > 0 {
                                        Label("\(day.taskCount) reminder\(day.taskCount == 1 ? "" : "s")", systemImage: "bell")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    if day.totalMinutes > 0 {
                                        Label(formatDuration(day.totalMinutes), systemImage: "clock")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            Spacer()

                            // Busy indicator
                            let density = min(Double(day.totalMinutes) / 480.0, 1.0)
                            Circle()
                                .fill(density > 0.7 ? .red : density > 0.4 ? .orange : density > 0 ? .green : Color(.systemGray4))
                                .frame(width: 10, height: 10)

                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal)
                        .background(
                            Calendar.current.isDateInToday(day.date)
                            ? Color.axisGold.opacity(0.08)
                            : Color(.secondarySystemGroupedBackground)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 100)
        }
    }

    private var addBlockSheet: some View {
        NavigationStack {
            Form {
                Section("Block") {
                    TextField("Title", text: $store.newBlockTitle.sending(\.newBlockTitleChanged))
                    Picker("Type", selection: $store.newBlockType.sending(\.newBlockTypeChanged)) {
                        Text("Task").tag("task")
                        Text("Meeting").tag("meeting")
                        Text("Focus").tag("focusBlock")
                        Text("Break").tag("break")
                        Text("Reminder").tag("reminder")
                    }
                }
                Section("Time") {
                    DatePicker("Start", selection: $store.newBlockStart.sending(\.newBlockStartChanged), displayedComponents: [.date, .hourAndMinute])
                    DatePicker("End", selection: $store.newBlockEnd.sending(\.newBlockEndChanged), displayedComponents: [.date, .hourAndMinute])
                }
            }
            .navigationTitle("Add to Planner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { store.send(.dismissAddBlockSheet) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { store.send(.confirmAddBlock) }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.axisGold)
                        .disabled(store.newBlockTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Block Actions

    private func blockDetailsText(_ block: EAPlannerReducer.State.TimeBlockState) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMMM d"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"

        let dateLine = "\(dateFormatter.string(from: block.startTime)) at \(timeFormatter.string(from: block.startTime)) - \(timeFormatter.string(from: block.endTime))"
        let typeLine = "Type: \(blockTypeLabel(block.blockType))"

        return "\(block.title)\n\(dateLine)\n\(typeLine)"
    }

    private func copyBlockDetails(_ block: EAPlannerReducer.State.TimeBlockState) {
        PlatformServices.copyToClipboard(blockDetailsText(block))
    }

    private func openMessagesWithBlockDetails(_ block: EAPlannerReducer.State.TimeBlockState) {
        let body = blockDetailsText(block)
        guard let encoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "sms:&body=\(encoded)") else { return }
        PlatformServices.openURL(url)
    }

    // MARK: - Helpers

    private func blockColor(_ type: String) -> Color {
        switch type {
        case "meeting": return .purple
        case "focusBlock": return .blue
        case "break": return .green
        case "task": return Color.axisGold
        case "reminder": return .orange
        default: return .gray
        }
    }

    private func blockIcon(_ type: String) -> String {
        switch type {
        case "meeting": return "video.fill"
        case "focusBlock": return "brain.head.profile"
        case "break": return "cup.and.saucer.fill"
        case "task": return "checklist"
        case "reminder": return "bell.fill"
        default: return "circle"
        }
    }

    private func blockTypeLabel(_ type: String) -> String {
        switch type {
        case "meeting": return "Event"
        case "focusBlock": return "Focus"
        case "break": return "Break"
        case "task": return "Task"
        case "reminder": return "Reminder"
        default: return type.capitalized
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func selectedDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: store.selectedDate)
    }

    private func dayAbbrev(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }

    private func dayNumber(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private func dayFullLabel(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInTomorrow(date) { return "Tomorrow" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hrs = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hrs)h \(mins)m" : "\(hrs)h"
        }
        return "\(minutes)m"
    }
}

#Preview {
    EAPlannerView(
        store: Store(initialState: EAPlannerReducer.State()) {
            EAPlannerReducer()
        }
    )
}

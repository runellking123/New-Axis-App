import ComposableArchitecture
import EventKit
import SwiftUI

struct EAPlannerView: View {
    @Bindable var store: StoreOf<EAPlannerReducer>
    @State private var selectedPlannerBlock: EAPlannerReducer.State.TimeBlockState?

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
            .sheet(item: $selectedPlannerBlock) { block in
                PlannerBlockDetailSheet(block: block)
                    .presentationDetents([.medium, .large])
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

                                Button {
                                    selectedPlannerBlock = block
                                } label: {
                                    timeBlockRow(block)
                                }
                                .buttonStyle(.plain)
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

// MARK: - Planner Block Detail Sheet
// Shown when the user taps a row in the Planner. For blocks linked to a real
// calendar event (eventId present), we look up the EKEvent so we can surface
// notes, full location, and a one-tap Join button for video meetings.

struct PlannerBlockDetailSheet: View {
    let block: EAPlannerReducer.State.TimeBlockState
    @Environment(\.dismiss) private var dismiss
    @State private var notes: String?
    @State private var fullLocation: String?
    @State private var calendarURL: URL?
    @State private var meeting: PlannerMeetingLink?
    @State private var organizerName: String?
    @State private var organizerEmail: String?
    @State private var attendees: [(name: String, email: String, status: String)] = []
    @State private var calendarSource: String?
    @State private var calendarTitle: String?
    @State private var availability: String?
    @State private var recurrenceSummary: String?
    @State private var alarmCount: Int = 0
    @State private var detectedURLs: [URL] = []
    @State private var lookupAttempted = false

    private var blockLabel: String {
        switch block.blockType {
        case "meeting": return "Event"
        case "focusBlock": return "Focus Block"
        case "break": return "Break"
        case "task": return "Task"
        case "reminder": return "Reminder"
        default: return "Block"
        }
    }

    private var blockIcon: String {
        switch block.blockType {
        case "meeting": return "person.2.fill"
        case "focusBlock": return "target"
        case "break": return "cup.and.saucer.fill"
        case "task": return "checkmark.circle.fill"
        case "reminder": return "bell.fill"
        default: return "clock"
        }
    }

    private var blockTint: Color {
        switch block.blockType {
        case "meeting": return .purple
        case "focusBlock": return .blue
        case "break": return .green
        case "task": return Color.axisAccent
        case "reminder": return .orange
        default: return .gray
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AxisSpacing.xl) {
                    VStack(alignment: .leading, spacing: AxisSpacing.sm) {
                        HStack(spacing: AxisSpacing.sm) {
                            Image(systemName: blockIcon).foregroundStyle(blockTint)
                            Text(blockLabel)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(blockTint)
                                .textCase(.uppercase)
                                .tracking(0.5)
                        }
                        Text(block.title)
                            .font(.system(.title2, design: .serif).weight(.bold))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Time + duration card
                    VStack(alignment: .leading, spacing: AxisSpacing.sm) {
                        HStack {
                            Image(systemName: "clock").foregroundStyle(.secondary)
                            Text("\(formattedTime(block.startTime)) – \(formattedTime(block.endTime))")
                                .font(.body.weight(.medium))
                            Spacer()
                            Text("\(block.durationMinutes) min").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Text(formattedDate(block.startTime))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(AxisSpacing.lg)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: AxisRadius.card, style: .continuous))

                    // Join button (when a video meeting link is found)
                    if let meeting {
                        Button {
                            PlatformServices.openURL(meeting.url)
                        } label: {
                            HStack {
                                Image(systemName: meeting.icon)
                                Text("Join \(meeting.service)")
                            }
                        }
                        .buttonStyle(.axisPrimary)
                    }

                    // Location
                    if let loc = fullLocation ?? block.location, !loc.isEmpty {
                        VStack(alignment: .leading, spacing: AxisSpacing.xs) {
                            Label("Location", systemImage: "mappin.and.ellipse")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(loc)
                                .font(.body)
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AxisSpacing.lg)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: AxisRadius.card, style: .continuous))
                    }

                    // Calendar source (which Outlook / iCloud / Google account)
                    if let calendarTitle {
                        HStack(spacing: AxisSpacing.sm) {
                            Image(systemName: "calendar")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(calendarTitle)
                                    .font(.subheadline.weight(.medium))
                                if let calendarSource, calendarSource != calendarTitle {
                                    Text(calendarSource)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if let availability, !availability.isEmpty {
                                Text(availability)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, AxisSpacing.sm)
                                    .padding(.vertical, AxisSpacing.xxs)
                                    .background(Capsule().fill(Color.secondary.opacity(0.15)))
                            }
                        }
                        .padding(AxisSpacing.lg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: AxisRadius.card, style: .continuous))
                    }

                    // Organizer
                    if let organizerName {
                        VStack(alignment: .leading, spacing: AxisSpacing.xs) {
                            Label("Organizer", systemImage: "person.crop.circle.badge.checkmark")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            HStack {
                                Text(organizerName).font(.body.weight(.medium))
                                Spacer()
                                if let email = organizerEmail {
                                    Button {
                                        if let url = URL(string: "mailto:\(email)") { PlatformServices.openURL(url) }
                                    } label: {
                                        Image(systemName: "envelope.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            if let email = organizerEmail {
                                Text(email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AxisSpacing.lg)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: AxisRadius.card, style: .continuous))
                    }

                    // Attendees
                    if !attendees.isEmpty {
                        VStack(alignment: .leading, spacing: AxisSpacing.sm) {
                            Label("Attendees (\(attendees.count))", systemImage: "person.2.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ForEach(Array(attendees.enumerated()), id: \.offset) { _, person in
                                HStack {
                                    Image(systemName: statusIcon(person.status))
                                        .foregroundStyle(statusColor(person.status))
                                        .frame(width: 18)
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(person.name).font(.subheadline)
                                        if !person.email.isEmpty {
                                            Text(person.email)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if !person.email.isEmpty {
                                        Button {
                                            if let url = URL(string: "mailto:\(person.email)") { PlatformServices.openURL(url) }
                                        } label: {
                                            Image(systemName: "envelope")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AxisSpacing.lg)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: AxisRadius.card, style: .continuous))
                    }

                    // Recurrence
                    if let recurrenceSummary {
                        HStack(spacing: AxisSpacing.sm) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundStyle(.secondary)
                            Text(recurrenceSummary)
                                .font(.subheadline)
                            Spacer()
                        }
                        .padding(AxisSpacing.lg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: AxisRadius.card, style: .continuous))
                    }

                    // Notes / description
                    if let notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: AxisSpacing.xs) {
                            Label("Notes", systemImage: "text.alignleft")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(notes)
                                .font(.body)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AxisSpacing.lg)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: AxisRadius.card, style: .continuous))
                    }

                    // Other links found in the event (non-meeting)
                    let otherLinks = detectedURLs.filter { meeting == nil || $0 != meeting?.url }
                    if !otherLinks.isEmpty {
                        VStack(alignment: .leading, spacing: AxisSpacing.xs) {
                            Label("Links", systemImage: "link")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ForEach(Array(otherLinks.prefix(8).enumerated()), id: \.offset) { _, url in
                                Button {
                                    PlatformServices.openURL(url)
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.up.right.square")
                                            .font(.caption)
                                        Text(url.absoluteString)
                                            .font(.caption)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                            .foregroundStyle(Color.axisInfo)
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AxisSpacing.lg)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: AxisRadius.card, style: .continuous))
                    }

                    // External event URL fallback (non-meeting top-level url)
                    if let calendarURL, meeting == nil, !detectedURLs.contains(calendarURL) {
                        Button {
                            PlatformServices.openURL(calendarURL)
                        } label: {
                            HStack {
                                Image(systemName: "link")
                                Text("Open Event Link")
                            }
                        }
                        .buttonStyle(.axisSecondary)
                    }

                    // Alarms / reminders set on the event
                    if alarmCount > 0 {
                        HStack(spacing: AxisSpacing.sm) {
                            Image(systemName: "bell.fill").foregroundStyle(.secondary)
                            Text("\(alarmCount) reminder\(alarmCount == 1 ? "" : "s") set")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, AxisSpacing.lg)
                    }

                    // AI reasoning (for AI-generated blocks)
                    if let reasoning = block.aiReasoning, !reasoning.isEmpty {
                        VStack(alignment: .leading, spacing: AxisSpacing.xs) {
                            Label("Why this block", systemImage: "sparkles")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(reasoning)
                                .font(.subheadline)
                                .italic()
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AxisSpacing.lg)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: AxisRadius.card, style: .continuous))
                    }

                    Spacer(minLength: 0)
                }
                .padding(AxisSpacing.lg)
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadCalendarDetails()
            }
        }
    }

    private func formattedTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .full
        f.timeStyle = .none
        return f.string(from: date)
    }

    private func loadCalendarDetails() async {
        guard let eventId = block.eventId, !lookupAttempted else { return }
        lookupAttempted = true
        let store = EKEventStore()
        // Try calendarItem first (works for both events and reminders, and is
        // what we now persist). Fall back to event(withIdentifier:) for blocks
        // that were saved before the identifier switch.
        let ek: EKEvent? = (store.calendarItem(withIdentifier: eventId) as? EKEvent)
            ?? store.event(withIdentifier: eventId)
        guard let ek else { return }

        // Build URL list from notes/location/url combined
        let haystack = [ek.notes ?? "", ek.location ?? "", ek.url?.absoluteString ?? ""]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        var urls: [URL] = []
        if !haystack.isEmpty,
           let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let range = NSRange(haystack.startIndex..<haystack.endIndex, in: haystack)
            urls = detector.matches(in: haystack, options: [], range: range).compactMap { $0.url }
        }
        if let u = ek.url, !urls.contains(u) { urls.insert(u, at: 0) }

        // Organizer
        var orgName: String?
        var orgEmail: String?
        if let org = ek.organizer {
            orgName = org.name ?? org.url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
            if org.url.scheme == "mailto" { orgEmail = org.url.absoluteString.replacingOccurrences(of: "mailto:", with: "") }
        }

        // Attendees
        var people: [(name: String, email: String, status: String)] = []
        for participant in ek.attendees ?? [] {
            let name = participant.name ?? participant.url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
            let email = participant.url.scheme == "mailto"
                ? participant.url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
                : ""
            let status: String
            switch participant.participantStatus {
            case .accepted: status = "accepted"
            case .declined: status = "declined"
            case .tentative: status = "tentative"
            case .pending: status = "pending"
            default: status = "unknown"
            }
            people.append((name: name, email: email, status: status))
        }

        // Availability
        let avail: String? = {
            switch ek.availability {
            case .busy: return "Busy"
            case .free: return "Free"
            case .tentative: return "Tentative"
            case .unavailable: return "Out of Office"
            default: return nil
            }
        }()

        // Recurrence summary (best-effort, single rule)
        var recurrence: String?
        if let rule = ek.recurrenceRules?.first {
            let freq: String
            switch rule.frequency {
            case .daily: freq = "Daily"
            case .weekly: freq = "Weekly"
            case .monthly: freq = "Monthly"
            case .yearly: freq = "Yearly"
            @unknown default: freq = "Recurring"
            }
            var summary = freq
            if rule.interval > 1 { summary += " (every \(rule.interval))" }
            if let endDate = rule.recurrenceEnd?.endDate {
                let f = DateFormatter(); f.dateStyle = .medium
                summary += " until \(f.string(from: endDate))"
            } else if let count = rule.recurrenceEnd?.occurrenceCount, count > 0 {
                summary += " (\(count) occurrences)"
            }
            recurrence = summary
        }

        await MainActor.run {
            self.notes = ek.notes
            self.fullLocation = ek.location
            self.calendarURL = ek.url
            self.meeting = PlannerMeetingLink.detect(notes: ek.notes, location: ek.location, url: ek.url)
            self.organizerName = orgName
            self.organizerEmail = orgEmail
            self.attendees = people
            self.calendarTitle = ek.calendar?.title
            self.calendarSource = ek.calendar?.source.title
            self.availability = avail
            self.recurrenceSummary = recurrence
            self.alarmCount = ek.alarms?.count ?? 0
            self.detectedURLs = urls
        }
    }

    private func statusIcon(_ status: String) -> String {
        switch status {
        case "accepted": return "checkmark.circle.fill"
        case "declined": return "xmark.circle.fill"
        case "tentative": return "questionmark.circle.fill"
        case "pending": return "clock.fill"
        default: return "person.crop.circle"
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "accepted": return .green
        case "declined": return .red
        case "tentative": return .orange
        case "pending": return .gray
        default: return .secondary
        }
    }
}

// Same meeting-link detection used in the Calendar tab — duplicated here to
// keep the Planner module self-contained. If a third caller appears, hoist
// this into Shared/.
struct PlannerMeetingLink {
    let url: URL
    let service: String
    let icon: String
    let tint: Color

    static func detect(notes: String?, location: String?, url: URL?) -> PlannerMeetingLink? {
        let haystack = [notes ?? "", location ?? "", url?.absoluteString ?? ""]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        guard !haystack.isEmpty else { return nil }

        let patterns: [(service: String, icon: String, tint: Color, host: [String], scheme: [String])] = [
            ("Zoom", "video.fill", .blue, ["zoom.us", "zoomgov.com"], ["zoommtg"]),
            ("Teams", "person.2.fill", .indigo, ["teams.microsoft.com", "teams.live.com"], ["msteams"]),
            ("Google Meet", "video.badge.waveform", .green, ["meet.google.com"], []),
            ("Webex", "video.circle.fill", .teal, ["webex.com"], []),
            ("GoToMeeting", "video.fill", .orange, ["gotomeeting.com", "gotomeet.me"], []),
            ("BlueJeans", "video.fill", .cyan, ["bluejeans.com"], []),
            ("Whereby", "video.fill", .pink, ["whereby.com"], []),
            ("Skype", "phone.bubble.fill", .blue, ["skype.com"], ["skype"]),
            ("Chime", "video.fill", .orange, ["chime.aws"], []),
        ]

        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(haystack.startIndex..<haystack.endIndex, in: haystack)
        let matches = detector?.matches(in: haystack, options: [], range: range) ?? []
        for match in matches {
            guard let url = match.url else { continue }
            let host = (url.host ?? "").lowercased()
            let scheme = (url.scheme ?? "").lowercased()
            for pattern in patterns {
                if pattern.host.contains(where: { host.contains($0) }) || pattern.scheme.contains(scheme) {
                    return PlannerMeetingLink(url: url, service: pattern.service, icon: pattern.icon, tint: pattern.tint)
                }
            }
        }

        let lowered = haystack.lowercased()
        if let range = lowered.range(of: #"(https?://[\w.\-]*(zoom\.us|zoomgov\.com|teams\.(microsoft|live)\.com|meet\.google\.com|webex\.com|gotomeeting\.com|gotomeet\.me|bluejeans\.com|whereby\.com|chime\.aws)[^\s<>"']*)"#, options: .regularExpression) {
            let raw = String(haystack[range])
            if let url = URL(string: raw) {
                let host = (url.host ?? "").lowercased()
                for pattern in patterns {
                    if pattern.host.contains(where: { host.contains($0) }) {
                        return PlannerMeetingLink(url: url, service: pattern.service, icon: pattern.icon, tint: pattern.tint)
                    }
                }
            }
        }
        return nil
    }
}

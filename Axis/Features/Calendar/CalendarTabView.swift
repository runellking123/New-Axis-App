import ComposableArchitecture
import EventKit
import SwiftUI

struct CalendarTabView: View {
    @State private var events: [CalEventItem] = []
    @State private var selectedDate = Date()
    @State private var calendarGranted = false
    @State private var showCreateEvent = false
    @State private var connectedSources: [CalSourceInfo] = []
    @State private var showConnectSheet = false

    // New event form
    @State private var newTitle = ""
    @State private var newStart = Date()
    @State private var newEnd = Date().addingTimeInterval(3600)
    @State private var newLocation = ""
    @State private var newNotes = ""

    // AI features
    @State private var nlEventText = ""
    @State private var isParsingNL = false
    @State private var showNLCreate = false
    @State private var freeSlots: [String] = []
    @State private var isSearchingSlots = false
    @State private var showFreeSlots = false
    @State private var meetingPrepText = ""
    @State private var isGeneratingPrep = false
    @State private var showMeetingPrep = false
    @State private var prepForEvent: CalEventItem?
    @State private var expandedEventId: String? = nil
    @State private var showEditEvent = false
    @State private var editingEvent: CalEventItem? = nil
    @State private var dailySummary = ""
    @State private var isGeneratingSummary = false
    @State private var conflicts: [(CalEventItem, CalEventItem)] = []
    @State private var weekPreview = ""
    @State private var isGeneratingWeek = false
    @State private var showWeekPreview = false

    struct CalEventItem: Identifiable {
        let id: String
        let title: String
        let startDate: Date
        let endDate: Date
        let location: String?
        let calendarName: String
        let calendarColor: CGColor?
        let isAllDay: Bool
    }

    struct CalSourceInfo: Identifiable {
        let id = UUID()
        let name: String
        let type: String
        let calendarCount: Int
        let isEnabled: Bool
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // MARK: 1) Date picker (existing)
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(Color.axisGold)
                        .padding(.horizontal)
                        .onChange(of: selectedDate) { _, _ in
                            loadEvents()
                            dailySummary = ""
                            conflicts = []
                        }

                    // MARK: 2) AI Natural Language Input (NEW)
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles").foregroundStyle(Color.axisGold)
                        TextField("e.g. Meeting with Dean Friday 2pm", text: $nlEventText)
                            .font(.subheadline)
                            .submitLabel(.send)
                            .onSubmit { Task { await parseNLEvent() } }
                        if isParsingNL {
                            ProgressView().scaleEffect(0.7)
                        } else if !nlEventText.isEmpty {
                            Button {
                                Task { await parseNLEvent() }
                            } label: {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(Color.axisGold)
                            }
                        }
                    }
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(.rect(cornerRadius: 10))
                    .padding(.horizontal)

                    // MARK: 3) AI Action Chips (NEW)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            aiActionChip("Find Free Time", icon: "clock.badge.checkmark") {
                                Task { await findFreeSlots() }
                            }
                            aiActionChip("Day Summary", icon: "doc.text") {
                                Task { await generateDailySummary() }
                            }
                            aiActionChip("Week Preview", icon: "calendar.badge.clock") {
                                Task { await generateWeekPreview() }
                            }
                            aiActionChip("Check Conflicts", icon: "exclamationmark.triangle") {
                                checkConflicts()
                            }
                        }
                        .padding(.horizontal)
                    }

                    // MARK: 4) Daily Summary Card (NEW)
                    if isGeneratingSummary {
                        HStack(spacing: 8) {
                            ProgressView().scaleEffect(0.7)
                            Text("Generating summary...").font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(Color.axisGold.opacity(0.08))
                        .clipShape(.rect(cornerRadius: 12))
                        .padding(.horizontal)
                    } else if !dailySummary.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "sparkles").foregroundStyle(Color.axisGold)
                                Text("Daily Summary").font(.caption).fontWeight(.semibold).foregroundStyle(Color.axisGold)
                                Spacer()
                                Button { dailySummary = "" } label: {
                                    Image(systemName: "xmark.circle.fill").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Text(dailySummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .background(Color.axisGold.opacity(0.08))
                        .clipShape(.rect(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    // MARK: 5) Conflict Warnings (NEW)
                    if !conflicts.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                                Text("\(conflicts.count) conflict\(conflicts.count == 1 ? "" : "s") detected")
                                    .font(.caption).fontWeight(.semibold).foregroundStyle(.red)
                                Spacer()
                                Button { conflicts = [] } label: {
                                    Image(systemName: "xmark.circle.fill").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            ForEach(Array(conflicts.enumerated()), id: \.offset) { _, pair in
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.triangle.merge").font(.caption2).foregroundStyle(.red)
                                    Text("\(pair.0.title) overlaps with \(pair.1.title)")
                                        .font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                                }
                            }
                        }
                        .padding(12)
                        .background(.red.opacity(0.08))
                        .clipShape(.rect(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    // MARK: 6) Connected accounts banner (existing)
                    Button { showConnectSheet = true } label: {
                        HStack {
                            Image(systemName: "link.circle.fill")
                                .foregroundStyle(Color.axisGold)
                            Text("\(connectedSources.count) calendar account\(connectedSources.count == 1 ? "" : "s") connected")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Manage")
                                .font(.caption)
                                .foregroundStyle(Color.axisGold)
                        }
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(.rect(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)

                    Divider()

                    // MARK: 7) Events list (existing + enhanced with travel warnings & context menu)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Events")
                                .font(.headline)
                            Spacer()
                            Text("\(events.count)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.axisGold.opacity(0.15))
                                .foregroundStyle(Color.axisGold)
                                .clipShape(.capsule)
                        }
                        .padding(.horizontal)

                        if !calendarGranted {
                            VStack(spacing: 12) {
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .font(.title)
                                    .foregroundStyle(.orange)
                                Text("Calendar access required")
                                    .font(.subheadline)
                                Button("Grant Access") {
                                    Task { await requestAccess(); loadEvents() }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color.axisGold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        } else if events.isEmpty {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundStyle(.secondary)
                                Text("No events on this day")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                        } else {
                            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                                VStack(spacing: 0) {
                                    // Travel time warning (Feature 6)
                                    if index > 0 {
                                        let prev = events[index - 1]
                                        let gap = event.startDate.timeIntervalSince(prev.endDate)
                                        let differentLocations = hasDifferentLocations(prev, event)
                                        if differentLocations && gap < 900 && gap >= 0 {
                                            let gapMin = Int(gap / 60)
                                            HStack(spacing: 4) {
                                                Image(systemName: "car.fill").font(.caption2).foregroundStyle(.orange)
                                                Text("\(gapMin) min gap — may need more travel time")
                                                    .font(.caption2).foregroundStyle(.orange)
                                            }
                                            .padding(.vertical, 4)
                                            .padding(.horizontal, 8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(.orange.opacity(0.08))
                                            .clipShape(.rect(cornerRadius: 6))
                                            .padding(.bottom, 4)
                                        }
                                    }

                                    // Event row with conflict badge + context menu + swipe
                                    eventRow(event)
                                        .overlay(alignment: .topTrailing) {
                                            if isConflicting(event) {
                                                Image(systemName: "exclamationmark.circle.fill")
                                                    .font(.caption)
                                                    .foregroundStyle(.red)
                                                    .padding(6)
                                            }
                                        }
                                        .onTapGesture {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                expandedEventId = expandedEventId == event.id ? nil : event.id
                                            }
                                        }
                                        .contextMenu {
                                            Button {
                                                editingEvent = event
                                                newTitle = event.title
                                                newStart = event.startDate
                                                newEnd = event.endDate
                                                newLocation = event.location ?? ""
                                                newNotes = ""
                                                showEditEvent = true
                                            } label: {
                                                Label("Edit", systemImage: "pencil")
                                            }
                                            Button {
                                                Task { await generateMeetingPrep(for: event) }
                                            } label: {
                                                Label("AI Meeting Prep", systemImage: "sparkles")
                                            }
                                            Button {
                                                shareEventAsICS(event)
                                            } label: {
                                                Label("Send Calendar Invite", systemImage: "calendar.badge.plus")
                                            }
                                            Button {
                                                textEventDetails(event)
                                            } label: {
                                                Label("Text Details", systemImage: "message")
                                            }
                                            Button {
                                                PlatformServices.copyToClipboard(eventDetailsText(event))
                                            } label: {
                                                Label("Copy Details", systemImage: "doc.on.doc")
                                            }
                                            Button {
                                                addEventToTasks(event)
                                            } label: {
                                                Label("Add to Tasks", systemImage: "checklist")
                                            }
                                            Divider()
                                            Button(role: .destructive) {
                                                deleteEvent(event)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                deleteEvent(event)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                        .swipeActions(edge: .leading) {
                                            Button {
                                                textEventDetails(event)
                                            } label: {
                                                Label("Text", systemImage: "message")
                                            }
                                            .tint(.blue)
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom, 100)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Calendar")
                        .font(.system(.title3, design: .serif).weight(.bold))
                        .foregroundStyle(Color.axisGold)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showCreateEvent = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.axisGold)
                    }
                }
            }
            .sheet(isPresented: $showCreateEvent) {
                createEventSheet
            }
            .sheet(isPresented: $showEditEvent) {
                editEventSheet
            }
            .sheet(isPresented: $showConnectSheet) {
                connectedAccountsSheet
            }
            .sheet(isPresented: $showFreeSlots) {
                freeSlotsSheet
            }
            .sheet(isPresented: $showMeetingPrep) {
                meetingPrepSheet
            }
            .sheet(isPresented: $showWeekPreview) {
                weekPreviewSheet
            }
            .task {
                await requestAccess()
                loadEvents()
                loadSources()
            }
        }
    }

    // MARK: - Event Row

    private func eventRow(_ event: CalEventItem) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if let color = event.calendarColor {
                    Rectangle().fill(Color(cgColor: color)).frame(width: 4).clipShape(.rect(cornerRadius: 2))
                } else {
                    Rectangle().fill(Color.axisGold).frame(width: 4).clipShape(.rect(cornerRadius: 2))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title).font(.subheadline).fontWeight(.medium)
                    HStack(spacing: 6) {
                        if event.isAllDay {
                            Text("All Day").font(.caption2).foregroundStyle(Color.axisGold)
                        } else {
                            Text(timeStr(event.startDate)).font(.caption).foregroundStyle(.secondary)
                            Text("–").font(.caption).foregroundStyle(.secondary)
                            Text(timeStr(event.endDate)).font(.caption).foregroundStyle(.secondary)
                        }
                        if let loc = event.location, !loc.isEmpty {
                            Text("• \(loc)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    Text(event.calendarName).font(.caption2).foregroundStyle(.tertiary)
                }
                Spacer()
                Image(systemName: expandedEventId == event.id ? "chevron.up" : "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Expanded details + action buttons
            if expandedEventId == event.id {
                Divider().padding(.vertical, 8)

                VStack(alignment: .leading, spacing: 8) {
                    if !event.isAllDay {
                        let duration = Int(event.endDate.timeIntervalSince(event.startDate) / 60)
                        HStack(spacing: 4) {
                            Image(systemName: "clock").font(.caption2).foregroundStyle(.secondary)
                            Text("\(duration) minutes").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if let loc = event.location, !loc.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill").font(.caption2).foregroundStyle(.secondary)
                            Text(loc).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                // Quick action buttons
                HStack(spacing: 10) {
                    quickActionButton("Share", icon: "square.and.arrow.up") {
                        shareEventAsICS(event)
                    }
                    quickActionButton("Text", icon: "message") {
                        textEventDetails(event)
                    }
                    quickActionButton("Copy", icon: "doc.on.doc") {
                        PlatformServices.copyToClipboard(eventDetailsText(event))
                    }
                    quickActionButton("Delete", icon: "trash", destructive: true) {
                        deleteEvent(event)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 12))
    }

    private func quickActionButton(_ label: String, icon: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.system(size: 9))
            }
            .foregroundStyle(destructive ? .red : Color.axisGold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(destructive ? .red.opacity(0.08) : Color.axisGold.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Create Event Sheet

    private var createEventSheet: some View {
        NavigationStack {
            Form {
                TextField("Event Title", text: $newTitle)
                DatePicker("Start", selection: $newStart)
                DatePicker("End", selection: $newEnd)
                TextField("Location", text: $newLocation)
                TextField("Notes", text: $newNotes, axis: .vertical).lineLimit(3...6)
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showCreateEvent = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { createEvent(); showCreateEvent = false }
                        .disabled(newTitle.isEmpty)
                }
            }
        }
    }

    // MARK: - Connected Accounts Sheet

    private var connectedAccountsSheet: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(connectedSources) { source in
                        HStack {
                            Image(systemName: iconForSource(source.type))
                                .foregroundStyle(Color.axisGold)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(source.name).font(.subheadline).fontWeight(.medium)
                                Text("\(source.calendarCount) calendar\(source.calendarCount == 1 ? "" : "s") • \(source.type)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                } header: {
                    Text("Connected Accounts")
                } footer: {
                    Text("Calendars are synced through your iPhone's Settings \u{2192} Calendar \u{2192} Accounts. Add Google, Outlook, Exchange, or other accounts there and they'll appear here automatically.")
                }

                Section {
                    Button {
                        #if os(iOS)
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            PlatformServices.openURL(url)
                        }
                        #endif
                    } label: {
                        Label("Open iPhone Settings", systemImage: "gear")
                    }

                    Link(destination: URL(string: "calshow://")!) {
                        Label("Open Apple Calendar", systemImage: "calendar")
                    }

                    Button {
                        if let url = URL(string: "ms-outlook://") {
                            PlatformServices.openURL(url)
                        }
                    } label: {
                        Label("Open Outlook", systemImage: "envelope.fill")
                    }
                } header: {
                    Text("Connect Accounts")
                } footer: {
                    Text("To connect Outlook, Gmail, or Exchange:\n\n1. Open iPhone Settings\n2. Tap Calendar \u{2192} Accounts\n3. Tap Add Account\n4. Select Microsoft Exchange, Google, or Outlook.com\n5. Sign in with your credentials\n\nCalendars will sync automatically and appear here.")
                }
            }
            .navigationTitle("Calendar Accounts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showConnectSheet = false }
                }
            }
        }
    }

    // MARK: - Free Slots Sheet (NEW)

    private var freeSlotsSheet: some View {
        NavigationStack {
            List {
                if isSearchingSlots {
                    HStack {
                        ProgressView().scaleEffect(0.8)
                        Text("Finding free time...").font(.subheadline).foregroundStyle(.secondary)
                    }
                } else if freeSlots.isEmpty {
                    Text("No free slots found during working hours (8 AM - 5 PM).")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Section {
                        ForEach(freeSlots, id: \.self) { slot in
                            HStack(spacing: 8) {
                                Image(systemName: "clock.fill").foregroundStyle(.green)
                                Text(slot).font(.subheadline)
                            }
                        }
                    } header: {
                        Text("Available Time Slots")
                    } footer: {
                        Text("Working hours: 8:00 AM - 5:00 PM")
                    }
                }
            }
            .navigationTitle("Free Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showFreeSlots = false }
                }
            }
        }
    }

    // MARK: - Meeting Prep Sheet (NEW)

    private var meetingPrepSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let event = prepForEvent {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar.circle.fill").foregroundStyle(Color.axisGold).font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.title).font(.headline)
                                Text("\(timeStr(event.startDate)) - \(timeStr(event.endDate))")
                                    .font(.caption).foregroundStyle(.secondary)
                                if let loc = event.location, !loc.isEmpty {
                                    Text(loc).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.bottom, 4)
                    }

                    Divider()

                    if isGeneratingPrep {
                        HStack(spacing: 8) {
                            ProgressView().scaleEffect(0.8)
                            Text("Generating meeting prep...").font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(.top, 8)
                    } else if !meetingPrepText.isEmpty {
                        Text(meetingPrepText)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding()
            }
            .navigationTitle("Meeting Prep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showMeetingPrep = false }
                }
            }
        }
    }

    // MARK: - Week Preview Sheet (NEW)

    private var weekPreviewSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if isGeneratingWeek {
                        HStack(spacing: 8) {
                            ProgressView().scaleEffect(0.8)
                            Text("Generating week preview...").font(.subheadline).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                    } else if !weekPreview.isEmpty {
                        Text(weekPreview)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding()
            }
            .navigationTitle("Week Ahead")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showWeekPreview = false }
                }
            }
        }
    }

    // MARK: - AI Action Chip

    private func aiActionChip(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption2)
                Text(title).font(.caption).fontWeight(.medium)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.axisGold.opacity(0.12))
            .foregroundStyle(Color.axisGold)
            .clipShape(.capsule)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Edit Event Sheet

    private var editEventSheet: some View {
        NavigationStack {
            Form {
                TextField("Event Title", text: $newTitle)
                DatePicker("Start", selection: $newStart)
                DatePicker("End", selection: $newEnd)
                TextField("Location", text: $newLocation)
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showEditEvent = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let editing = editingEvent {
                            updateEvent(editing)
                        }
                        showEditEvent = false
                    }
                    .disabled(newTitle.isEmpty)
                }
            }
        }
    }

    // MARK: - Event Actions

    private func deleteEvent(_ event: CalEventItem) {
        let store = EKEventStore()
        if let ekEvent = store.calendarItem(withIdentifier: event.id) as? EKEvent {
            try? store.remove(ekEvent, span: .thisEvent)
            loadEvents()
        }
    }

    private func updateEvent(_ event: CalEventItem) {
        let store = EKEventStore()
        if let ekEvent = store.calendarItem(withIdentifier: event.id) as? EKEvent {
            ekEvent.title = newTitle
            ekEvent.startDate = newStart
            ekEvent.endDate = newEnd
            if !newLocation.isEmpty { ekEvent.location = newLocation }
            try? store.save(ekEvent, span: .thisEvent)
            loadEvents()
        }
    }

    private func eventDetailsText(_ event: CalEventItem) -> String {
        let df = DateFormatter()
        df.dateFormat = "EEEE, MMMM d"
        let dateText = df.string(from: event.startDate)

        var text = "\(event.title)\n"
        if event.isAllDay {
            text += "\(dateText) - All Day\n"
        } else {
            text += "\(dateText) at \(timeStr(event.startDate)) - \(timeStr(event.endDate))\n"
        }
        if let loc = event.location, !loc.isEmpty {
            text += "\(loc)\n"
        }
        return text
    }

    private func textEventDetails(_ event: CalEventItem) {
        let details = eventDetailsText(event)
        let encoded = details.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "sms:&body=\(encoded)") {
            PlatformServices.openURL(url)
        }
    }

    private func shareEventAsICS(_ event: CalEventItem) {
        // Create .ics content
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd'T'HHmmss"
        df.timeZone = TimeZone.current

        var ics = "BEGIN:VCALENDAR\nVERSION:2.0\nPRODID:-//AXIS//EN\nBEGIN:VEVENT\n"
        ics += "SUMMARY:\(event.title)\n"
        ics += "DTSTART:\(df.string(from: event.startDate))\n"
        ics += "DTEND:\(df.string(from: event.endDate))\n"
        if let loc = event.location, !loc.isEmpty {
            ics += "LOCATION:\(loc)\n"
        }
        ics += "END:VEVENT\nEND:VCALENDAR"

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(event.title.replacingOccurrences(of: " ", with: "_")).ics")
        try? ics.write(to: tempURL, atomically: true, encoding: .utf8)

        // Also include plain text
        let plainText = eventDetailsText(event)

        PlatformServices.share(items: [plainText, tempURL])
    }

    private func addEventToTasks(_ event: CalEventItem) {
        let task = EATask(title: event.title, category: "general")
        if !event.isAllDay {
            task.deadline = event.startDate
        }
        PersistenceService.shared.saveEATask(task)
    }

    // MARK: - EventKit

    private func requestAccess() async {
        let store = EKEventStore()
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .fullAccess || status == .writeOnly {
            calendarGranted = true
            return
        }
        if status == .notDetermined {
            let granted = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
                store.requestFullAccessToEvents { granted, _ in c.resume(returning: granted) }
            }
            calendarGranted = granted
        }
    }

    private func loadEvents() {
        guard calendarGranted else { return }
        let store = EKEventStore()
        let start = Calendar.current.startOfDay(for: selectedDate)
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let ekEvents = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
        events = ekEvents.map { e in
            CalEventItem(
                id: e.calendarItemIdentifier,
                title: e.title ?? "Untitled",
                startDate: e.startDate,
                endDate: e.endDate,
                location: e.location,
                calendarName: e.calendar?.title ?? "Calendar",
                calendarColor: e.calendar?.cgColor,
                isAllDay: e.isAllDay
            )
        }
    }

    private func loadEventsForDateRange(start: Date, end: Date) -> [CalEventItem] {
        guard calendarGranted else { return [] }
        let store = EKEventStore()
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let ekEvents = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
        return ekEvents.map { e in
            CalEventItem(
                id: e.calendarItemIdentifier,
                title: e.title ?? "Untitled",
                startDate: e.startDate,
                endDate: e.endDate,
                location: e.location,
                calendarName: e.calendar?.title ?? "Calendar",
                calendarColor: e.calendar?.cgColor,
                isAllDay: e.isAllDay
            )
        }
    }

    private func loadSources() {
        let store = EKEventStore()
        connectedSources = store.sources.filter { $0.sourceType != .local || !$0.calendars(for: .event).isEmpty }.map { source in
            let typeName: String
            switch source.sourceType {
            case .local: typeName = "On My iPhone"
            case .exchange: typeName = "Exchange"
            case .calDAV: typeName = "CalDAV"
            case .mobileMe: typeName = "iCloud"
            case .subscribed: typeName = "Subscribed"
            case .birthdays: typeName = "Birthdays"
            default: typeName = "Other"
            }
            return CalSourceInfo(
                name: source.title,
                type: typeName,
                calendarCount: source.calendars(for: .event).count,
                isEnabled: true
            )
        }
    }

    private func createEvent() {
        guard calendarGranted else { return }
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.title = newTitle
        event.startDate = newStart
        event.endDate = newEnd
        if !newLocation.isEmpty { event.location = newLocation }
        if !newNotes.isEmpty { event.notes = newNotes }
        event.calendar = store.defaultCalendarForNewEvents
        try? store.save(event, span: .thisEvent)
        newTitle = ""; newLocation = ""; newNotes = ""
        loadEvents()
    }

    private func iconForSource(_ type: String) -> String {
        switch type {
        case "iCloud": return "icloud.fill"
        case "Exchange": return "building.2.fill"
        case "CalDAV": return "globe"
        case "On My iPhone": return "iphone"
        case "Subscribed": return "link"
        case "Birthdays": return "gift.fill"
        default: return "calendar"
        }
    }

    private func timeStr(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f.string(from: date)
    }

    private func dateStr(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }

    private func isoStr(_ date: Date) -> String {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f.string(from: date)
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"; return f.string(from: date)
    }

    // MARK: - Feature 1: Natural Language Event Creation

    private func parseNLEvent() async {
        let text = nlEventText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isParsingNL = true
        PlatformServices.dismissKeyboard()

        let today = DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .none)
        let prompt = """
        Parse this into a calendar event. Today is \(today).
        Return ONLY valid JSON, no other text: {"title":"...","startDate":"2026-03-26T14:00:00","endDate":"2026-03-26T15:00:00","location":""}
        If no end time mentioned, make it 1 hour after start.
        If no specific date, assume today or the next occurrence of the mentioned day.
        Input: \(text)
        """

        let result = await askAI(prompt)

        // Try to extract JSON from the response
        var jsonStr = result
        if let start = result.firstIndex(of: "{"), let end = result.lastIndex(of: "}") {
            jsonStr = String(result[start...end])
        }

        if let data = jsonStr.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let title = json["title"] as? String, !title.isEmpty {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime]

            // Try multiple date formats
            let startStr = json["startDate"] as? String ?? ""
            let endStr = json["endDate"] as? String ?? ""

            var startDate = isoFormatter.date(from: startStr)
            var endDate = isoFormatter.date(from: endStr)

            // Fallback: try without seconds
            if startDate == nil {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                f.timeZone = .current
                startDate = f.date(from: startStr)
                endDate = f.date(from: endStr)
            }

            if let start = startDate {
                let end = endDate ?? start.addingTimeInterval(3600)
                let store = EKEventStore()
                if EKEventStore.authorizationStatus(for: .event) == .fullAccess {
                    let event = EKEvent(eventStore: store)
                    event.title = title
                    event.startDate = start
                    event.endDate = end
                    let loc = json["location"] as? String ?? ""
                    if !loc.isEmpty { event.location = loc }
                    event.calendar = store.defaultCalendarForNewEvents
                    try? store.save(event, span: .thisEvent)
                    nlEventText = ""
                    loadEvents()
                }
            }
        }
        isParsingNL = false
    }

    // MARK: - Feature 2: Smart Free Slot Finder

    private func findFreeSlots() async {
        isSearchingSlots = true
        showFreeSlots = true
        defer { isSearchingSlots = false }

        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: selectedDate)

        // Working hours: 8 AM - 5 PM
        guard let workStart = cal.date(bySettingHour: 8, minute: 0, second: 0, of: dayStart),
              let workEnd = cal.date(bySettingHour: 17, minute: 0, second: 0, of: dayStart) else {
            freeSlots = []
            return
        }

        // Get non-all-day events sorted by start time
        let dayEvents = events.filter { !$0.isAllDay }.sorted { $0.startDate < $1.startDate }

        var slots: [String] = []
        var cursor = workStart
        let tf = DateFormatter()
        tf.dateFormat = "h:mm a"

        for event in dayEvents {
            let evStart = max(event.startDate, workStart)
            let evEnd = min(event.endDate, workEnd)

            if evStart > cursor {
                let gap = evStart.timeIntervalSince(cursor)
                if gap >= 900 { // At least 15 minutes
                    let duration = Int(gap / 60)
                    slots.append("\(tf.string(from: cursor)) - \(tf.string(from: evStart)) (\(duration) min free)")
                }
            }
            if evEnd > cursor {
                cursor = evEnd
            }
        }

        // Check remaining time after last event
        if cursor < workEnd {
            let gap = workEnd.timeIntervalSince(cursor)
            if gap >= 900 {
                let duration = Int(gap / 60)
                slots.append("\(tf.string(from: cursor)) - \(tf.string(from: workEnd)) (\(duration) min free)")
            }
        }

        freeSlots = slots
    }

    // MARK: - Feature 3: Meeting Prep

    private func generateMeetingPrep(for event: CalEventItem) async {
        prepForEvent = event
        meetingPrepText = ""
        isGeneratingPrep = true
        showMeetingPrep = true

        let timeInfo = event.isAllDay ? "All day" : "\(timeStr(event.startDate)) - \(timeStr(event.endDate))"
        let locationInfo = event.location ?? "No location specified"
        let prompt = "Generate brief meeting prep notes for: \(event.title) at \(timeInfo). Location: \(locationInfo). Include 3 talking points, questions to ask, and any prep needed. Keep it concise."

        let response = await askAI(prompt)
        meetingPrepText = response
        isGeneratingPrep = false
    }

    // MARK: - Feature 4: Daily Schedule Summary

    private func generateDailySummary() async {
        guard !events.isEmpty else {
            dailySummary = "No events scheduled for this day."
            return
        }
        isGeneratingSummary = true
        defer { isGeneratingSummary = false }

        let eventList = events.map { event in
            let time = event.isAllDay ? "All Day" : "\(timeStr(event.startDate))-\(timeStr(event.endDate))"
            let loc = event.location ?? ""
            return "- \(event.title) (\(time))\(loc.isEmpty ? "" : " at \(loc)")"
        }.joined(separator: "\n")

        let prompt = "Summarize this day's schedule. Events:\n\(eventList)\nHighlight conflicts, busy periods, and free time. Keep it to 3-4 sentences."
        dailySummary = await askAI(prompt)
    }

    // MARK: - Feature 5: Conflict Detection

    private func checkConflicts() {
        var found: [(CalEventItem, CalEventItem)] = []
        let timedEvents = events.filter { !$0.isAllDay }

        for i in 0..<timedEvents.count {
            for j in (i + 1)..<timedEvents.count {
                let a = timedEvents[i]
                let b = timedEvents[j]
                // Overlap: a starts before b ends AND b starts before a ends
                if a.startDate < b.endDate && b.startDate < a.endDate {
                    found.append((a, b))
                }
            }
        }
        conflicts = found
    }

    private func isConflicting(_ event: CalEventItem) -> Bool {
        conflicts.contains { $0.0.id == event.id || $0.1.id == event.id }
    }

    // MARK: - Feature 6: Travel Time Helpers

    private func hasDifferentLocations(_ a: CalEventItem, _ b: CalEventItem) -> Bool {
        let locA = (a.location ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let locB = (b.location ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        // Both must have locations and they must differ
        guard !locA.isEmpty, !locB.isEmpty else { return false }
        return locA.lowercased() != locB.lowercased()
    }

    // MARK: - Feature 7: Week-Ahead Preview

    private func generateWeekPreview() async {
        isGeneratingWeek = true
        showWeekPreview = true
        defer { isGeneratingWeek = false }

        let cal = Calendar.current
        let today = cal.startOfDay(for: selectedDate)
        guard let weekEnd = cal.date(byAdding: .day, value: 7, to: today) else {
            weekPreview = "Unable to load week data."
            return
        }

        let weekEvents = loadEventsForDateRange(start: today, end: weekEnd)

        if weekEvents.isEmpty {
            weekPreview = "No events scheduled for the next 7 days."
            return
        }

        // Group events by day
        var dayLines: [String] = []
        for dayOffset in 0..<7 {
            guard let dayDate = cal.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            let label = dayLabel(dayDate)
            let dayEvts = weekEvents.filter { cal.isDate($0.startDate, inSameDayAs: dayDate) }
            if dayEvts.isEmpty {
                dayLines.append("\(label): No events")
            } else {
                let items = dayEvts.map { e in
                    let time = e.isAllDay ? "All Day" : "\(timeStr(e.startDate))-\(timeStr(e.endDate))"
                    return "  - \(e.title) (\(time))"
                }.joined(separator: "\n")
                dayLines.append("\(label) (\(dayEvts.count) event\(dayEvts.count == 1 ? "" : "s")):\n\(items)")
            }
        }

        let prompt = "Preview this week's schedule:\n\(dayLines.joined(separator: "\n"))\n\nHighlight the busiest day, any conflicts, and recommend priorities. Keep it concise."
        weekPreview = await askAI(prompt)
    }

    // MARK: - AI Helper

    private func askAI(_ prompt: String) async -> String {
        let key = MultiProviderChatService.shared.anthropicAPIKey
        guard !key.isEmpty else { return "AI not configured" }
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 15
        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 500,
            "messages": [["role": "user", "content": prompt]]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let content = json["content"] as? [[String: Any]],
               let text = content.first?["text"] as? String {
                return text
            }
        } catch {}
        return "Unable to generate response"
    }
}

#Preview {
    CalendarTabView()
}

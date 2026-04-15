import ComposableArchitecture
import SwiftUI

struct EADashboardView: View {
    @Bindable var store: StoreOf<EADashboardReducer>
    var onNavigateToPlanner: (() -> Void)?
    var onNavigateToTasks: (() -> Void)?
    var onNavigateToProjects: (() -> Void)?
    var onSettingsTapped: (() -> Void)?
    var onAddTapped: (() -> Void)?
    var onCompletedTasksTapped: (() -> Void)?
    var onMeetingsTapped: (() -> Void)?
    var onDeepWorkTapped: (() -> Void)?
    var onToggleDarkMode: (() -> Void)?
    var isDarkMode: Bool = false

    @State private var animateStats = false
    @State private var pulseInbox = false
    @State private var showWeatherDetail = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AxisSpacing.xl) {
                    // Greeting first — quick orientation, then straight into what matters.
                    greetingBanner

                    // Timeline-first hierarchy: the most useful thing on this screen
                    // is "what does the rest of my day look like?" — show it immediately.
                    todayTimeline

                    if !store.isFocusMode {
                        // AI recommendation — surface above the fold when present.
                        if store.nextBestAction != nil { nextBestActionCard }

                        // At-risk tasks — second-priority actionable content.
                        if !store.atRiskTasks.isEmpty { priorityCarousel }
                    }

                    // Quick capture — after the user has reviewed today, let them add.
                    quickAddField

                    // Stats + weather — supporting context, not hero content.
                    animatedStatsRow

                    Button { showWeatherDetail = true } label: {
                        weatherGlance
                    }
                    .buttonStyle(.plain)

                    if !store.isFocusMode {
                        if store.inboxCount > 0 { inboxPulse }
                        if !store.activeProjects.isEmpty { projectsScroll }
                        if !store.upcomingDeadlines.isEmpty { deadlinesSection }
                        if !store.recentChatSummary.isEmpty { recentChatSection }
                    }

                    // Daily quote — flavor, bottom of screen.
                    quoteCard
                }
                .padding(.horizontal, AxisSpacing.lg)
                .padding(.bottom, 100)
            }
            .refreshable { store.send(.refreshTapped) }
            .background(timeOfDayGradient)
            .scrollDismissesKeyboard(.immediately)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Executive Assistant")
                        .font(.system(.headline, design: .serif).weight(.bold))
                        .foregroundStyle(Color.axisAccent)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { onSettingsTapped?() } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: AxisSpacing.md) {
                        Button { onToggleDarkMode?() } label: {
                            Image(systemName: isDarkMode ? "sun.max" : "moon")
                                .foregroundStyle(.secondary)
                        }
                        Button { store.send(.toggleFocusMode) } label: {
                            Image(systemName: store.isFocusMode ? "eye.slash" : "eye")
                                .foregroundStyle(store.isFocusMode ? Color.axisWarning : .secondary)
                        }
                        // The ONE gold action in the toolbar — the primary "add" CTA.
                        Button { onAddTapped?() } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.axisAccent)
                                .font(.title3)
                        }
                    }
                }
            }
            .sheet(isPresented: $showWeatherDetail) {
                if let weather = WeatherService.shared.currentWeather {
                    WeatherDetailView(
                        weather: weather,
                        hourly: WeatherService.shared.hourlyForecast,
                        daily: WeatherService.shared.dailyForecast
                    )
                }
            }
            .onAppear {
                store.send(.onAppear)
                withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                    animateStats = true
                }
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulseInbox = true
                }
            }
        }
    }

    // MARK: - Time-of-day gradient background

    private var timeOfDayGradient: some View {
        let hour = Calendar.current.component(.hour, from: Date())
        let dark = colorScheme == .dark
        let colors: [Color] = {
            if dark {
                // Dark mode: subtle dark gradients that keep text legible
                switch hour {
                case 5..<8: return [Color(red: 0.08, green: 0.06, blue: 0.02), Color(red: 0.1, green: 0.08, blue: 0.03)]
                case 8..<17: return [Color(red: 0.07, green: 0.07, blue: 0.09), Color(red: 0.05, green: 0.05, blue: 0.07)]
                case 17..<20: return [Color(red: 0.06, green: 0.04, blue: 0.08), Color(red: 0.04, green: 0.03, blue: 0.06)]
                default: return [Color(red: 0.04, green: 0.04, blue: 0.06), Color(red: 0.02, green: 0.02, blue: 0.04)]
                }
            } else {
                // Light mode
                switch hour {
                case 5..<8: return [Color(red: 1.0, green: 0.97, blue: 0.9), Color(red: 0.98, green: 0.95, blue: 0.87)]
                case 8..<12: return [Color(red: 0.96, green: 0.96, blue: 0.94), Color(red: 0.94, green: 0.93, blue: 0.91)]
                case 12..<17: return [Color(.systemGroupedBackground), Color(.systemGroupedBackground)]
                case 17..<20: return [Color(red: 0.93, green: 0.91, blue: 0.95), Color(red: 0.95, green: 0.93, blue: 0.96)]
                default: return [Color(red: 0.92, green: 0.92, blue: 0.94), Color(red: 0.9, green: 0.9, blue: 0.93)]
                }
            }
        }()
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }

    // MARK: 1 - Animated Greeting Banner

    private var greetingBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(store.currentGreeting)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Text(store.userName.isEmpty ? "Commander" : store.userName)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.axisGold)

                if store.streakDays > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                        Text("\(store.streakDays) day streak")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.orange.opacity(0.15))
                    .clipShape(.capsule)
                }
            }
            Spacer()

            // Energy ring
            if store.isEnergyLoaded {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                        .frame(width: 56, height: 56)
                    Circle()
                        .trim(from: 0, to: animateStats ? CGFloat(store.energyScore) / 10.0 : 0)
                        .stroke(
                            energyColor,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(store.energyScore)")
                            .font(.system(.callout, design: .rounded).weight(.bold))
                            .foregroundStyle(energyColor)
                        Text("Energy")
                            .font(.system(size: 7))
                            .foregroundStyle(.secondary)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    private var energyColor: Color {
        store.energyScore >= 7 ? .green : store.energyScore >= 4 ? .orange : .red
    }

    // MARK: - Quick Add

    private var quickAddField: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(Color.axisGold)
            TextField("Quick add a task...", text: $store.quickAddText.sending(\.quickAddTextChanged))
                .font(.subheadline)
                .onSubmit { store.send(.quickAddSubmit) }
            if !store.quickAddText.isEmpty {
                Button { store.send(.quickAddSubmit) } label: {
                    Text("Add")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.axisGold)
                        .clipShape(.capsule)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 12))
    }

    // MARK: 8 - Weather Glance

    private var weatherGlance: some View {
        VStack(alignment: .leading, spacing: 10) {
            if store.isWeatherLoaded {
                // Row 1: Icon + Temp + Condition
                HStack(spacing: 12) {
                    Image(systemName: store.weatherIcon)
                        .font(.system(size: 36))
                        .symbolRenderingMode(.multicolor)
                        .frame(width: 40)

                    Text(store.weatherTemp)
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .minimumScaleFactor(0.7)

                    Text(store.weatherCondition)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()
                }

                // Row 2: Location + Details
                HStack(spacing: 16) {
                    if !store.locationName.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                                .foregroundStyle(Color.axisGold)
                            Text(store.locationName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if !store.weatherFeelsLike.isEmpty {
                        Text("Feels \(store.weatherFeelsLike)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !store.weatherHumidity.isEmpty {
                        Text("\(store.weatherHumidity)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                // Row 3: Actionable note
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                        .foregroundStyle(Color.axisGold)
                    Text(store.weatherNote)
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
            } else {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Loading weather...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: 6 - Animated Stats Row

    private var animatedStatsRow: some View {
        HStack(spacing: 12) {
            animatedStatCard(
                icon: "checkmark.circle.fill",
                value: store.tasksCompletedToday,
                label: "Done",
                color: .green,
                action: onCompletedTasksTapped
            )
            animatedStatCard(
                icon: "calendar",
                value: store.meetingsRemaining,
                label: "Meetings",
                color: .purple,
                action: onMeetingsTapped
            )
            animatedStatCard(
                icon: "brain.head.profile",
                value: nil,
                label: "Deep Work",
                color: .blue,
                action: onDeepWorkTapped,
                stringValue: String(format: "%.1fh", store.deepWorkHoursToday)
            )
        }
    }

    private func animatedStatCard(icon: String, value: Int?, label: String, color: Color, action: (() -> Void)?, stringValue: String? = nil) -> some View {
        Button { action?() } label: {
            GlassCard {
                VStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(color)
                    if let stringValue {
                        Text(animateStats ? stringValue : "0")
                            .font(.headline)
                            .contentTransition(.numericText())
                    } else if let value {
                        Text(animateStats ? "\(value)" : "0")
                            .font(.headline)
                            .contentTransition(.numericText())
                    }
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: 3 - Today's Timeline

    private var todayTimeline: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(Color.axisGold)
                    Text("Today's Timeline")
                        .font(.headline)
                        .foregroundStyle(Color.axisGold)
                    Spacer()
                    Button { onNavigateToPlanner?() } label: {
                        Text("Full Plan")
                            .font(.caption)
                            .foregroundStyle(Color.axisGold)
                    }
                }

                if store.isPlanLoaded {
                    if store.planTimeBlocks.isEmpty {
                        Text(store.planSummary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        // Vertical timeline with NOW marker
                        let nowString = {
                            let f = DateFormatter()
                            f.dateFormat = "h:mm a"
                            return f.string(from: Date())
                        }()

                        ForEach(Array(store.planTimeBlocks.prefix(6).enumerated()), id: \.element.id) { index, block in
                            HStack(alignment: .top, spacing: 12) {
                                // Timeline line + dot
                                VStack(spacing: 0) {
                                    Circle()
                                        .fill(blockColor(block.blockType))
                                        .frame(width: 10, height: 10)
                                    if index < min(store.planTimeBlocks.count - 1, 5) {
                                        Rectangle()
                                            .fill(Color.secondary.opacity(0.2))
                                            .frame(width: 2, height: 32)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(block.title)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .lineLimit(1)
                                    HStack(spacing: 4) {
                                        Text(block.startTime)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text("–")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                        Text(block.endTime)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Text(block.blockType == "meeting" ? "Meeting" : block.blockType == "task" ? "Task" : block.blockType == "focusBlock" ? "Focus" : "Break")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundStyle(blockColor(block.blockType))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(blockColor(block.blockType).opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }

                        if store.planTimeBlocks.count > 6 {
                            Text("+\(store.planTimeBlocks.count - 6) more")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 22)
                        }
                    }
                } else {
                    HStack {
                        ProgressView()
                        Text("Building your timeline...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: 5 - Next Best Action

    private var nextBestActionCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.axisGold)
                    Text("Your Next Move")
                        .font(.headline)
                        .foregroundStyle(Color.axisGold)
                    Spacer()
                }
                if let action = store.nextBestAction {
                    Text(action.taskTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(action.reasoning)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button { onNavigateToTasks?() } label: {
                        Text("Start Now")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.axisGold)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.axisGold.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: 4 - Priority Cards Carousel

    private var priorityCarousel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text("At Risk")
                    .font(.headline)
                    .foregroundStyle(.red)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(store.atRiskTasks) { task in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(task.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .lineLimit(2)
                            Text("Due \(task.deadline, style: .relative)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack {
                                Text(task.priority.uppercased())
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(task.priority == "critical" ? .red : .orange)
                                    .clipShape(Capsule())
                                Spacer()
                                Button("Schedule") {
                                    store.send(.scheduleAtRiskTask(task.id))
                                }
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.orange)
                            }
                        }
                        .padding(14)
                        .frame(width: 200)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    // MARK: 9 - Inbox Pulse

    private var inboxPulse: some View {
        Button { onNavigateToTasks?() } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(.orange.opacity(pulseInbox ? 0.3 : 0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: "tray.fill")
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(store.inboxCount) unreviewed item\(store.inboxCount == 1 ? "" : "s")")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Tap to quick-triage")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.orange.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Active Projects

    private var projectsScroll: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active Projects")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(store.activeProjects) { project in
                        Button { onNavigateToProjects?() } label: {
                            GlassCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(project.title)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                    ProgressView(value: project.progress)
                                        .tint(Color.axisGold)
                                    HStack {
                                        Text("\(Int(project.progress * 100))%")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        if let days = project.daysToDeadline {
                                            Text("\(days)d left")
                                                .font(.caption2)
                                                .foregroundStyle(days < 3 ? .red : .secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(width: 180)
                    }
                }
            }
        }
    }

    // MARK: - Deadlines

    private var deadlinesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundStyle(.red)
                Text("Upcoming Deadlines")
                    .font(.headline)
                    .foregroundStyle(.red)
            }
            ForEach(store.upcomingDeadlines) { deadline in
                GlassCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(deadline.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(deadline.category.capitalized)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(deadline.daysLeft == 0 ? "Today" : deadline.daysLeft == 1 ? "Tomorrow" : "\(deadline.daysLeft)d left")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(deadline.daysLeft <= 1 ? .red : deadline.daysLeft <= 3 ? .orange : .secondary)
                    }
                }
            }
        }
    }

    // MARK: - Recent Chat

    private var recentChatSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "bubble.left.and.text.bubble.right")
                        .foregroundStyle(Color.axisGold)
                    Text("Recent AI Chat")
                        .font(.headline)
                        .foregroundStyle(Color.axisGold)
                }
                Text(store.recentChatSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
    }

    // MARK: 10 - Daily Quote

    private var quoteCard: some View {
        VStack(spacing: 12) {
            if !store.dailyQuote.isEmpty {
                VStack(spacing: 16) {
                    // Bible verse
                    VStack(spacing: 8) {
                        Image(systemName: "book.closed.fill")
                            .font(.title3)
                            .foregroundStyle(Color.axisGold.opacity(0.6))

                        Text(store.dailyQuote)
                            .font(.system(.subheadline, design: .serif).weight(.medium))
                            .multilineTextAlignment(.center)
                            .italic()
                            .foregroundStyle(.primary)

                        Text("— \(store.dailyQuoteAuthor)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.axisGold)
                    }

                    // Grandma's version
                    if !store.dailyQuoteGrandma.isEmpty {
                        VStack(spacing: 6) {
                            HStack(spacing: 4) {
                                Text("🪑")
                                    .font(.caption)
                                Text("Grandma's Version")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                    .tracking(1)
                            }

                            Text("\"\(store.dailyQuoteGrandma)\"")
                                .font(.footnote.weight(.medium))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.primary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(Color.axisGold.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Actions
                    HStack(spacing: 10) {
                        Button {
                            store.send(.previousQuote)
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(store.quoteHistoryIndex > 0 ? Color.axisGold : .gray)
                                .frame(width: 32, height: 32)
                                .background(store.quoteHistoryIndex > 0 ? Color.axisGold.opacity(0.1) : Color.gray.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .disabled(store.quoteHistoryIndex <= 0)

                        Button {
                            store.send(.refreshQuote)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: store.quoteHistoryIndex < store.quoteHistory.count - 1 ? "chevron.right" : "arrow.clockwise")
                                    .font(.caption2)
                                Text(store.quoteHistoryIndex < store.quoteHistory.count - 1 ? "Next" : "New Word")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(Color.axisGold)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color.axisGold.opacity(0.1))
                            .clipShape(Capsule())
                        }

                        Button {
                            let shareText = "\"\(store.dailyQuote)\"\n— \(store.dailyQuoteAuthor)\n\n\(store.dailyQuoteGrandma)\n\n— Shared from AXIS"
                            PlatformServices.share(items: [shareText])
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.caption2)
                                Text("Share")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(Color.axisGold)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color.axisGold.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - Helpers

    private func blockColor(_ type: String) -> Color {
        switch type {
        case "meeting": return .purple
        case "focusBlock": return .blue
        case "break": return .green
        case "task": return Color.axisGold
        default: return .gray
        }
    }
}

#Preview {
    EADashboardView(
        store: Store(initialState: EADashboardReducer.State()) {
            EADashboardReducer()
        }
    )
}

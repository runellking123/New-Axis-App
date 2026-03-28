import ComposableArchitecture
import SwiftUI

struct BalanceView: View {
    @Bindable var store: StoreOf<BalanceReducer>

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    checkInBanner
                    if !store.todayCheckIns.isEmpty { energyTimeline }
                    healthKitRow
                    moodAndWaterRow
                    if store.weeklyEnergyAverages.contains(where: { $0 > 0 }) { weeklyEnergyChart }
                    suggestionsCard
                    stressCard
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .background(Color(.systemGroupedBackground))
            .scrollDismissesKeyboard(.immediately)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Balance")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(.green)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button { store.send(.exportData) } label: {
                            Image(systemName: "square.and.arrow.up").foregroundStyle(.green)
                        }
                        Button { store.send(.requestHealthAccess) } label: {
                            Image(systemName: "arrow.clockwise").foregroundStyle(.green)
                        }
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { store.showCheckIn },
                set: { if !$0 { store.send(.dismissCheckIn) } }
            )) { checkInSheet }
            .onAppear { store.send(.onAppear) }
        }
    }

    private var checkInBanner: some View {
        Button { store.send(.showCheckInSheet) } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(.green.opacity(0.15)).frame(width: 44, height: 44)
                    Image(systemName: "bolt.heart.fill").font(.title3).foregroundStyle(.green)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("How's your energy right now?").font(.subheadline).fontWeight(.medium)
                    Text(store.todayCheckIns.isEmpty ? "No check-ins today" : "\(store.todayCheckIns.count) check-in\(store.todayCheckIns.count == 1 ? "" : "s") today | Avg: \(String(format: "%.0f", store.todayAverageEnergy))/10")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(.green)
            }
            .padding(14).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var energyTimeline: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis").foregroundStyle(.green)
                Text("Today's Energy").font(.headline)
                Spacer()
                Text("Avg: \(String(format: "%.1f", store.todayAverageEnergy))").font(.caption).fontWeight(.bold).foregroundStyle(.green)
            }
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(store.todayCheckIns) { checkIn in
                    VStack(spacing: 4) {
                        Text("\(checkIn.level)").font(.system(size: 9, weight: .bold)).foregroundStyle(energyColor(checkIn.level))
                        RoundedRectangle(cornerRadius: 3).fill(energyColor(checkIn.level))
                            .frame(width: 28, height: max(8, CGFloat(checkIn.level) * 6))
                        Text(checkIn.timeLabel).font(.system(size: 7)).foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 80)
            ForEach(store.todayCheckIns.filter { !$0.note.isEmpty }) { checkIn in
                HStack(spacing: 6) {
                    Circle().fill(energyColor(checkIn.level)).frame(width: 6, height: 6)
                    Text("\(checkIn.timeLabel): \(checkIn.note)").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(14).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var healthKitRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "applewatch").foregroundStyle(.green)
                Text("Apple Watch").font(.headline)
                Spacer()
                if store.isSyncingHealth { ProgressView().scaleEffect(0.7) }
                else if store.healthKitConnected { Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(.green) }
            }
            if store.healthKitConnected {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        healthMetric("Sleep", value: String(format: "%.1fh", store.sleepHours), icon: "bed.double.fill", color: .indigo)
                        healthMetric("Steps", value: "\(store.stepsToday)", icon: "figure.walk", color: .green)
                        healthMetric("Calories", value: "\(store.activeCalories)", icon: "flame.fill", color: .orange)
                        healthMetric("Heart", value: "\(Int(store.heartRate))", icon: "heart.fill", color: .red)
                        healthMetric("Stand", value: "\(store.standHours)h", icon: "figure.stand", color: .blue)
                    }
                }
            } else {
                Text("Connect HealthKit to see Apple Watch data").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(14).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func healthMetric(_ label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            Text(value).font(.subheadline).fontWeight(.bold)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(width: 70).padding(.vertical, 8).background(color.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var moodAndWaterRow: some View {
        HStack(spacing: 12) {
            VStack(spacing: 8) {
                Text("Mood").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { level in
                        Button { store.send(.setMood(level)) } label: {
                            Text(moodEmoji(level)).font(.title3)
                                .opacity(store.moodToday == level ? 1 : 0.3)
                                .scaleEffect(store.moodToday == level ? 1.2 : 1)
                        }.buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity).padding(12).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(spacing: 8) {
                Text("Water").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 2) {
                    Text("\(store.waterGlasses)").font(.title2).fontWeight(.bold).foregroundStyle(.blue)
                    Text("/\(store.waterGoal)").font(.caption).foregroundStyle(.secondary)
                }
                Button { store.send(.addWater) } label: {
                    Image(systemName: "plus.circle.fill").foregroundStyle(.blue)
                }
            }
            .frame(maxWidth: .infinity).padding(12).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var weeklyEnergyChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "chart.bar.fill").foregroundStyle(.green)
                Text("7-Day Energy").font(.headline)
                Spacer()
            }
            let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<7, id: \.self) { i in
                    let avg = i < store.weeklyEnergyAverages.count ? store.weeklyEnergyAverages[i] : 0
                    VStack(spacing: 4) {
                        if avg > 0 {
                            Text(String(format: "%.0f", avg)).font(.system(size: 9, weight: .bold)).foregroundStyle(energyColor(Int(avg)))
                        }
                        RoundedRectangle(cornerRadius: 4)
                            .fill(avg > 0 ? energyColor(Int(avg)) : Color.gray.opacity(0.2))
                            .frame(height: max(4, CGFloat(avg) * 8))
                        Text(days[i]).font(.system(size: 9)).foregroundStyle(.tertiary)
                    }.frame(maxWidth: .infinity)
                }
            }.frame(height: 100)
        }
        .padding(14).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var suggestionsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lightbulb.fill").foregroundStyle(.yellow)
                Text("Recovery Tips").font(.headline)
            }
            ForEach(store.recoverySuggestions, id: \.self) { tip in
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "arrow.right.circle.fill").font(.caption2).foregroundStyle(.green).padding(.top, 2)
                    Text(tip).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(14).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var stressCard: some View {
        HStack(spacing: 12) {
            Image(systemName: store.stressLevel.icon).font(.title2).foregroundStyle(stressColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("Stress: \(store.stressLevel.rawValue)").font(.subheadline).fontWeight(.semibold)
                Text(store.stressLevel.suggestion).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var checkInSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Text("How's your energy?").font(.title2.bold())
                Text("\(store.checkInLevel)").font(.system(size: 60, weight: .bold, design: .rounded)).foregroundStyle(energyColor(store.checkInLevel))
                Slider(value: Binding(
                    get: { Double(store.checkInLevel) },
                    set: { store.send(.checkInLevelChanged(Int($0))) }
                ), in: 1...10, step: 1).tint(energyColor(store.checkInLevel)).padding(.horizontal)
                HStack {
                    Text("Drained").font(.caption).foregroundStyle(.red)
                    Spacer()
                    Text("Charged").font(.caption).foregroundStyle(.green)
                }.padding(.horizontal)
                TextField("How are you feeling? (optional)", text: $store.checkInNote.sending(\.checkInNoteChanged))
                    .textFieldStyle(.roundedBorder).padding(.horizontal)
                Spacer()
            }
            .navigationTitle("Energy Check-In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { store.send(.dismissCheckIn) } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { store.send(.submitCheckIn) }.fontWeight(.bold) }
            }
        }
        .presentationDetents([.medium])
    }

    private func energyColor(_ level: Int) -> Color {
        switch level { case 8...10: return .green; case 5...7: return .yellow; case 3...4: return .orange; default: return .red }
    }
    private func moodEmoji(_ level: Int) -> String {
        switch level { case 1: return "😩"; case 2: return "😔"; case 3: return "😐"; case 4: return "😊"; case 5: return "🔥"; default: return "😐" }
    }
    private var stressColor: Color {
        switch store.stressLevel { case .low: return .green; case .moderate: return .yellow; case .high: return .orange; case .critical: return .red }
    }
}

#Preview {
    BalanceView(
        store: Store(initialState: BalanceReducer.State()) {
            BalanceReducer()
        }
    )
}

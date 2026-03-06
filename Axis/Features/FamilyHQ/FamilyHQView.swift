import ComposableArchitecture
import PhotosUI
import SwiftUI

struct FamilyHQView: View {
    @Bindable var store: StoreOf<FamilyHQReducer>
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    // Section picker
                    Picker("Section", selection: $store.selectedSection.sending(\.sectionChanged)) {
                        ForEach(FamilyHQReducer.State.Section.allCases, id: \.self) { section in
                            Text(section.rawValue).tag(section)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    ScrollView {
                        VStack(spacing: 16) {
                            switch store.selectedSection {
                            case .calendar:
                                calendarSection
                            case .meals:
                                mealsSection
                            case .dadWins:
                                dadWinsSection
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 100)
                    }
                }
                .background(Color(.systemGroupedBackground))

                if store.showConfetti {
                    ConfettiView()
                        .allowsHitTesting(false)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Family HQ")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(.blue)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    trailingButton
                }
            }
            .sheet(isPresented: Binding(
                get: { store.showAddEvent },
                set: { _ in store.send(.toggleAddEvent) }
            )) {
                addEventSheet
            }
            .sheet(isPresented: Binding(
                get: { store.showAddDadWin },
                set: { _ in store.send(.toggleAddDadWin) }
            )) {
                addDadWinSheet
            }
            .onAppear {
                store.send(.onAppear)
            }
        }
    }

    @ViewBuilder
    private var trailingButton: some View {
        switch store.selectedSection {
        case .calendar:
            Button { store.send(.toggleAddEvent) } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.blue)
            }
        case .dadWins:
            Button { store.send(.toggleAddDadWin) } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.blue)
            }
        case .meals:
            EmptyView()
        }
    }

    // MARK: - Calendar Section

    private var calendarSection: some View {
        VStack(spacing: 16) {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Family Calendar")
                            .font(.headline)
                        Spacer()
                        Text("\(store.completedEventCount)/\(store.events.count) done")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Picker("Filter", selection: $store.eventFilter.sending(\.eventFilterChanged)) {
                        ForEach(FamilyHQReducer.State.EventFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            if !store.filteredCalendarEvents.isEmpty {
                ForEach(store.filteredCalendarEvents) { event in
                    eventCard(event)
                }
            }

            if store.events.isEmpty {
                emptyState(icon: "calendar", message: "No family events yet. Tap + to add one.")
            } else if store.filteredCalendarEvents.isEmpty {
                emptyState(icon: "line.3.horizontal.decrease.circle", message: "No events match this filter yet.")
            }
        }
    }

    private func eventCard(_ event: FamilyHQReducer.State.EventState) -> some View {
        GlassCard {
            HStack(spacing: 12) {
                Button {
                    store.send(.toggleEventCompleted(event.id))
                } label: {
                    Image(systemName: event.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(event.isCompleted ? .green : .secondary)
                }

                Image(systemName: event.categoryIcon)
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .strikethrough(event.isCompleted)
                        .foregroundStyle(event.isCompleted ? .secondary : .primary)
                    HStack(spacing: 4) {
                        Image(systemName: event.date.isToday ? "clock" : "calendar")
                            .font(.caption2)
                        Text(event.date.isToday ? event.date.timeString : event.date.shortDateString)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    store.send(.deleteEvent(event.id))
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Meals Section

    private var mealsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "fork.knife")
                    .foregroundStyle(.blue)
                Text("This Week's Dinner Plan")
                    .font(.headline)
                Spacer()
            }

            ForEach(store.mealPlan) { meal in
                GlassCard {
                    HStack(spacing: 12) {
                        Text(meal.dayLabel)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                            .frame(width: 36)

                        TextField("Plan dinner...", text: Binding(
                            get: { meal.mealName },
                            set: { newValue in
                                store.send(.mealNameChanged(dayOfWeek: meal.dayOfWeek, mealType: meal.mealType, name: newValue))
                            }
                        ))
                        .font(.subheadline)
                        .textFieldStyle(.plain)

                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Dad Wins Section

    private var dadWinsSection: some View {
        VStack(spacing: 12) {
            // Streak counter
            GlassCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dad Win Streak")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(store.dadWins.count)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                    }
                    Spacer()
                    Image(systemName: "trophy.fill")
                        .font(.title)
                        .foregroundStyle(.yellow)
                }
            }

            if store.dadWins.isEmpty {
                emptyState(icon: "heart.fill", message: "Record your dad wins — the moments that matter most.")
            } else {
                ForEach(store.dadWins) { win in
                    dadWinCard(win)
                }
            }
        }
    }

    private func dadWinCard(_ win: FamilyHQReducer.State.DadWinState) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: win.moodIcon)
                        .foregroundStyle(moodColor(win.mood))
                    Text(win.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(win.date.relativeString)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if !win.details.isEmpty {
                    Text(win.details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }

                if win.hasPhoto {
                    HStack(spacing: 4) {
                        Image(systemName: "photo.fill")
                            .font(.caption2)
                        Text("Photo attached")
                            .font(.caption2)
                    }
                    .foregroundStyle(.blue)
                }

                HStack {
                    Text(win.mood.capitalized)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(moodColor(win.mood).opacity(0.15))
                        .foregroundStyle(moodColor(win.mood))
                        .clipShape(Capsule())

                    Spacer()

                    Button {
                        store.send(.deleteDadWin(win.id))
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func moodColor(_ mood: String) -> Color {
        switch mood {
        case "proud": return .yellow
        case "grateful": return .pink
        case "joyful": return .orange
        case "peaceful": return .green
        case "accomplished": return .purple
        default: return .yellow
        }
    }

    private func emptyState(icon: String, message: String) -> some View {
        GlassCard {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Add Event Sheet

    private var addEventSheet: some View {
        NavigationStack {
            Form {
                Section("Event Details") {
                    TextField("Event title", text: $store.newEventTitle.sending(\.newEventTitleChanged))

                    Picker("Category", selection: $store.newEventCategory.sending(\.newEventCategoryChanged)) {
                        Label("Activity", systemImage: "figure.run").tag("activity")
                        Label("Appointment", systemImage: "cross.case.fill").tag("appointment")
                        Label("School", systemImage: "graduationcap.fill").tag("school")
                        Label("Meal", systemImage: "fork.knife").tag("meal")
                        Label("Outing", systemImage: "car.fill").tag("outing")
                    }

                    DatePicker("Date & Time", selection: $store.newEventDate.sending(\.newEventDateChanged))
                }
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { store.send(.toggleAddEvent) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { store.send(.addEvent) }
                        .fontWeight(.semibold)
                        .disabled(store.newEventTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Add Dad Win Sheet

    private var addDadWinSheet: some View {
        NavigationStack {
            Form {
                Section("What happened?") {
                    TextField("Title", text: $store.newDadWinTitle.sending(\.newDadWinTitleChanged))
                    TextField("Details (optional)", text: $store.newDadWinDetails.sending(\.newDadWinDetailsChanged), axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("How did it feel?") {
                    Picker("Mood", selection: $store.newDadWinMood.sending(\.newDadWinMoodChanged)) {
                        Label("Proud", systemImage: "star.fill").tag("proud")
                        Label("Grateful", systemImage: "heart.fill").tag("grateful")
                        Label("Joyful", systemImage: "face.smiling.inverse").tag("joyful")
                        Label("Peaceful", systemImage: "leaf.fill").tag("peaceful")
                        Label("Accomplished", systemImage: "trophy.fill").tag("accomplished")
                    }
                }

                Section("Add a Photo") {
                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        HStack {
                            Image(systemName: store.newDadWinPhotoData != nil ? "photo.fill" : "camera.fill")
                                .foregroundStyle(.blue)
                            Text(store.newDadWinPhotoData != nil ? "Photo selected" : "Choose from library")
                                .font(.subheadline)
                        }
                    }
                    .onChange(of: selectedPhotoItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                store.send(.newDadWinPhotoDataChanged(data))
                            }
                        }
                    }

                    if let photoData = store.newDadWinPhotoData,
                       let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button("Remove Photo", role: .destructive) {
                            selectedPhotoItem = nil
                            store.send(.newDadWinPhotoDataChanged(nil))
                        }
                        .font(.caption)
                    }
                }
            }
            .navigationTitle("New Dad Win")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        selectedPhotoItem = nil
                        store.send(.toggleAddDadWin)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { store.send(.addDadWin) }
                        .fontWeight(.semibold)
                        .disabled(store.newDadWinTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }
}

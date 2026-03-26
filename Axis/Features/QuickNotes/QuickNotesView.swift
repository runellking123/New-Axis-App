import SwiftUI
import ComposableArchitecture

struct QuickNotesView: View {
    @Bindable var store: StoreOf<QuickNotesReducer>

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Folder tabs
                folderPicker

                // Search bar
                HStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search notes...", text: $store.searchText.sending(\.searchTextChanged))
                            .textFieldStyle(.plain)
                    }
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Menu {
                        ForEach(QuickNotesReducer.State.SortOrder.allCases, id: \.self) { order in
                            Button {
                                store.send(.sortOrderChanged(order))
                            } label: {
                                HStack {
                                    Text(order.rawValue)
                                    if store.sortOrder == order {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                            .font(.title3)
                            .foregroundStyle(Color.axisGold)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 12)

                if store.filteredNotes.isEmpty {
                    emptyState
                } else {
                    notesList
                }
            }
            .navigationTitle("Quick Notes")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.send(.showAddSheet)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.axisGold)
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { store.showAddSheet },
                set: { newValue in
                    if !newValue { store.send(.dismissSheet) }
                }
            )) {
                NoteEditorSheet(store: store)
            }
            .onAppear {
                store.send(.onAppear)
            }
        }
    }

    // MARK: - Folder Picker

    private var folderPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(QuickNotesReducer.State.Folder.allCases, id: \.self) { folder in
                    let isSelected = store.selectedFolder == folder
                    let count = store.state.noteCount(for: folder)
                    Button {
                        store.send(.selectedFolderChanged(folder))
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: folder.icon)
                                .font(.caption)
                            Text(folder.rawValue)
                                .font(.subheadline.weight(.medium))
                            if count > 0 {
                                Text("\(count)")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(isSelected ? Color.white.opacity(0.3) : Color.secondary.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(isSelected ? Color.axisGold : Color.clear)
                        .foregroundStyle(isSelected ? .white : .primary)
                        .clipShape(Capsule())
                        .overlay {
                            if !isSelected {
                                Capsule().stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "note.text.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(Color.axisGold.opacity(0.5))
            Text(store.selectedFolder == .all ? "No Notes Yet" : "No \(store.selectedFolder.rawValue) Notes")
                .font(.title2.bold())
            Text("Tap + to jot down your first note")
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Notes List

    private var notesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                let notes = store.filteredNotes
                let pinned = notes.filter(\.isPinned)
                let unpinned = notes.filter { !$0.isPinned }

                if !pinned.isEmpty {
                    sectionHeader("Pinned")
                    ForEach(pinned) { note in
                        noteCard(note)
                    }
                }

                if !unpinned.isEmpty {
                    if !pinned.isEmpty {
                        sectionHeader("Notes")
                    }
                    ForEach(unpinned) { note in
                        noteCard(note)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.top, 4)
    }

    private func noteCard(_ note: QuickNotesReducer.State.NoteItem) -> some View {
        Button {
            store.send(.editNote(note))
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Color strip
                RoundedRectangle(cornerRadius: 2)
                    .fill(colorForName(note.color))
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(note.displayTitle)
                            .font(.headline)
                            .lineLimit(1)

                        Spacer()

                        if note.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption)
                                .foregroundStyle(Color.axisGold)
                        }
                    }

                    if !note.preview.isEmpty {
                        Text(note.preview)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    HStack(spacing: 8) {
                        // Folder badge
                        if let folder = QuickNotesReducer.State.Folder(rawValue: note.folder), folder != .all {
                            HStack(spacing: 3) {
                                Image(systemName: folder.icon)
                                    .font(.caption2)
                                Text(folder.rawValue)
                                    .font(.caption2)
                            }
                            .foregroundStyle(Color.axisGold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.axisGold.opacity(0.12))
                            .clipShape(Capsule())
                        }

                        Text(note.updatedAt, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                store.send(.togglePin(note))
            } label: {
                Label(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash" : "pin")
            }
            Button {
                store.send(.editNote(note))
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive) {
                store.send(.deleteNote(note))
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                store.send(.deleteNote(note))
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                store.send(.togglePin(note))
            } label: {
                Label(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash" : "pin")
            }
            .tint(Color.axisGold)
        }
    }

    private func colorForName(_ name: String) -> Color {
        switch name {
        case "yellow": return .yellow
        case "blue": return .blue
        case "green": return .green
        case "pink": return .pink
        case "purple": return .purple
        case "orange": return .orange
        case "red": return .red
        default: return .yellow
        }
    }
}

// MARK: - Note Editor Sheet

struct NoteEditorSheet: View {
    @Bindable var store: StoreOf<QuickNotesReducer>
    @FocusState private var focusedField: Field?

    enum Field { case title, content }

    private let colors = ["yellow", "blue", "green", "pink", "purple", "orange", "red"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title field
                    TextField("Title (optional)", text: $store.formTitle.sending(\.formTitleChanged))
                        .font(.title2.bold())
                        .focused($focusedField, equals: .title)

                    // Folder picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Folder")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 10) {
                            ForEach(QuickNotesReducer.State.Folder.assignable, id: \.self) { folder in
                                let isSelected = store.formFolder == folder
                                Button {
                                    store.send(.formFolderChanged(folder))
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: folder.icon)
                                            .font(.caption)
                                        Text(folder.rawValue)
                                            .font(.subheadline.weight(.medium))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(isSelected ? Color.axisGold : Color.clear)
                                    .foregroundStyle(isSelected ? .white : .primary)
                                    .clipShape(Capsule())
                                    .overlay {
                                        if !isSelected {
                                            Capsule().stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Color picker
                    HStack(spacing: 12) {
                        Text("Color")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ForEach(colors, id: \.self) { color in
                            Button {
                                store.send(.formColorChanged(color))
                            } label: {
                                Circle()
                                    .fill(colorForName(color))
                                    .frame(width: 28, height: 28)
                                    .overlay {
                                        if store.formColor == color {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                        }
                    }

                    // Content editor
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Note")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $store.formContent.sending(\.formContentChanged))
                            .focused($focusedField, equals: .content)
                            .frame(minHeight: 250)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    if let editing = store.editingNote {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Created \(editing.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Text("Updated \(editing.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding()
            }
            .navigationTitle(store.editingNote == nil ? "New Note" : "Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        store.send(.dismissSheet)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.send(.saveNote)
                    }
                    .bold()
                    .disabled(store.formTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                              store.formContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                focusedField = store.editingNote == nil ? .content : nil
            }
        }
    }

    private func colorForName(_ name: String) -> Color {
        switch name {
        case "yellow": return .yellow
        case "blue": return .blue
        case "green": return .green
        case "pink": return .pink
        case "purple": return .purple
        case "orange": return .orange
        case "red": return .red
        default: return .yellow
        }
    }
}

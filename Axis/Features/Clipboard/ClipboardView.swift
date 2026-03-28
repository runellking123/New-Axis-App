import SwiftUI
import ComposableArchitecture

struct ClipboardView: View {
    @Bindable var store: StoreOf<ClipboardReducer>

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ClipboardReducer.State.Filter.allCases, id: \.self) { filter in
                            let isSelected = store.selectedFilter == filter
                            Button { store.send(.filterChanged(filter)) } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: filter.icon)
                                        .font(.caption)
                                    Text(filter.rawValue)
                                        .font(.subheadline.weight(.medium))
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
                    .padding(.vertical, 8)
                }

                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search clips...", text: $store.searchText.sending(\.searchTextChanged))
                        .textFieldStyle(.plain)
                }
                .padding(10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
                .padding(.bottom, 12)

                if store.filteredItems.isEmpty {
                    emptyState
                } else {
                    clipList
                }
            }
            .navigationTitle("Clipboard")
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { store.send(.showAddSheet) } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.axisGold)
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { store.showAddSheet },
                set: { if !$0 { store.send(.dismissSheet) } }
            )) {
                ClipEditorSheet(store: store)
            }
            .onAppear { store.send(.onAppear) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 60))
                .foregroundStyle(Color.axisGold.opacity(0.5))
            Text("No Saved Clips")
                .font(.title2.bold())
            Text("Save links, snippets, and text for later")
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var clipList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(store.filteredItems) { item in
                    clipCard(item)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    private func clipCard(_ item: ClipboardReducer.State.ClipItem) -> some View {
        Button { store.send(.editItem(item)) } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: item.icon)
                        .foregroundStyle(Color.axisGold)
                    Text(item.displayTitle)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }

                if item.isLink {
                    Text(item.content)
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .lineLimit(1)
                } else {
                    Text(item.content)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack {
                    if !item.tags.isEmpty {
                        ForEach(item.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.axisGold.opacity(0.12))
                                .foregroundStyle(Color.axisGold)
                                .clipShape(Capsule())
                        }
                    }
                    Spacer()
                    Text(item.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { store.send(.toggleFavorite(item)) } label: {
                Label(item.isFavorite ? "Unfavorite" : "Favorite", systemImage: item.isFavorite ? "star.slash" : "star")
            }
            if item.isLink {
                Button {
                    if let url = URL(string: item.content) {
                        #if canImport(UIKit)
                        UIApplication.shared.open(url)
                        #endif
                    }
                } label: {
                    Label("Open Link", systemImage: "safari")
                }
            }
            Button {
                #if canImport(UIKit)
                UIPasteboard.general.string = item.content
                #endif
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            Divider()
            Button(role: .destructive) { store.send(.deleteItem(item)) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { store.send(.deleteItem(item)) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button { store.send(.toggleFavorite(item)) } label: {
                Label("Favorite", systemImage: "star")
            }
            .tint(.yellow)
        }
    }
}

// MARK: - Editor Sheet

struct ClipEditorSheet: View {
    @Bindable var store: StoreOf<ClipboardReducer>

    private let types = [("text", "Text"), ("link", "Link"), ("snippet", "Snippet")]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Paste button
                    if store.editingItem == nil {
                        Button { store.send(.pasteFromClipboard) } label: {
                            Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                                .font(.subheadline)
                                .foregroundStyle(Color.axisGold)
                                .padding(10)
                                .frame(maxWidth: .infinity)
                                .background(Color.axisGold.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    // Title
                    TextField("Title (optional)", text: $store.formTitle.sending(\.formTitleChanged))
                        .font(.title2.bold())

                    // Type picker
                    HStack(spacing: 10) {
                        Text("Type")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ForEach(types, id: \.0) { type in
                            let isSelected = store.formType == type.0
                            Button { store.send(.formTypeChanged(type.0)) } label: {
                                Text(type.1)
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(isSelected ? Color.axisGold : Color.clear)
                                    .foregroundStyle(isSelected ? .white : .primary)
                                    .clipShape(Capsule())
                                    .overlay {
                                        if !isSelected { Capsule().stroke(Color.secondary.opacity(0.3), lineWidth: 1) }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Content
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Content")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $store.formContent.sending(\.formContentChanged))
                            .frame(minHeight: 150)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Tags
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tags (comma-separated)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("work, reference, important", text: $store.formTags.sending(\.formTagsChanged))
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding()
            }
            .navigationTitle(store.editingItem == nil ? "New Clip" : "Edit Clip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { store.send(.dismissSheet) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { store.send(.saveItem) }
                        .bold()
                        .disabled(store.formContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    ClipboardView(
        store: Store(initialState: ClipboardReducer.State()) {
            ClipboardReducer()
        }
    )
}

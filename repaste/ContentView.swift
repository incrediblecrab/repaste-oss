//
//  ContentView.swift
//  Repaste
//

import SwiftUI
import SwiftData
import AppKit

struct ToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.2 : 1)
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Query private var pastes: [Phrase]

    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("windowHeight") private var windowHeight: Double = 400

    @State private var searchText = ""
    @State private var isSearching = false
    @State private var isReady = false
    @State private var selectedTag: String?

    // All unique tags across phrases
    private var allTags: [String] {
        Array(Set(pastes.flatMap { $0.tags })).sorted()
    }

    // Pinned first (by pinnedAt desc), then unpinned (by order)
    private var sortedPastes: [Phrase] {
        let pinned = pastes.filter { $0.isPinned }.sorted { ($0.pinnedAt ?? .distantPast) > ($1.pinnedAt ?? .distantPast) }
        let unpinned = pastes.filter { !$0.isPinned }.sorted { $0.order < $1.order }
        return pinned + unpinned
    }

    private var filteredPastes: [Phrase] {
        var result = sortedPastes

        // Filter by tag
        if let tag = selectedTag {
            result = result.filter { $0.tags.contains(tag) }
        }

        // Filter by search
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.content.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            Divider()

            if sortedPastes.isEmpty {
                emptyState
            } else if filteredPastes.isEmpty {
                noResultsState
            } else {
                pasteList
            }
        }
        .frame(width: 300, height: windowHeight)
        .background(appearanceMode.isSolid ? Color(nsColor: .windowBackgroundColor) : Color.clear)
        .onAppear {
            AppState.updateAppearance()
            // Delay to allow window to fully render before enabling interactions
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isReady = true
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack {
            Spacer()
            Image(systemName: "sparkle.text.clipboard")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No pastes yet")
                .font(.headline)
                .padding(.top)
            Text("Click + to add your first paste")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var noResultsState: some View {
        VStack {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No results")
                .font(.headline)
                .padding(.top)
            Text("Try a different search term")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Paste List

    private var pasteList: some View {
        List {
            ForEach(filteredPastes) { paste in
                PasteRowView(paste: paste, onCopy: {
                    closePopover()
                }, onEdit: {
                    AppState.shared.startEditing(paste)
                    openWindow(id: "paste-editor")
                }, onMoveUp: {
                    movePaste(paste, direction: -1)
                }, onMoveDown: {
                    movePaste(paste, direction: 1)
                })
                .listRowInsets(EdgeInsets())
                .listRowSeparatorTint(.primary.opacity(0.15))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.horizontal, .zero, for: .scrollContent)
    }

    private func movePaste(_ paste: Phrase, direction: Int) {
        if paste.isPinned {
            // Move within pinned section by swapping pinnedAt dates
            let pinned = pastes.filter { $0.isPinned }.sorted { ($0.pinnedAt ?? .distantPast) > ($1.pinnedAt ?? .distantPast) }
            guard let currentIndex = pinned.firstIndex(where: { $0.id == paste.id }) else { return }
            let newIndex = currentIndex + direction
            guard newIndex >= 0, newIndex < pinned.count else { return }

            let other = pinned[newIndex]
            let tempDate = paste.pinnedAt
            paste.pinnedAt = other.pinnedAt
            other.pinnedAt = tempDate
        } else {
            // Move within unpinned section by swapping order
            let unpinned = pastes.filter { !$0.isPinned }.sorted { $0.order < $1.order }
            guard let currentIndex = unpinned.firstIndex(where: { $0.id == paste.id }) else { return }
            let newIndex = currentIndex + direction
            guard newIndex >= 0, newIndex < unpinned.count else { return }

            let other = unpinned[newIndex]
            let tempOrder = paste.order
            paste.order = other.order
            other.order = tempOrder
        }
        AppState.save(modelContext, operation: "move paste")
    }

    private func closePopover() {
        NSApplication.shared.keyWindow?.close()
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            if isSearching {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search", text: $searchText)
                        .textFieldStyle(.plain)
                    Button {
                        withAnimation(.snappy(duration: 0.15)) {
                            isSearching = false
                            searchText = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(ToolbarButtonStyle())
                }
            } else {
                Button(action: addPaste) {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(ToolbarButtonStyle())
                .help("Add new paste")
                .disabled(!isReady)
                .opacity(isReady ? 1 : 0.3)

                Spacer()

                Button {
                    withAnimation(.snappy(duration: 0.15)) {
                        isSearching = true
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(ToolbarButtonStyle())
                .help("Search")
                .disabled(!isReady || pastes.isEmpty)
                .opacity(isReady ? (pastes.isEmpty ? 0.3 : 1) : 0.3)

                Menu {
                    Button {
                        selectedTag = nil
                    } label: {
                        HStack {
                            Text("All")
                            if selectedTag == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    if !allTags.isEmpty {
                        Divider()

                        ForEach(allTags, id: \.self) { tag in
                            Button {
                                selectedTag = tag
                            } label: {
                                HStack {
                                    Text(tag)
                                    if selectedTag == tag {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: selectedTag != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .opacity(isReady ? (allTags.isEmpty ? 0.3 : 1) : 0.3)
                }
                .buttonStyle(ToolbarButtonStyle())
                .help("Filter by tag")
                .disabled(!isReady || allTags.isEmpty)

                Button {
                    closePopover()
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "floating-paste")
                } label: {
                    Image(systemName: "macwindow.and.pointer.arrow")
                }
                .buttonStyle(ToolbarButtonStyle())
                .help("Pop out window")
                .disabled(!isReady)
                .opacity(isReady ? 1 : 0.3)

                Button {
                    closePopover()
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "settings")
                } label: {
                    Image(systemName: "gear")
                }
                .buttonStyle(ToolbarButtonStyle())
                .help("Settings")
                .disabled(!isReady)
                .opacity(isReady ? 1 : 0.3)
            }
        }
        .padding()
    }

    // MARK: - Actions

    private func addPaste() {
        // Close existing paste-editor window if open
        for window in NSApp.windows where window.identifier?.rawValue == "paste-editor" {
            window.close()
        }
        closePopover()
        NSApp.activate(ignoringOtherApps: true)
        AppState.shared.startAdding()
        openWindow(id: "paste-editor")
    }
}

// MARK: - Floating Window Wrapper

struct FloatingContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Query private var pastes: [Phrase]

    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system

    @State private var searchText = ""
    @State private var isSearching = false
    @State private var selectedTag: String?

    private var allTags: [String] {
        Array(Set(pastes.flatMap { $0.tags })).sorted()
    }

    private var sortedPastes: [Phrase] {
        let pinned = pastes.filter { $0.isPinned }.sorted { ($0.pinnedAt ?? .distantPast) > ($1.pinnedAt ?? .distantPast) }
        let unpinned = pastes.filter { !$0.isPinned }.sorted { $0.order < $1.order }
        return pinned + unpinned
    }

    private var filteredPastes: [Phrase] {
        var result = sortedPastes
        if let tag = selectedTag {
            result = result.filter { $0.tags.contains(tag) }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.content.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            floatingToolbar
            Divider()
            if sortedPastes.isEmpty {
                emptyState
            } else if filteredPastes.isEmpty {
                noResultsState
            } else {
                pasteList
            }
        }
        .frame(minWidth: 300, idealWidth: 350, maxWidth: .infinity, minHeight: 300, idealHeight: 500, maxHeight: .infinity)
        .modifier(FloatingGlassModifier(isSolid: appearanceMode.isSolid))
        .background(FloatingWindowConfigurator(isSolid: appearanceMode.isSolid))
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Image(systemName: "sparkle.text.clipboard")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No pastes yet")
                .font(.headline)
                .padding(.top)
            Text("Click + to add your first paste")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var noResultsState: some View {
        VStack {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No results")
                .font(.headline)
                .padding(.top)
            Text("Try a different search term")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var pasteList: some View {
        List {
            ForEach(filteredPastes) { paste in
                PasteRowView(paste: paste, onCopy: {}, onEdit: {
                    AppState.shared.startEditing(paste)
                    openWindow(id: "paste-editor")
                }, onMoveUp: {
                    movePaste(paste, direction: -1)
                }, onMoveDown: {
                    movePaste(paste, direction: 1)
                })
                .listRowInsets(EdgeInsets())
                .listRowSeparatorTint(.primary.opacity(0.15))
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.horizontal, .zero, for: .scrollContent)
    }

    private func movePaste(_ paste: Phrase, direction: Int) {
        if paste.isPinned {
            let pinned = pastes.filter { $0.isPinned }.sorted { ($0.pinnedAt ?? .distantPast) > ($1.pinnedAt ?? .distantPast) }
            guard let currentIndex = pinned.firstIndex(where: { $0.id == paste.id }) else { return }
            let newIndex = currentIndex + direction
            guard newIndex >= 0, newIndex < pinned.count else { return }
            let other = pinned[newIndex]
            let tempDate = paste.pinnedAt
            paste.pinnedAt = other.pinnedAt
            other.pinnedAt = tempDate
        } else {
            let unpinned = pastes.filter { !$0.isPinned }.sorted { $0.order < $1.order }
            guard let currentIndex = unpinned.firstIndex(where: { $0.id == paste.id }) else { return }
            let newIndex = currentIndex + direction
            guard newIndex >= 0, newIndex < unpinned.count else { return }
            let other = unpinned[newIndex]
            let tempOrder = paste.order
            paste.order = other.order
            other.order = tempOrder
        }
        AppState.save(modelContext, operation: "move paste")
    }

    private var floatingToolbar: some View {
        HStack(spacing: 12) {
            if isSearching {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search", text: $searchText)
                        .textFieldStyle(.plain)
                    Button {
                        withAnimation(.snappy(duration: 0.15)) {
                            isSearching = false
                            searchText = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(ToolbarButtonStyle())
                }
            } else {
                Button {
                    AppState.shared.startAdding()
                    openWindow(id: "paste-editor")
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(ToolbarButtonStyle())
                .help("Add new paste")

                Spacer()

                Button {
                    withAnimation(.snappy(duration: 0.15)) {
                        isSearching = true
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(ToolbarButtonStyle())
                .help("Search")
                .disabled(pastes.isEmpty)
                .opacity(pastes.isEmpty ? 0.3 : 1)

                Menu {
                    Button {
                        selectedTag = nil
                    } label: {
                        HStack {
                            Text("All")
                            if selectedTag == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    if !allTags.isEmpty {
                        Divider()
                        ForEach(allTags, id: \.self) { tag in
                            Button {
                                selectedTag = tag
                            } label: {
                                HStack {
                                    Text(tag)
                                    if selectedTag == tag {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: selectedTag != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .opacity(allTags.isEmpty ? 0.3 : 1)
                }
                .buttonStyle(ToolbarButtonStyle())
                .help("Filter by tag")
                .disabled(allTags.isEmpty)
            }
        }
        .padding()
    }
}

/// Applies Liquid Glass effect for glass modes, solid background for solid modes
struct FloatingGlassModifier: ViewModifier {
    var isSolid: Bool

    func body(content: Content) -> some View {
        if isSolid {
            content
                .background(Color(nsColor: .windowBackgroundColor))
        } else {
            if #available(macOS 26.0, *) {
                content
                    .glassEffect(.regular, in: .rect)
            } else {
                content
                    .background(.ultraThinMaterial)
            }
        }
    }
}

/// Configures window to be floating (always on top) and draggable
struct FloatingWindowConfigurator: NSViewRepresentable {
    var isSolid: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        configureWindow(view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        configureWindow(nsView)
    }

    private func configureWindow(_ view: NSView) {
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.level = .floating
            window.isMovableByWindowBackground = false
            window.isOpaque = isSolid
            window.backgroundColor = isSolid ? .windowBackgroundColor : .clear
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Phrase.self, Tag.self, UsageEvent.self], inMemory: true)
}

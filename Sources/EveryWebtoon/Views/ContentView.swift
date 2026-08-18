import SwiftUI

struct ContentView: View {
    @AppStorage("sidebarVisible") private var sidebarVisible = true
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var selectedItem: SidebarItem? = SidebarItem.all.first
    @StateObject private var searchVM = SearchViewModel()
    @FocusState private var searchFieldFocused: Bool
    @State private var detailPath: [Webtoon] = []

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selectedItem: $selectedItem)
        } detail: {
            NavigationStack(path: $detailPath) {
                Group {
                    if searchVM.isActive {
                        SearchResultsView(searchVM: searchVM) { webtoon in
                            searchVM.recordQuery(searchVM.query)
                            detailPath.append(webtoon)
                        }
                    } else if searchFieldFocused {
                        SearchRecentsView(searchVM: searchVM)
                    } else if let item = selectedItem {
                        detailView(for: item)
                            .id(item.id)
                    }
                }
                .frame(minWidth: 500)
                .navigationDestination(for: Webtoon.self) { webtoon in
                    WebtoonDetailView(webtoon: webtoon)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItem(placement: .principal) {
                SearchField(searchVM: searchVM, isFocused: $searchFieldFocused)
                    .frame(width: 300)
            }
        }
        .onChange(of: sidebarVisible) { _, visible in
            columnVisibility = visible ? .all : .detailOnly
        }
        .onAppear {
            searchFieldFocused = false
        }
        .task {
            try? await Task.sleep(for: .milliseconds(300))
            searchFieldFocused = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusSearch)) { _ in
            searchFieldFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
            sidebarVisible.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateSidebar)) { note in
            if let item = note.object as? SidebarItem {
                detailPath = []
                selectedItem = item
            }
        }
    }

    @ViewBuilder
    private func detailView(for item: SidebarItem) -> some View {
        switch item.id {
        case "library", "recent":
            LibraryView(item: item) { webtoon in
                detailPath.append(webtoon)
            }
        default:
            if item.id.hasPrefix("collection-") {
                LibraryView(item: item) { webtoon in
                    detailPath.append(webtoon)
                }
            } else {
                DiscoverView(item: item) { webtoon in
                    detailPath.append(webtoon)
                }
            }
        }
    }
}
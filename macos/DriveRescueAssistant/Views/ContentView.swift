import SwiftUI

struct ContentView: View {
    @Bindable var store: DriveStore

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            DetailView(store: store)
        }
        .task {
            await store.refresh()
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    Task { await store.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh drives")
                .disabled(store.isRefreshing)
            }
        }
    }
}

import AppKit
import SwiftUI

@main
struct DriveRescueAssistantApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = DriveStore(projectRoot: ProjectPaths.projectRoot)

    var body: some Scene {
        WindowGroup("Drive Rescue Assistant", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 920, minHeight: 580)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Refresh Drives") {
                    Task { await store.refresh() }
                }
                .keyboardShortcut("r")
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

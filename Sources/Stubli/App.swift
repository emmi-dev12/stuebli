import SwiftUI
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    weak var store: EditorStore?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { NSApp.windows.first?.delegate = self }
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply { store?.confirmLeaving() == false ? .terminateCancel : .terminateNow }
    func windowShouldClose(_ sender: NSWindow) -> Bool { store?.confirmLeaving() ?? true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
@main
struct StubliApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var store = EditorStore()
    var body: some Scene {
        Window("Stübli", id: "editor") {
            EditorView().environmentObject(store).onAppear { delegate.store = store }
        }
        .defaultSize(width: 1320, height: 850)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Example Room") { store.newRoom() }.keyboardShortcut("n")
                Button("Open Room…") { store.open() }.keyboardShortcut("o")
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save") { store.save() }.keyboardShortcut("s")
                Button("Save As…") { store.save(copy: true) }.keyboardShortcut("s", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .undoRedo) {
                Button("Undo Scene Edit") { store.undo() }.keyboardShortcut("z").disabled(store.history.isEmpty)
                Button("Redo Scene Edit") { store.redo() }.keyboardShortcut("z", modifiers: [.command,.shift]).disabled(store.future.isEmpty)
            }
        }
    }
}

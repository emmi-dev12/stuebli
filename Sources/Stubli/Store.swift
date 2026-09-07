import AppKit
import SwiftUI
import StubliCore

@MainActor
final class EditorStore: ObservableObject {
    @Published var document = SceneDocument.sample
    @Published var selected: String?
    @Published var mode = "Plan"
    @Published var sidebar = "Objects"
    @Published var error: String?
    @Published var status = "Example measurements — replace with your room."
    @Published var conflict = false
    @Published var url: URL?
    @Published var history: [SceneDocument] = []
    @Published var future: [SceneDocument] = []
    @Published var routes: [RouteResult] = []
    @Published var checking = false
    @Published var cameraReset = 0
    @Published var comparison: SceneDocument?
    private var saved: SceneDocument?
    private var diskData: Data?
    private var timer: Timer?
    var dirty: Bool { document != saved }
    var item: Item? { document.items.first { $0.id == selected } }
    var issues: [String] { document.warnings() }

    init() {
        do {
            let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Stuebli", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let target = folder.appendingPathComponent("Bedroom.stubli.json")
            if FileManager.default.fileExists(atPath: target.path) { try load(target) }
            else { try SceneIO.commit(document, to: target, expected: nil); try load(target) }
        } catch { self.error = error.localizedDescription }
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
    }
    func checkpoint() { history.append(document); if history.count > 100 { history.removeFirst() }; future = [] }
    func change(_ operation: (inout SceneDocument) -> Void, record: Bool = true) {
        var draft = document; operation(&draft)
        do { try draft.validate() } catch { self.error = error.localizedDescription; return }
        guard draft != document else { return }
        if record { checkpoint() }
        document = draft; routes = []; status = "Unsaved changes"
    }
    func undo() { guard let last = history.popLast() else { return }; future.append(document); document = last; routes = []; status = dirty ? "Unsaved changes" : "Saved · \(url?.lastPathComponent ?? "Room")" }
    func redo() { guard let next = future.popLast() else { return }; history.append(document); document = next; routes = []; status = dirty ? "Unsaved changes" : "Saved · \(url?.lastPathComponent ?? "Room")" }
    func add(_ product: CatalogProduct) {
        let item = product.makeItem(); change { $0.items.append(item) }; selected = item.id; sidebar = "Objects"
    }
    func addPerson() {
        var person = Item.generic("person"); person.name = "Person \(document.items.filter { $0.kind == "person" }.count + 1)"
        change { $0.items.append(person) }; selected = person.id
    }
    func deleteSelection() { guard let id = selected else { return }; change { $0.items.removeAll { $0.id == id } }; selected = nil }
    func duplicateSelection() {
        guard var copy = item else { return }; copy.id = UUID().uuidString.lowercased(); copy.x += 0.15; copy.z -= 0.15
        change { $0.items.append(copy) }; selected = copy.id
    }
    func update(_ item: Item) { change { doc in if let i = doc.items.firstIndex(where: { $0.id == item.id }) { doc.items[i] = item } } }
    func move(_ id: String, x: Double, z: Double) {
        change({ doc in
            guard let i = doc.items.firstIndex(where: { $0.id == id }) else { return }
            doc.items[i].x = (x * 100).rounded() / 100; doc.items[i].z = (z * 100).rounded() / 100
        }, record: false)
    }
    func load(_ target: URL) throws {
        let data = try Data(contentsOf: target)
        let doc = try JSONDecoder().decode(SceneDocument.self, from: data); try doc.validate()
        document = doc; saved = doc; diskData = data; url = target
        selected = nil; history = []; future = []; routes = []; comparison = nil; conflict = false
        status = "Saved · \(target.lastPathComponent)"
    }
    @discardableResult func save(copy: Bool = false) -> Bool {
        var target = url
        var expected = diskData
        if copy || target == nil {
            let panel = NSSavePanel(); panel.nameFieldStringValue = "Bedroom.stubli.json"; panel.allowedContentTypes = [.json]
            guard panel.runModal() == .OK, let choice = panel.url else { return false }
            target = choice; expected = try? Data(contentsOf: choice)
        }
        do {
            try SceneIO.commit(document, to: target!, expected: expected)
            url = target; diskData = try SceneIO.encode(document); saved = document; conflict = false
            status = "Saved · \(target!.lastPathComponent)"; return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func confirmLeaving() -> Bool {
        guard dirty else { return true }
        let alert = NSAlert(); alert.messageText = "Save changes to this room?"
        alert.informativeText = "Your changes haven't been written to the scene file."
        alert.addButton(withTitle: "Save"); alert.addButton(withTitle: "Cancel"); alert.addButton(withTitle: "Discard Changes")
        switch alert.runModal() { case .alertFirstButtonReturn: return save(); case .alertThirdButtonReturn: return true; default: return false }
    }
    func open() {
        guard confirmLeaving() else { return }
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let target = panel.url { do { try load(target) } catch { self.error = error.localizedDescription } }
    }
    func newRoom() {
        guard confirmLeaving() else { return }
        document = .sample; selected = nil; saved = nil; diskData = nil; url = nil; history = []; future = []; routes = []; comparison = nil; conflict = false
        status = "New example room — save a copy to begin."
    }
    func poll() {
        guard let url else { return }
        guard let data = try? Data(contentsOf: url) else {
            if !conflict { conflict = true; status = "Scene file unavailable. Save a copy or restore the file." }; return
        }
        guard data != diskData else { return }
        if dirty { conflict = true; status = "External edit detected. Reload or save your version as a copy."; return }
        do { try load(url); status = "Reloaded external agent edit" }
        catch { if !conflict { conflict = true; self.error = "External edit is invalid: \(error.localizedDescription)" } }
    }
    func reload() {
        guard let url, confirmLeaving() else { return }
        do { try load(url) } catch { self.error = error.localizedDescription }
    }
    func copyAgentPath() {
        guard let url else { error = "Save this room first so an agent can open it."; return }
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(url.path, forType: .string)
        status = "Scene path copied. Save local changes before agent edits."
    }
    func compare() {
        if let other = comparison {
            let current = document; change { $0 = other }; comparison = current; selected = nil
            status = "Swapped with comparison layout"
        } else { comparison = document; status = "Comparison captured. Rearrange, then swap to compare." }
    }
    func checkRoutes() {
        guard !checking else { return }
        guard max(document.room.width, document.room.depth) <= 15, document.items.count <= 100 else { error = "Route checking currently supports rooms up to 15 m and 100 objects."; return }
        let doc = document, people = doc.items.filter { $0.kind == "person" }
        guard !people.isEmpty else { error = "Add a person, then check their route to the door."; return }
        checking = true
        Task {
            let results = await Task.detached { people.map { Routes.toDoor(in: doc, person: $0) } }.value
            checking = false
            guard document == doc else { status = "Room changed during the check. Run it again."; return }
            routes = results; sidebar = "Checks"; mode = "Plan"
        }
    }
}

import SwiftUI
import StubliCore

// Explicit property-wrapper alias avoids the SDK 27 State macro in CLI-only toolchains.
typealias LegacyState<Value> = SwiftUI.State<Value>

let pine = Color(red: 0.16, green: 0.34, blue: 0.29)
func icon(_ kind: String) -> String {
    switch kind {
    case "bed": "bed.double"
    case "desk": "desktopcomputer"
    case "chair": "chair"
    case "person": "person"
    case "bedside", "chest": "archivebox"
    default: "cabinet"
    }
}
func measure(_ number: Double) -> String { number.formatted(.number.precision(.fractionLength(0...3))) }

struct EditorView: View {
    @EnvironmentObject var store: EditorStore
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 18) {
                HStack(spacing: 8) { Image(systemName: "cube.transparent").font(.title2); Text("Stübli").font(.title2.weight(.semibold)) }.foregroundStyle(pine)
                Divider().frame(height: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.document.name).font(.headline)
                    Text("\(measure(store.document.room.width)) × \(measure(store.document.room.depth)) m · \(measure(store.document.room.width * store.document.room.depth)) m²")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Picker("View", selection: $store.mode) { Text("Plan").tag("Plan"); Text("3D").tag("3D"); Text("Walk").tag("Walk") }
                    .pickerStyle(.segmented).frame(width: 216)
                Button { store.cameraReset += 1 } label: { Image(systemName: "viewfinder") }.help("Reset view").accessibilityLabel("Reset view")
                Button { store.save() } label: { Label(store.dirty ? "Save changes" : "Saved", systemImage: store.dirty ? "square.and.arrow.down" : "checkmark") }
                    .buttonStyle(.borderedProminent).tint(pine).disabled(!store.dirty)
            }.padding(.horizontal, 20).padding(.vertical, 13)
            Divider()
            HStack(spacing: 0) {
                LibrarySidebar().frame(width: 252)
                Divider()
                VStack(spacing: 0) {
                    HStack {
                        Label(store.mode == "Plan" ? "Floor plan" : store.mode == "Walk" ? "Eye-level walkthrough" : "Room model", systemImage: store.mode == "Plan" ? "square.split.2x2" : "cube")
                            .font(.headline)
                        Spacer()
                        Button(store.comparison == nil ? "Capture layout" : "Swap layouts") { store.compare() }
                            .help("Capture a layout, make changes, then swap to compare. Save As keeps a permanent copy.")
                    }.padding(16)
                    ZStack(alignment: .bottomLeading) {
                        if store.mode == "Plan" { PlanView() }
                        else { RoomSceneView(store: store).id("scene") }
                        Text(store.mode == "Plan" ? "Drag objects · 1 cm snap · north ↑" : store.mode == "Walk" ? "Click view · W/S move · A/D turn · drag to look · R resets" : "Drag empty space to orbit · scroll to zoom · click objects to select")
                            .font(.caption).foregroundStyle(.secondary).padding(9).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6)).padding(14)
                            .allowsHitTesting(false)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                        Text("Catalog dimensions verified · 3D shapes approximate")
                        Spacer(minLength: 0)
                    }.font(.caption).foregroundStyle(.secondary).padding(12)
                }.frame(minWidth: 480)
                Divider()
                Inspector().frame(width: 260)
            }
            Divider()
            HStack(spacing: 12) {
                Circle().fill(store.conflict ? Color.orange : store.dirty ? Color.orange : pine).frame(width: 6, height: 6)
                Text(store.status).lineLimit(1)
                Spacer()
                if store.conflict {
                    Button("Reload…") { store.reload() }
                    Button("Save a copy…") { store.save(copy: true) }
                }
                Button { store.undo() } label: { Image(systemName: "arrow.uturn.backward") }.disabled(store.history.isEmpty).help("Undo scene edit").accessibilityLabel("Undo scene edit")
                Button { store.redo() } label: { Image(systemName: "arrow.uturn.forward") }.disabled(store.future.isEmpty).help("Redo scene edit").accessibilityLabel("Redo scene edit")
                Button("Agent file path") { store.copyAgentPath() }.help("Copy the local scene file path for Codex or Claude")
            }.font(.caption).padding(.horizontal, 16).padding(.vertical, 9)
        }
        .frame(minWidth: 1060, minHeight: 720)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(pine)
        .alert("Stübli", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("OK") { store.error = nil }
        } message: { Text(store.error ?? "") }
    }
}

struct LibrarySidebar: View {
    @EnvironmentObject var store: EditorStore
    @LegacyState private var search = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("Sidebar", selection: $store.sidebar) {
                Text("Objects").tag("Objects"); Text("IKEA").tag("IKEA"); Text("Checks").tag("Checks")
            }.pickerStyle(.segmented).padding(12)
            if store.sidebar == "Objects" {
                HStack { Text("In your room").font(.headline); Spacer(); Text("\(store.document.items.count)").foregroundStyle(.secondary) }.padding(.horizontal, 16).padding(.vertical, 10)
                List(selection: $store.selected) {
                    ForEach(store.document.items) { item in
                        HStack(spacing: 10) {
                            Image(systemName: icon(item.kind)).frame(width: 24).foregroundStyle(pine)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.name).lineLimit(2)
                                Text("\(measure(item.width)) × \(measure(item.depth)) m").font(.caption).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 5).tag(item.id)
                    }
                }.listStyle(.sidebar)
                HStack {
                    Button { store.sidebar = "IKEA" } label: { Label("Furniture", systemImage: "plus") }
                    Button { store.addPerson() } label: { Label("Person", systemImage: "person.badge.plus") }
                }.padding(12)
                HStack { Button("Duplicate") { store.duplicateSelection() }; Button("Remove") { store.deleteSelection() } }.disabled(store.item == nil).padding(.horizontal, 12).padding(.bottom, 14)
            } else if store.sidebar == "IKEA" {
                TextField("Search furniture", text: $search).textFieldStyle(.roundedBorder).padding(.horizontal, 12).padding(.bottom, 10)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Catalog.products.filter { search.isEmpty || "\($0.series) \($0.name) \($0.articleNumber)".localizedCaseInsensitiveContains(search) }) { product in
                            VStack(alignment: .leading, spacing: 7) {
                                HStack { Text(product.series).font(.headline); Spacer(); Button { store.add(product) } label: { Image(systemName: "plus") }.accessibilityLabel("Add \(product.series) \(product.name)") }
                                Text(product.name).font(.subheadline)
                                Text(product.finish).font(.caption).foregroundStyle(.secondary)
                                Text("\(measure(product.assembledDimensionsM.width)) × \(measure(product.assembledDimensionsM.depth)) × \(measure(product.assembledDimensionsM.height)) m").font(.caption).monospacedDigit()
                                Link("\(product.articleNumber) ↗", destination: URL(string: product.source.url)!).font(.caption)
                            }.padding(14)
                            Divider()
                        }
                    }
                }
                Text("12 Swiss variants · checked 7 Sep 2026\nStock unverified. Models approximate.").font(.caption).foregroundStyle(.secondary).padding(12)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Will it fit?").font(.title3.weight(.semibold))
                        if store.issues.isEmpty { Label("No footprint conflicts", systemImage: "checkmark.circle").foregroundStyle(pine) }
                        ForEach(Array(store.issues.enumerated()), id: \.offset) { _, issue in Label(issue, systemImage: "exclamationmark.triangle").font(.callout) }
                        Divider()
                        Text("Sharing the room").font(.headline)
                        Text("Can each person reach the open doorway while the other stays put?").foregroundStyle(.secondary)
                        Button(store.checking ? "Checking…" : "Check routes to door") { store.checkRoutes() }.disabled(store.checking)
                        ForEach(store.routes, id: \.personID) { route in
                            VStack(alignment: .leading, spacing: 6) {
                                Label(route.personName, systemImage: route.reachable ? "checkmark.circle" : "xmark.circle").font(.headline)
                                Text(route.reachable ? "Route found" : "No route found under these assumptions").font(.callout)
                                Text(route.assumption).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Divider()
                        Text("These are conservative floor-plan checks. Open drawers, dressing, simultaneous movement and daily routines need further modeling.").font(.caption).foregroundStyle(.secondary)
                    }.padding(16)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct NumericField: View {
    let title: String
    @Binding var value: Double
    var unit = "m"
    var body: some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            TextField(title, value: $value, format: .number.precision(.fractionLength(0...3)))
                .textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing).frame(width: 76).monospacedDigit()
                .accessibilityLabel("\(title) in \(unit)")
            Text(unit).font(.caption).foregroundStyle(.secondary).frame(width: 15)
        }
    }
}
struct Inspector: View {
    @EnvironmentObject var store: EditorStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let item = store.item { ItemInspector(original: item).id(item.id) }
                else {
                    Text("Room dimensions").font(.title3.weight(.semibold))
                    Text("Enter your measurements. Furniture positions are measured from the southwest corner.").font(.callout).foregroundStyle(.secondary)
                    RoomInspector(original: store.document.room).id(store.document.room)
                }
                Divider()
                if store.item != nil { Button("Edit room dimensions") { store.selected = nil } }
                Button("Check room layout") { store.sidebar = "Checks" }
                Divider()
                Text("Local workspace").font(.headline)
                Text("Save, then give your agent the scene file path. Valid external edits appear automatically when your local changes are saved.").font(.caption).foregroundStyle(.secondary)
                Button("Open room…") { store.open() }
                Button("Save a copy…") { store.save(copy: true) }
            }.padding(18)
        }
    }
}
struct RoomInspector: View {
    @EnvironmentObject var store: EditorStore
    @LegacyState var draft: Room
    @LegacyState var name: String = ""
    init(original: Room) { _draft = State(initialValue: original) }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Room name", text: $name).textFieldStyle(.roundedBorder).onAppear { name = store.document.name }
            NumericField(title: "Width", value: $draft.width)
            NumericField(title: "Depth", value: $draft.depth)
            NumericField(title: "Ceiling", value: $draft.height)
            Text("Door · south wall").font(.headline).padding(.top, 9)
            NumericField(title: "From west", value: $draft.doorX)
            NumericField(title: "Width", value: $draft.doorWidth)
            Text("Window · north wall").font(.headline).padding(.top, 9)
            NumericField(title: "From west", value: $draft.windowX)
            NumericField(title: "Width", value: $draft.windowWidth)
            NumericField(title: "Sill height", value: $draft.windowSill)
            NumericField(title: "Height", value: $draft.windowHeight)
            Button("Apply room measurements") { store.change { $0.room = draft; $0.name = name } }.buttonStyle(.borderedProminent).tint(pine).padding(.top, 6)
        }
    }
}
struct ItemInspector: View {
    @EnvironmentObject var store: EditorStore
    let original: Item
    @LegacyState var draft: Item
    init(original: Item) { self.original = original; _draft = State(initialValue: original) }
    var product: CatalogProduct? { Catalog.products.first { $0.id == original.catalogID } }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon(original.kind)).font(.largeTitle).foregroundStyle(pine)
            Text(original.name).font(.title3.weight(.semibold))
            if let product {
                Text("IKEA · \(product.articleNumber)").font(.caption).foregroundStyle(.secondary)
                Text(product.finish).font(.caption)
                Link("View official product ↗", destination: URL(string: product.source.url)!).font(.caption)
            } else { Text(original.kind == "person" ? "Adjustable body envelope" : "Custom object").font(.caption).foregroundStyle(.secondary) }
            Divider().padding(.vertical, 5)
            TextField("Object name", text: $draft.name).textFieldStyle(.roundedBorder)
            NumericField(title: "X · east", value: $draft.x)
            NumericField(title: "Z · north", value: $draft.z)
            NumericField(title: "Rotation", value: $draft.rotation, unit: "°")
            Divider().padding(.vertical, 5)
            NumericField(title: "Width", value: $draft.width).disabled(product != nil)
            NumericField(title: "Depth", value: $draft.depth).disabled(product != nil)
            NumericField(title: "Height", value: $draft.height).disabled(product != nil)
            Button("Apply object changes") { store.update(draft) }.buttonStyle(.borderedProminent).tint(pine)
            Button("Rotate 90°") { var copy = original; copy.rotation = (copy.rotation + 90).truncatingRemainder(dividingBy: 360); store.update(copy) }
            if let product {
                Text("Published dimensions are locked. The 3D shape is an approximation.").font(.caption).foregroundStyle(.secondary)
                Button("Make custom to resize") { var copy = original; copy.catalogID = nil; copy.name += " (custom)"; store.update(copy) }
                if product.requiresWallAnchoring == true { Label("Requires wall anchoring", systemImage: "exclamationmark.triangle").font(.caption) }
                ForEach(product.notes, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
            }
            Divider()
            Text("Object ID").font(.caption.weight(.semibold))
            Text(original.id).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled)
        }.onChange(of: original) { _, new in draft = new }
    }
}

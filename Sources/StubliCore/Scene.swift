import Foundation

public struct Room: Codable, Equatable, Hashable, Sendable {
    public var width: Double = 4.8
    public var depth: Double = 4.2
    public var height: Double = 2.5
    public var doorX: Double = 0.7
    public var doorWidth: Double = 0.85
    public var windowX: Double = 2.7
    public var windowWidth: Double = 1.4
    public var windowSill: Double = 0.9
    public var windowHeight: Double = 1.2
    public init() {}
}

public struct Item: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var kind: String
    public var x: Double
    public var z: Double
    public var width: Double
    public var depth: Double
    public var height: Double
    public var catalogID: String? = nil
    public var openFraction: Double? = nil
    public var rotation: Double
    public init(id: String = UUID().uuidString.lowercased(), name: String, kind: String, x: Double, z: Double, width: Double, depth: Double, height: Double, rotation: Double = 0) {
        self.id = id; self.name = name; self.kind = kind; self.x = x; self.z = z
        self.width = width; self.depth = depth; self.height = height; self.rotation = rotation
    }
    public var footprint: (width: Double, depth: Double) {
        let r = rotation * .pi / 180
        return (abs(cos(r)) * width + abs(sin(r)) * depth, abs(sin(r)) * width + abs(cos(r)) * depth)
    }
    public static let kinds = ["bed", "desk", "chair", "wardrobe", "wardrobe_frame", "bedside", "chest", "bookcase", "shelving", "person"]
    public static func generic(_ kind: String) -> Item {
        switch kind {
        case "bed": Item(name: "Double bed", kind: kind, x: 2.3, z: 2.3, width: 1.6, depth: 2, height: 0.55)
        case "desk": Item(name: "Desk", kind: kind, x: 3.6, z: 0.8, width: 1.2, depth: 0.6, height: 0.75)
        case "wardrobe": Item(name: "Wardrobe", kind: kind, x: 0.55, z: 2.4, width: 0.8, depth: 0.6, height: 2)
        case "person": Item(name: "Person clearance", kind: kind, x: 1.5, z: 0.9, width: 0.55, depth: 0.55, height: 1.7)
        default: Item(name: "Chair", kind: "chair", x: 3.6, z: 1.5, width: 0.5, depth: 0.5, height: 0.85)
        }
    }
}

public struct SceneDocument: Codable, Equatable, Sendable {
    public var schemaVersion: Int = 1
    public var lighting: String? = nil
    public var name: String = "Bedroom study"
    public var room = Room()
    public var items: [Item] = []
    public init() {}
    public static var sample: SceneDocument {
        var scene = SceneDocument()
        let placements: [(String, Double, Double, Double)] = [
            ("09929373", 2.15, 3.02, 0), ("80214549", 0.96, 3.65, 0),
            ("80213074", 4.1, 3.85, 0), ("70261150", 4.1, 2.95, 0),
            ("00441758", 0.43, 2.15, 90)]
        scene.items = placements.compactMap { code, x, z, rotation in
            guard let product = Catalog.products.first(where: { $0.id == "ikea-ch-" + code }) else { return nil }
            var item = product.makeItem(); item.x = x; item.z = z; item.rotation = rotation; return item
        }
        var person = Item.generic("person"); person.name = "Person A"; person.x = 1.3; person.z = 1.2
        scene.items.append(person)
        person.id = UUID().uuidString.lowercased(); person.name = "Person B"; person.x = 3.25; person.z = 1.3
        scene.items.append(person)
        scene.name = "Example bedroom"
        return scene
    }
    public func validate() throws {
        guard ["Daylight", "Evening"].contains(lighting ?? "Daylight") else { throw SceneError.invalid("Lighting must be Daylight or Evening.") }
        guard schemaVersion == 1 else { throw SceneError.invalid("Unsupported schema version.") }
        guard !name.isEmpty, name.count <= 200, items.count <= 500 else { throw SceneError.invalid("Use a room name and at most 500 objects.") }
        guard [room.width, room.depth, room.height].allSatisfy({ $0.isFinite && $0 >= 0.5 && $0 <= 50 }), room.doorWidth.isFinite, room.doorX.isFinite, room.doorWidth > 0, room.doorX >= 0, room.doorX + room.doorWidth <= room.width else { throw SceneError.invalid("Room sizes must be 0.5–50 m; the doorway must fit the south wall.") }
        guard [room.windowX, room.windowWidth, room.windowSill, room.windowHeight].allSatisfy({ $0.isFinite && $0 >= 0 }), room.windowWidth > 0, room.windowHeight > 0, room.windowX + room.windowWidth <= room.width, room.windowSill + room.windowHeight <= room.height else { throw SceneError.invalid("The window must fit the north wall.") }
        guard Set(items.map(\.id)).count == items.count else { throw SceneError.invalid("Object IDs must be unique.") }
        for item in items {
            guard (item.openFraction ?? 0).isFinite, (0...1).contains(item.openFraction ?? 0) else { throw SceneError.invalid("Opening must be between zero and one.") }
            guard !item.id.isEmpty, !item.name.isEmpty, item.name.count <= 200,
                  [item.x, item.z, item.rotation].allSatisfy({ $0.isFinite && abs($0) <= 10000 }),
                  [item.width, item.depth, item.height].allSatisfy({ $0.isFinite && $0 > 0 && $0 <= 50 }),
                  Item.kinds.contains(item.kind)
            else { throw SceneError.invalid("Invalid object: \(item.id). Check its kind, name, and finite positive dimensions.") }
            if let id = item.catalogID {
                guard let product = Catalog.products.first(where: { $0.id == id }),
                      item.kind == product.category,
                      abs(item.width - product.assembledDimensionsM.width) < 0.000001,
                      abs(item.depth - product.assembledDimensionsM.depth) < 0.000001,
                      abs(item.height - product.assembledDimensionsM.height) < 0.000001
                else { throw SceneError.invalid("Catalog dimensions are locked. Convert to a custom object before resizing.") }
            }
        }
    }
    public func warnings() -> [String] {
        var results: [String] = []
        for item in items {
            let f = item.footprint
            if item.x - f.width / 2 < -0.001 || item.x + f.width / 2 > room.width + 0.001 || item.z - f.depth / 2 < -0.001 || item.z + f.depth / 2 > room.depth + 0.001 {
                results.append("\(item.name) extends outside the room.")
            }
            if item.height > room.height { results.append("\(item.name) exceeds the ceiling height.") }
            if item.x + f.width / 2 > room.doorX && item.x - f.width / 2 < room.doorX + room.doorWidth && item.z - f.depth / 2 < room.doorWidth && item.z + f.depth / 2 > 0 {
                results.append("\(item.name) may block the door approach.")
            }
        }
        for i in items.indices {
            for j in items.indices where j > i {
                if overlaps(items[i], items[j]) { results.append("\(items[i].name) overlaps \(items[j].name) in the floor plan.") }
            }
        }
        for envelope in openingEnvelopes {
            let f = envelope.volume.footprint, v = envelope.volume
            if v.x - f.width / 2 < 0 || v.x + f.width / 2 > room.width || v.z - f.depth / 2 < 0 || v.z + f.depth / 2 > room.depth {
                results.append("\(envelope.ownerName): open furniture may hit a wall (\(envelope.basis)).")
            }
            for other in items where other.id != envelope.ownerID {
                if overlaps(v, other) { results.append("\(envelope.ownerName): opening may hit \(other.name) (\(envelope.basis)).") }
            }
        }
        return results
    }
}

// Separating axis theorem for rotated rectangular footprints; touching is allowed.
public func overlaps(_ a: Item, _ b: Item) -> Bool {
    func axes(_ item: Item) -> [(Double, Double)] {
        let r = item.rotation * .pi / 180
        return [(cos(r), -sin(r)), (sin(r), cos(r))]
    }
    let aa = axes(a), bb = axes(b)
    for axis in aa + bb {
        func radius(_ item: Item, _ basis: [(Double, Double)]) -> Double {
            abs(axis.0 * basis[0].0 + axis.1 * basis[0].1) * item.width / 2 + abs(axis.0 * basis[1].0 + axis.1 * basis[1].1) * item.depth / 2
        }
        let distance = abs((b.x - a.x) * axis.0 + (b.z - a.z) * axis.1)
        if distance >= radius(a, aa) + radius(b, bb) - 0.001 { return false }
    }
    return true
}

public enum SceneError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
}

public enum SceneIO {
    public static func read(_ url: URL) throws -> SceneDocument {
        let data = try Data(contentsOf: url)
        guard data.count < 5_000_000 else { throw SceneError.invalid("Scene file exceeds 5 MB.") }
        let document = try JSONDecoder().decode(SceneDocument.self, from: data)
        try document.validate()
        return document
    }
    public static func encode(_ document: SceneDocument) throws -> Data {
        try document.validate()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(document)
    }
    public static func write(_ document: SceneDocument, to url: URL) throws { try encode(document).write(to: url, options: .atomic) }
    // All app/CLI writers cooperate on this lock; manual editors must avoid concurrent writes.
    public static func commit(_ document: SceneDocument, to url: URL, expected: Data?) throws {
        let lock = URL(fileURLWithPath: url.path + ".lock")
        do { try FileManager.default.createDirectory(at: lock, withIntermediateDirectories: false) }
        catch { throw SceneError.invalid("This scene is being saved elsewhere (or a stale .lock directory exists). Retry after the other writer finishes.") }
        defer { try? FileManager.default.removeItem(at: lock) }
        let current = FileManager.default.fileExists(atPath: url.path) ? try Data(contentsOf: url) : nil
        guard current == expected else { throw SceneError.invalid("The scene changed on disk. Reload it or save a copy to keep both versions.") }
        try write(document, to: url)
    }
}

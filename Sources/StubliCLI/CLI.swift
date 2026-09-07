import Foundation
import StubliCore

let help = """
Stübli 0.2 — local agent interface (metres)

stubli catalog [QUERY]                     Search verified Swiss product records
stubli sample FILE                         Create a new example scene
stubli inspect FILE [OBJECT_ID]            Read scene or one object as JSON
stubli check FILE                          Check footprints, door approach, ceiling
stubli routes FILE                         Check each person's path to the door
stubli set FILE OBJECT_ID FIELD VALUE      x,z,width,depth,height,rotation,name,openFraction
stubli add FILE KIND_OR_CATALOG_ID         Add a catalog product or generic person
stubli remove FILE OBJECT_ID               Remove an object
stubli custom FILE OBJECT_ID               Detach catalog identity before resizing
stubli patch FILE PATCH_JSON_FILE          Apply a batch atomically

Patch: {"updates":[{"id":"…","x":1.5,"z":2,"rotation":90}],
        "room":{"width":4.8,"depth":4.2},"name":"Layout B"}
Room patch fields: width,depth,height,doorX,doorWidth,windowX,windowWidth,
windowSill,windowHeight. Object dimensions retain catalog validation.
Positions are centres, x east and z north from the southwest corner.
Positive rotation follows a right-handed rotation about +y. Rotation 0
places a product's front toward south; geometric details are approximate.
Save GUI changes before editing; the clean GUI automatically reloads.
All app/CLI writers use a lock and reject stale writes. Manual editors
must avoid concurrent writes. Keep scene backups for agent workflows.
"""
func output<T: Encodable>(_ value: T) throws {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    print(String(decoding: try encoder.encode(value), as: UTF8.self))
}
func edit(_ field: String, value: String, item: inout Item) throws {
    if field == "name" { item.name = value; return }
    guard let n = Double(value), n.isFinite else { throw SceneError.invalid("Provide a finite number.") }
    switch field {
    case "x": item.x = n
    case "z": item.z = n
    case "width": item.width = n
    case "depth": item.depth = n
    case "height": item.height = n
    case "rotation": item.rotation = n
    case "openFraction": item.openFraction = n
    default: throw SceneError.invalid("Unknown object field: \(field).")
    }
}
func run() throws {
    let args = Array(CommandLine.arguments.dropFirst())
    guard let command = args.first, command != "--help", command != "help" else { print(help); return }
    if command == "catalog" {
        let query = args.dropFirst().joined(separator: " ")
        try output(Catalog.products.filter { query.isEmpty || "\($0.id) \($0.articleNumber) \($0.series) \($0.name)".localizedCaseInsensitiveContains(query) }); return
    }
    guard args.count >= 2 else { throw SceneError.invalid(help) }
    let url = URL(fileURLWithPath: args[1])
    if command == "sample" { try SceneIO.commit(.sample, to: url, expected: nil); print(url.path); return }
    let original = try Data(contentsOf: url)
    var scene = try JSONDecoder().decode(SceneDocument.self, from: original); try scene.validate()
    switch command {
    case "inspect":
        if args.count == 3 {
            guard let item = scene.items.first(where: { $0.id == args[2] }) else { throw SceneError.invalid("Object ID not found.") }
            try output(item)
        } else { try output(scene) }; return
    case "check": try output(scene.warnings()); return
    case "routes":
        guard max(scene.room.width,scene.room.depth) <= 15, scene.items.count <= 100 else { throw SceneError.invalid("Route check limit: 15 m rooms, 100 objects.") }
        try output(scene.items.filter { $0.kind == "person" }.map { Routes.toDoor(in: scene,person: $0) }); return
    case "add":
        guard args.count == 3 else { throw SceneError.invalid("Provide a catalog ID or generic kind.") }
        let item: Item
        if let product = Catalog.products.first(where: { $0.id == args[2] }) { item = product.makeItem() }
        else if ["bed","desk","chair","wardrobe","person"].contains(args[2]) { item = Item.generic(args[2]) }
        else { throw SceneError.invalid("Unknown catalog ID or generic kind.") }
        scene.items.append(item); try SceneIO.commit(scene, to: url, expected: original); try output(item); return
    case "set", "remove", "custom":
        guard args.count >= 3, let index = scene.items.firstIndex(where: { $0.id == args[2] }) else { throw SceneError.invalid("Object ID not found.") }
        if command == "remove" { scene.items.remove(at: index) }
        else if command == "custom" { scene.items[index].catalogID = nil; scene.items[index].name += " (custom)" }
        else {
            guard args.count == 5 else { throw SceneError.invalid("Expected set FILE ID FIELD VALUE.") }
            try edit(args[3],value: args[4],item: &scene.items[index])
        }
    case "patch":
        guard args.count == 3,
              let patch = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: args[2]))) as? [String:Any],
              Set(patch.keys).isSubset(of: ["updates","room","name","lighting"]) else { throw SceneError.invalid("Expected a patch object with updates, room and/or name.") }
        if let raw = patch["lighting"] { guard let value = raw as? String else { throw SceneError.invalid("Lighting must be text.") }; scene.lighting = value }
        if let name = patch["name"] { guard let name = name as? String else { throw SceneError.invalid("Name must be text.") }; scene.name = name }
        if let raw = patch["updates"] {
            guard let updates = raw as? [[String:Any]] else { throw SceneError.invalid("Updates must be an array of objects.") }
            for update in updates {
                guard let id = update["id"] as? String, let i = scene.items.firstIndex(where: { $0.id == id }) else { throw SceneError.invalid("Update object ID not found.") }
                for (field,value) in update where field != "id" {
                    guard let string = value as? String ?? (value as? NSNumber)?.stringValue else { throw SceneError.invalid("Unsupported value for \(field).") }
                    try edit(field,value: string,item: &scene.items[i])
                }
            }
        }
        if let raw = patch["room"] {
            guard let room = raw as? [String:Double] else { throw SceneError.invalid("Room fields must be numeric.") }
            for (field,n) in room {
                switch field {
                case "width": scene.room.width = n
                case "depth": scene.room.depth = n
                case "height": scene.room.height = n
                case "doorX": scene.room.doorX = n
                case "doorWidth": scene.room.doorWidth = n
                case "windowX": scene.room.windowX = n
                case "windowWidth": scene.room.windowWidth = n
                case "windowSill": scene.room.windowSill = n
                case "windowHeight": scene.room.windowHeight = n
                default: throw SceneError.invalid("Unknown room field: \(field).")
                }
            }
        }
    default: throw SceneError.invalid(help)
    }
    try SceneIO.commit(scene, to: url, expected: original)
    try output(scene.warnings())
}
@main struct CLI { static func main() {
    do { try run() } catch { FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8)); exit(1) }
} }

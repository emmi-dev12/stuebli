import Foundation

public struct OpeningEnvelope: Sendable {
    public var ownerID: String
    public var ownerName: String
    public var volume: Item
    public var basis: String
}
extension Item {
    public var canOpen: Bool { ["wardrobe", "bedside", "chest", "desk"].contains(kind) }
    public var openingDistance: Double {
        guard canOpen else { return 0 }
        if kind == "wardrobe" { return width / 3 * sin((openFraction ?? 0) * .pi / 2) }
        let verified = Catalog.products.first { $0.id == catalogID }?.movement.drawerTravelM
        return (verified ?? depth * 0.65) * (openFraction ?? 0)
    }
    public var openingBasis: String {
        if kind == "wardrobe" { return "assumed three equal hinged doors" }
        if Catalog.products.first(where: { $0.id == catalogID })?.movement.drawerTravelM != nil { return "published drawer travel" }
        return "assumed drawer travel: 65% of depth"
    }
}
extension SceneDocument {
    public var openingEnvelopes: [OpeningEnvelope] {
        items.compactMap { item in
            let extensionDepth = item.openingDistance
            guard extensionDepth > 0.001 else { return nil }
            let r = item.rotation * .pi / 180, offset = item.depth / 2 + extensionDepth / 2
            let volume = Item(id: "opening-" + item.id, name: item.name + " opening", kind: "person", x: item.x - sin(r) * offset, z: item.z - cos(r) * offset, width: item.width, depth: extensionDepth, height: item.height, rotation: item.rotation)
            return OpeningEnvelope(ownerID: item.id, ownerName: item.name, volume: volume, basis: item.openingBasis)
        }
    }
}

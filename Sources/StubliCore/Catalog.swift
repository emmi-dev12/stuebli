import Foundation

public struct ProductDimensions: Codable, Sendable {
    public var width: Double
    public var depth: Double
    public var height: Double
}
public struct ProductSource: Codable, Sendable {
    public var url: String
    public var accessedOn: String
}
public struct ProductMovement: Codable, Sendable {
    public var drawerTravelM: Double?
}
public struct CatalogProduct: Codable, Identifiable, Sendable {
    public var id: String
    public var articleNumber: String
    public var series: String
    public var name: String
    public var finish: String
    public var category: String
    public var assembledDimensionsM: ProductDimensions
    public var source: ProductSource
    public var movement: ProductMovement
    public var requiresWallAnchoring: Bool?
    public var notes: [String]
    public func makeItem() -> Item {
        var item = Item(name: "\(series) \(name)", kind: category, x: assembledDimensionsM.width / 2 + 0.2, z: assembledDimensionsM.depth / 2 + 0.2, width: assembledDimensionsM.width, depth: assembledDimensionsM.depth, height: assembledDimensionsM.height)
        item.catalogID = id
        return item
    }
}
public enum Catalog {
    private struct Envelope: Decodable { var products: [CatalogProduct] }
    public static let products: [CatalogProduct] = {
        guard let url = Bundle.module.url(forResource: "ikea-ch", withExtension: "json"),
              let data = try? Data(contentsOf: url), let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else { return [] }
        return envelope.products
    }()
}

public struct RouteResult: Codable, Sendable {
    public var personID: String
    public var personName: String
    public var destination: String
    public var reachable: Bool
    public var points: [[Double]]
    public var assumption: String
}
public enum Routes {
    // 10 cm grid, conservative circular pedestrian envelope. This is geometry,
    // not a behavioural or accessibility certification model.
    public static func toDoor(in document: SceneDocument, person: Item) -> RouteResult {
        let step = 0.1, radius = max(person.width, person.depth) / 2
        let nx = Int(document.room.width / step), nz = Int(document.room.depth / step)
        let obstacles = document.items.filter { $0.id != person.id }
        func free(_ x: Int, _ z: Int) -> Bool {
            let px = Double(x) * step + step / 2, pz = Double(z) * step + step / 2
            guard px >= radius, px <= document.room.width - radius, pz >= radius, pz <= document.room.depth - radius else { return false }
            for item in obstacles {
                let r = item.rotation * .pi / 180, dx = px - item.x, dz = pz - item.z
                let lx = cos(r) * dx - sin(r) * dz, lz = sin(r) * dx + cos(r) * dz
                let qx = max(abs(lx) - item.width / 2, 0), qz = max(abs(lz) - item.depth / 2, 0)
                if qx * qx + qz * qz < radius * radius { return false }
            }
            return true
        }
        let sx = Int(person.x / step), sz = Int(person.z / step)
        let tx = Int((document.room.doorX + document.room.doorWidth / 2) / step)
        let tz = Int((radius + step) / step)
        var result = RouteResult(personID: person.id, personName: person.name, destination: "Door approach", reachable: false, points: [], assumption: "10 cm grid; \(Int(radius * 200)) cm body diameter; other person stationary; doorway assumed open; no timed behaviour.")
        guard document.room.doorWidth >= radius * 2, sx >= 0, sz >= 0, sx < nx, sz < nz, free(sx, sz), free(tx, tz) else { return result }
        let start = sz * nx + sx, end = tz * nx + tx
        var queue = [start], cursor = 0, previous = [start: start]
        while cursor < queue.count {
            let current = queue[cursor]; cursor += 1
            if current == end { break }
            for (dx,dz) in [(1,0),(-1,0),(0,1),(0,-1)] {
                let x = current % nx + dx, z = current / nx + dz, key = z * nx + x
                guard x >= 0, z >= 0, x < nx, z < nz, previous[key] == nil, free(x,z) else { continue }
                previous[key] = current; queue.append(key)
            }
        }
        guard previous[end] != nil else { return result }
        result.reachable = true
        var key = end
        while true {
            result.points.append([Double(key % nx) * step + step / 2, Double(key / nx) * step + step / 2])
            if key == start { break }; key = previous[key]!
        }
        result.points.reverse(); return result
    }
}

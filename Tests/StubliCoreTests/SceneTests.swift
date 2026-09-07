import Foundation
import StubliCore

final class SceneTests {
    func testCatalogAndSample() throws {
        XCTAssertEqual(Catalog.products.count,12)
        XCTAssertEqual(Set(Catalog.products.map(\.id)).count,12)
        for p in Catalog.products {
            var doc = SceneDocument(); doc.items = [p.makeItem()]; try doc.validate()
            XCTAssertTrue(p.source.url.contains("/ch/en/p/"))
        }
        let sample = SceneDocument.sample; try sample.validate()
        XCTAssertEqual(sample.items.count,7)
        XCTAssertTrue(sample.warnings().isEmpty, sample.warnings().joined(separator: "; "))
        try XCTAssertEqual(try JSONDecoder().decode(SceneDocument.self, from: SceneIO.encode(sample)),sample)
    }
    func testExactProductEnvelopeAndLock() throws {
        let pax = try XCTUnwrap(Catalog.products.first { $0.series == "PAX" })
        XCTAssertEqual(pax.assembledDimensionsM.width,0.998,accuracy: 0.000001)
        XCTAssertEqual(pax.assembledDimensionsM.height,2.012,accuracy: 0.000001)
        var doc = SceneDocument(); doc.items = [pax.makeItem()]
        doc.items[0].width = 1
        XCTAssertThrowsError(try doc.validate())
        doc.items[0].catalogID = nil
        XCTAssertNoThrow(try doc.validate())
    }
    func testRotatedFootprintsAndTouching() {
        let a = Item(name: "A",kind: "desk",x: 0,z: 0,width: 2,depth: 0.1,height: 1,rotation: 45)
        var b = a; b.id = "b"; b.x = 0.2; b.z = 0.2
        XCTAssertFalse(overlaps(a,b)) // AABBs overlap, true oriented rectangles don't.
        b.x = 0.02; b.z = 0.02; XCTAssertTrue(overlaps(a,b))
        var c = Item.generic("bed"); var d = c; d.x += c.width
        XCTAssertFalse(overlaps(c,d))
        c.rotation = 90; XCTAssertEqual(c.footprint.width,c.depth,accuracy: 0.000001)
    }
    func testInvalidGeometryAndDoorWarning() throws {
        var doc = SceneDocument.sample; doc.room.windowWidth = 10
        XCTAssertThrowsError(try doc.validate())
        doc = .sample; doc.items[0].x = .infinity
        XCTAssertThrowsError(try doc.validate())
        doc = .sample; doc.items.append(doc.items[0]); XCTAssertThrowsError(try doc.validate())
        doc = .sample; doc.items[0].x = 1; doc.items[0].z = 0.5
        XCTAssertTrue(doc.warnings().contains { $0.contains("door approach") })
    }
    func testStaleWritesCannotOverwriteAndInvalidWritesAreAtomic() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder,withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("room.json")
        let first = SceneDocument.sample
        try SceneIO.commit(first,to: file,expected: nil)
        let snapshot = try Data(contentsOf: file)
        var second = first; second.name = "Agent edit"
        try SceneIO.commit(second,to: file,expected: snapshot)
        XCTAssertThrowsError(try SceneIO.commit(first,to: file,expected: snapshot))
        try XCTAssertEqual(try SceneIO.read(file).name,"Agent edit")
        let current = try Data(contentsOf: file)
        second.room.width = -1
        XCTAssertThrowsError(try SceneIO.commit(second,to: file,expected: current))
        try XCTAssertEqual(try Data(contentsOf: file),current)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path + ".lock"))
    }
    func testRouteFoundThenBlockedByBarrier() {
        var doc = SceneDocument(); var person = Item.generic("person"); person.x = 2; person.z = 3
        doc.items = [person]
        XCTAssertTrue(Routes.toDoor(in: doc,person: person).reachable)
        doc.items.append(Item(name: "Barrier",kind: "wardrobe",x: doc.room.width / 2,z: 1.5,width: doc.room.width,depth: 0.6,height: 2))
        XCTAssertFalse(Routes.toDoor(in: doc,person: person).reachable)
    }
}

// Dependency-free checks also run with Apple's Command Line Tools (no Xcode/XCTest).
func XCTAssertTrue(_ value: @autoclosure () throws -> Bool, _ message: String = "", file: StaticString = #file, line: UInt = #line) rethrows {
    if try !value() { fatalError("Check failed: \(message)",file: file,line: line) }
}
func XCTAssertFalse(_ value: @autoclosure () throws -> Bool, file: StaticString = #file, line: UInt = #line) rethrows { try XCTAssertTrue(!value(),file: file,line: line) }
func XCTAssertEqual<T: Equatable>(_ a: @autoclosure () throws -> T,_ b: @autoclosure () throws -> T,file: StaticString = #file,line: UInt = #line) rethrows { try XCTAssertTrue(a() == b(),file: file,line: line) }
func XCTAssertEqual(_ a: Double,_ b: Double, accuracy: Double,file: StaticString = #file,line: UInt = #line) { XCTAssertTrue(abs(a-b) <= accuracy,file: file,line: line) }
func XCTAssertThrowsError<T>(_ expression: @autoclosure () throws -> T,file: StaticString = #file,line: UInt = #line) {
    do { _ = try expression() } catch { return }; fatalError("Expected rejection",file: file,line: line)
}
func XCTAssertNoThrow<T>(_ expression: @autoclosure () throws -> T,file: StaticString = #file,line: UInt = #line) { do { _ = try expression() } catch { fatalError("Unexpected: \(error)",file: file,line: line) } }
func XCTUnwrap<T>(_ value: T?) throws -> T { guard let value else { throw SceneError.invalid("Missing test value") }; return value }
@main struct CheckRunner {
    static func main() throws {
        let tests = SceneTests()
        let cases: [(String, () throws -> Void)] = [
            ("catalog + sample round trip", tests.testCatalogAndSample),
            ("exact dimensions + product lock", tests.testExactProductEnvelopeAndLock),
            ("rotated collision + touching", tests.testRotatedFootprintsAndTouching),
            ("invalid geometry + door warnings", tests.testInvalidGeometryAndDoorWarning),
            ("stale writes + atomic validation", tests.testStaleWritesCannotOverwriteAndInvalidWritesAreAtomic),
            ("reachable + blocked route", tests.testRouteFoundThenBlockedByBarrier)
        ]
        for (name,test) in cases { try test(); print("PASS \(name)") }
        print("All \(cases.count) core checks passed.")
    }
}

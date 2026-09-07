import AppKit
import SceneKit

@MainActor
enum Materials {
    static let oakColor = image("oak-color.jpg")
    static let oakNormal = image("oak-normal.jpg")
    static let oakRoughness = image("oak-roughness.jpg")
    static let cottonNormal = image("cotton-normal.jpg")
    static let environment = Bundle.module.url(forResource: "studio", withExtension: "hdr", subdirectory: "Materials")
    static func image(_ name: String) -> NSImage? {
        guard let url = Bundle.module.resourceURL?.appendingPathComponent("Materials/" + name) else { return nil }
        return NSImage(contentsOf: url)
    }
    static func wood(width: Double, depth: Double) -> SCNMaterial {
        let m = SCNMaterial(); m.lightingModel = .physicallyBased
        m.diffuse.contents = oakColor; m.diffuse.intensity = 0.74; m.normal.contents = oakNormal; m.roughness.contents = oakRoughness
        for property in [m.diffuse,m.normal,m.roughness] {
            property.wrapS = .repeat; property.wrapT = .repeat
            property.contentsTransform = SCNMatrix4MakeScale(CGFloat(width / 2), CGFloat(depth / 2), 1)
            property.maxAnisotropy = 8
        }
        m.normal.intensity = 0.45
        return m
    }
    static func cloth(_ color: NSColor, repeatCount: Double = 3) -> SCNMaterial {
        let m = SCNMaterial(); m.lightingModel = .physicallyBased
        m.diffuse.contents = color; m.roughness.contents = 0.95; m.normal.contents = cottonNormal
        m.normal.wrapS = .repeat; m.normal.wrapT = .repeat
        m.normal.contentsTransform = SCNMatrix4MakeScale(CGFloat(repeatCount), CGFloat(repeatCount), 1)
        m.normal.intensity = 0.32; m.isDoubleSided = true
        return m
    }
    static func finish(_ color: NSColor, metal: Double = 0, roughness: Double = 0.5) -> SCNMaterial {
        let m = SCNMaterial(); m.lightingModel = .physicallyBased
        m.diffuse.contents = color; m.roughness.contents = roughness; m.metalness.contents = metal
        return m
    }
}

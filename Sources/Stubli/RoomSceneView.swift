import SwiftUI
import SceneKit
import StubliCore

struct RoomSceneView: NSViewRepresentable {
    @ObservedObject var store: EditorStore
    func makeNSView(context: Context) -> BedroomSCNView {
        let view = BedroomSCNView(frame: .zero)
        view.store = store
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 30
        view.rendersContinuously = false
        view.backgroundColor = NSColor(calibratedRed: 0.92, green: 0.93, blue: 0.91, alpha: 1)
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.group)
        view.setAccessibilityIdentifier("room-viewport")
        view.setAccessibilityLabel("Interactive bedroom 3D view")
        view.update(document: store.document, mode: store.mode, selection: store.selected, reset: store.cameraReset)
        return view
    }
    func updateNSView(_ view: BedroomSCNView, context: Context) {
        view.update(document: store.document, mode: store.mode, selection: store.selected, reset: store.cameraReset)
    }
}

@MainActor
final class BedroomSCNView: SCNView {
    weak var store: EditorStore?
    var lastDocument: SceneDocument?
    var lastMode = ""
    var lastSelection: String?
    var lastReset = -1
    var yaw: Float = .pi
    var pitch: Float = 0
    private var walkCamera: SCNNode?
    override var acceptsFirstResponder: Bool { true }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if lastMode == "Walk" { window?.makeFirstResponder(self) }
    }

    func update(document: SceneDocument, mode: String, selection: String?, reset: Int) {
        let changed = lastDocument != document || lastMode != mode || lastReset != reset
        if changed {
            let previousCamera = pointOfView?.clone()
            let preserveCamera = lastMode == mode && lastReset == reset
            scene = SceneBuilder.build(document, cutaway: mode != "Walk")
            allowsCameraControl = mode != "Walk"
            defaultCameraController.inertiaEnabled = false
            defaultCameraController.target = SCNVector3(document.room.width / 2, 0.6, document.room.depth / 2)
            if preserveCamera, let camera = previousCamera {
                scene?.rootNode.addChildNode(camera); pointOfView = camera
            } else { resetCamera(document, walk: mode == "Walk") }
            if mode == "Walk" { walkCamera = pointOfView; window?.makeFirstResponder(self) }
            lastDocument = document; lastMode = mode; lastReset = reset
        }
        if changed || lastSelection != selection {
            scene?.rootNode.childNode(withName: "selection", recursively: false)?.removeFromParentNode()
            if let item = document.items.first(where: { $0.id == selection }) {
                let ring = SCNNode()
                ring.name = "selection"; ring.position = SCNVector3(item.x, 0.008, item.z); ring.eulerAngles.y = CGFloat(item.rotation * .pi / 180)
                let c = NSColor(calibratedRed: 0.1, green: 0.5, blue: 0.36, alpha: 1)
                for z in [-item.depth / 2, item.depth / 2] { ring.addChildNode(SceneBuilder.box(item.width + 0.06, 0.012, 0.02, 0, 0, z, c)) }
                for x in [-item.width / 2, item.width / 2] { ring.addChildNode(SceneBuilder.box(0.02, 0.012, item.depth + 0.06, x, 0, 0, c)) }
                scene?.rootNode.addChildNode(ring)
            }
            lastSelection = selection
        }
        needsDisplay = true
    }
    func resetCamera(_ doc: SceneDocument, walk: Bool) {
        let node = SCNNode(); let camera = SCNCamera(); camera.zNear = 0.03; camera.zFar = 200
        camera.wantsHDR = true; camera.exposureOffset = 0.0
        camera.screenSpaceAmbientOcclusionIntensity = 0.8
        camera.screenSpaceAmbientOcclusionRadius = 0.15
        camera.fieldOfView = walk ? 70 : 43
        node.camera = camera
        if walk {
            node.position = SCNVector3(doc.room.doorX + doc.room.doorWidth / 2, min(1.65, doc.room.height - 0.1), 0.45)
            yaw = .pi; pitch = 0; node.eulerAngles = SCNVector3(pitch,yaw,0)
        } else {
            let span = max(doc.room.width, doc.room.depth)
            node.position = SCNVector3(doc.room.width * 1.25, span * 1.15, -doc.room.depth * 1.05)
            node.look(at: SCNVector3(doc.room.width / 2, 0.45, doc.room.depth / 2))
        }
        scene?.rootNode.addChildNode(node); pointOfView = node
    }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        if lastMode != "Walk" {
            let point = convert(event.locationInWindow, from: nil)
            let hits = hitTest(point, options: [.searchMode: SCNHitTestSearchMode.all.rawValue])
            if let item = hits.compactMap({ hit -> String? in
                var node: SCNNode? = hit.node
                while let current = node { if let name = current.name, name.hasPrefix("item:") { return String(name.dropFirst(5)) }; node = current.parent }
                return nil
            }).first { store?.selected = item }
            super.mouseDown(with: event)
        }
    }
    override func mouseDragged(with event: NSEvent) {
        if lastMode == "Walk" {
            yaw -= Float(event.deltaX) * 0.008; pitch = max(-1.1, min(1.1, pitch - Float(event.deltaY) * 0.008))
            pointOfView?.eulerAngles = SCNVector3(pitch, yaw, 0); needsDisplay = true
        } else { super.mouseDragged(with: event) }
    }
    override func keyDown(with event: NSEvent) {
        guard lastMode == "Walk", let doc = lastDocument, let camera = pointOfView else { super.keyDown(with: event); return }
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        if key == "r" { resetCamera(doc, walk: true); needsDisplay = true; return }
        if key == "a" || event.keyCode == 123 { yaw += 0.10 }
        else if key == "d" || event.keyCode == 124 { yaw -= 0.10 }
        else if key == "w" || key == "s" || event.keyCode == 126 || event.keyCode == 125 {
            let distance: Double = key == "s" || event.keyCode == 125 ? -0.10 : 0.10
            let x = Double(camera.position.x) - sin(Double(yaw)) * distance
            let z = Double(camera.position.z) - cos(Double(yaw)) * distance
            let body = Item(name: "Viewer", kind: "person", x: x, z: z, width: 0.4, depth: 0.4, height: 1.65)
            if x >= 0.2, x <= doc.room.width - 0.2, z >= 0.2, z <= doc.room.depth - 0.2, !doc.items.contains(where: { overlaps(body, $0) }) {
                camera.position.x = CGFloat(x); camera.position.z = CGFloat(z)
            }
        } else { super.keyDown(with: event); return }
        camera.eulerAngles = SCNVector3(pitch,yaw,0); needsDisplay = true
    }
}

enum SceneBuilder {
    static let ivory = NSColor(calibratedRed: 0.90, green: 0.89, blue: 0.84, alpha: 1)
    static let white = NSColor(calibratedRed: 0.96, green: 0.955, blue: 0.93, alpha: 1)
    static let oak = NSColor(calibratedRed: 0.58, green: 0.41, blue: 0.24, alpha: 1)
    static let fabric = NSColor(calibratedRed: 0.26, green: 0.40, blue: 0.33, alpha: 1)
    static let dark = NSColor(calibratedRed: 0.16, green: 0.18, blue: 0.18, alpha: 1)
    static func material(_ color: NSColor, roughness: CGFloat = 0.7) -> SCNMaterial {
        let m = SCNMaterial(); m.diffuse.contents = color; m.lightingModel = .physicallyBased
        m.roughness.contents = roughness; m.metalness.contents = 0; return m
    }
    static func box(_ w: Double, _ h: Double, _ d: Double, _ x: Double, _ y: Double, _ z: Double, _ color: NSColor, bevel: Double = 0.003) -> SCNNode {
        let geometry = SCNBox(width: w, height: h, length: d, chamferRadius: min(bevel, min(w,h,d) / 4))
        geometry.materials = [material(color)]
        let node = SCNNode(geometry: geometry); node.position = SCNVector3(x,y,z); return node
    }
    static func sphere(_ radius: Double, _ x: Double, _ y: Double, _ z: Double, _ color: NSColor) -> SCNNode {
        let geometry = SCNSphere(radius: radius); geometry.segmentCount = 20; geometry.materials = [material(color)]
        let node = SCNNode(geometry: geometry); node.position = SCNVector3(x,y,z); return node
    }
    static func build(_ doc: SceneDocument, cutaway: Bool) -> SCNScene {
        let scene = SCNScene(), root = scene.rootNode, r = doc.room
        scene.background.contents = NSColor(calibratedRed: 0.91, green: 0.93, blue: 0.93, alpha: 1)
        let sky = NSImage(size: NSSize(width: 256,height: 128))
        sky.lockFocus()
        NSGradient(starting: NSColor(calibratedRed: 0.73,green: 0.70,blue: 0.63,alpha: 1), ending: NSColor(calibratedRed: 0.92,green: 0.96,blue: 1,alpha: 1))!.draw(in: NSRect(x: 0,y: 0,width: 256,height: 128),angle: 90)
        sky.unlockFocus()
        scene.lightingEnvironment.contents = sky
        scene.lightingEnvironment.intensity = 1.5
        root.addChildNode(box(r.width + 0.12, 0.12, r.depth + 0.12, r.width / 2, -0.07, r.depth / 2, oak))
        let columns = min(34, max(1, Int(r.width / 0.18))), rows = min(8, max(1, Int(r.depth / 0.9)))
        for x in 0..<columns { for z in 0..<rows {
            let w = r.width / Double(columns), d = r.depth / Double(rows)
            let shade = Double((x * 7 + z * 3) % 9) * 0.008
            let c = NSColor(calibratedRed: 0.70 + shade, green: 0.55 + shade, blue: 0.38 + shade, alpha: 1)
            root.addChildNode(box(w - 0.002, 0.018, d - 0.002, Double(x) * w + w / 2, -0.009, Double(z) * d + d / 2, c, bevel: 0))
        } }
        root.addChildNode(box(0.10, r.height, r.depth, -0.05, r.height / 2, r.depth / 2, ivory))
        func north(_ x: Double, _ w: Double, _ y: Double, _ h: Double) {
            if w > 0.001 && h > 0.001 { root.addChildNode(box(w,h,0.10,x,y,r.depth + 0.05,ivory)) }
        }
        north(r.windowX / 2, r.windowX, r.height / 2, r.height)
        let right = r.width - r.windowX - r.windowWidth
        north(r.windowX + r.windowWidth + right / 2, right, r.height / 2,r.height)
        north(r.windowX + r.windowWidth / 2, r.windowWidth, r.windowSill / 2, r.windowSill)
        let above = r.height - r.windowSill - r.windowHeight
        north(r.windowX + r.windowWidth / 2, r.windowWidth, r.height - above / 2, above)
        let glass = box(r.windowWidth, r.windowHeight, 0.015, r.windowX + r.windowWidth / 2, r.windowSill + r.windowHeight / 2, r.depth + 0.03, NSColor(calibratedRed: 0.67, green: 0.82, blue: 0.87, alpha: 1))
        glass.geometry?.firstMaterial?.emission.contents = NSColor(calibratedWhite: 0.35, alpha: 1)
        root.addChildNode(glass)
        for x in [r.windowX, r.windowX + r.windowWidth / 2, r.windowX + r.windowWidth] { root.addChildNode(box(0.035, r.windowHeight, 0.07, x, r.windowSill + r.windowHeight / 2, r.depth - 0.008, white)) }
        for y in [r.windowSill, r.windowSill + r.windowHeight] { root.addChildNode(box(r.windowWidth + 0.05, 0.035, 0.12, r.windowX + r.windowWidth / 2, y, r.depth - 0.025, white)) }
        if !cutaway {
            root.addChildNode(box(r.width,0.10,r.depth,r.width / 2,r.height + 0.05,r.depth / 2,ivory))
            root.addChildNode(box(0.10, r.height, r.depth, r.width + 0.05, r.height / 2, r.depth / 2, ivory))
            for (x,w) in [(r.doorX / 2, r.doorX), ((r.doorX + r.doorWidth + r.width) / 2, r.width - r.doorX - r.doorWidth)] where w > 0.001 {
                root.addChildNode(box(w, r.height, 0.10, x, r.height / 2, -0.05, ivory))
            }
            let doorHeight = min(2.05,r.height)
            if r.height > doorHeight { root.addChildNode(box(r.doorWidth,r.height - doorHeight,0.10,r.doorX + r.doorWidth / 2,(r.height + doorHeight) / 2,-0.05,ivory)) }
        }
        // A threshold shows the open doorway without inventing a measured door leaf.
        root.addChildNode(box(r.doorWidth,0.012,0.10,r.doorX + r.doorWidth / 2,0.006,0,oak))
        for item in doc.items { root.addChildNode(furniture(item)) }
        let ambient = SCNNode(); ambient.light = SCNLight(); ambient.light?.type = .ambient
        ambient.light?.intensity = 430; ambient.light?.color = NSColor(calibratedRed: 0.91, green: 0.95, blue: 1, alpha: 1); root.addChildNode(ambient)
        let sun = SCNNode(); sun.light = SCNLight(); sun.light?.type = .directional; sun.light?.intensity = 1100
        sun.light?.color = NSColor(calibratedRed: 1, green: 0.94, blue: 0.82, alpha: 1)
        sun.light?.castsShadow = true; sun.light?.shadowMode = .forward; sun.light?.shadowRadius = 5
        sun.light?.shadowMapSize = CGSize(width: 2048,height: 2048); sun.light?.shadowSampleCount = 16
        sun.eulerAngles = SCNVector3(-0.85,-0.6,0); root.addChildNode(sun)
        let fill = SCNNode(); fill.light = SCNLight(); fill.light?.type = .omni
        fill.light?.intensity = 650; fill.position = SCNVector3(r.width * 0.7,r.height * 0.9,r.depth * 0.2)
        fill.light?.attenuationStartDistance = 0; fill.light?.attenuationEndDistance = 20
        root.addChildNode(fill)
        return scene
    }
    static func furniture(_ item: Item) -> SCNNode {
        let node = SCNNode(); node.name = "item:" + item.id
        node.position = SCNVector3(item.x,0,item.z); node.eulerAngles.y = CGFloat(item.rotation * .pi / 180)
        let w = item.width, d = item.depth, h = item.height
        let product = Catalog.products.first { $0.id == item.catalogID }
        let wood = product?.series == "TARVA" ? oak : white
        func add(_ a: Double,_ b: Double,_ c: Double,_ x: Double,_ y: Double,_ z: Double,_ color: NSColor) { node.addChildNode(box(a,b,c,x,y,z,color)) }
        // Model all parts inside the verified outer envelope. Interior dimensions,
        // upholstery, joinery and finish are explicitly illustrative.
        switch item.kind {
        case "bed":
            let base = min(0.38,h * 0.5)
            add(w,h,0.045,0,h / 2,d / 2 - 0.0225,wood)
            add(w,base,0.045,0,base / 2,-d / 2 + 0.0225,wood)
            for x in [-w / 2 + 0.025,w / 2 - 0.025] { add(0.05,base * 0.5,d - 0.09,x,base * 0.75,0,wood) }
            add(max(0.01,w - 0.10),h * 0.20,max(0.01,d - 0.10),0,base + h * 0.10,0,white)
            add(max(0.01,w - 0.11),h * 0.05,d * 0.61,0,base + h * 0.225,-d * 0.14,fabric)
            for x in [-w * 0.23,w * 0.23] { add(w * 0.40,h * 0.09,d * 0.19,x,base + h * 0.24,d * 0.32,white) }
        case "desk":
            add(w,h * 0.045,d,0,h * 0.9775,0,wood)
            for x in [-w * 0.45,w * 0.45] { for z in [-d * 0.41,d * 0.41] { add(w * 0.035,h * 0.955,d * 0.07,x,h * 0.4775,z,dark) } }
            add(w * 0.9,h * 0.11,d * 0.92,0,h * 0.87,0,wood)
        case "chair":
            add(w * 0.80,h * 0.07,d * 0.76,0,h * 0.39,-d * 0.06,dark)
            add(w * 0.78,h * 0.57,d * 0.09,0,h * 0.715,d * 0.31,dark)
            add(w * 0.09,h * 0.33,d * 0.09,0,h * 0.165,0,dark)
            add(w,h * 0.03,d * 0.09,0,h * 0.02,0,dark)
            add(w * 0.09,h * 0.03,d,0,h * 0.02,0,dark)
            for x in [-w * 0.47,w * 0.47] { add(w * 0.06,h * 0.04,d * 0.65,x,h * 0.53,-d * 0.08,dark) }
        case "person":
            let color = NSColor(calibratedRed: 0.67,green: 0.42,blue: 0.25,alpha: 1)
            node.addChildNode(sphere(min(w,d) * 0.22,0,h - min(w,d) * 0.22,0,color))
            add(w * 0.70,h * 0.34,d * 0.45,0,h * 0.63,0,fabric)
            for x in [-w * 0.18,w * 0.18] { add(w * 0.20,h * 0.46,d * 0.34,x,h * 0.23,0,dark) }
        default:
            let t = min(0.02,min(w,d,h) * 0.05)
            let green = product?.series == "HEMNES"
            let color = green ? fabric : wood
            add(w,t,d,0,h - t / 2,0,color); add(w,t,d,0,t / 2,0,color)
            for x in [-w / 2 + t / 2,w / 2 - t / 2] { add(t,h,d,x,h / 2,0,color) }
            if item.kind != "shelving" { add(w,h,t,0,h / 2,d / 2 - t / 2,color) }
            if ["bookcase","shelving","wardrobe_frame"].contains(item.kind) {
                let levels = item.kind == "bookcase" ? 6 : item.kind == "shelving" ? 4 : 1
                for level in 1..<levels { add(w,t,d,0,h * Double(level) / Double(levels),0,color) }
                if item.kind == "shelving" { add(t,h,d,0,h / 2,0,color) }
            } else {
                let count = item.kind == "wardrobe" ? 3 : item.kind == "chest" ? 3 : 2
                if item.kind == "wardrobe" {
                    for i in 0..<count {
                        let dw = (w - 2 * t) / Double(count)
                        let x = -w / 2 + t + dw * (Double(i) + 0.5)
                        add(dw - 0.004,h - 2 * t,t,x,h / 2,-d / 2 + t / 2,color)
                        add(0.012,h * 0.08,0.018,x + dw * 0.3,h * 0.5,-d / 2 + 0.009,dark)
                    }
                } else {
                    for i in 0..<count {
                        let dh = (h - 2 * t) / Double(count)
                        add(w - 2 * t,dh - 0.008,t,0,t + dh * (Double(i) + 0.5),-d / 2 + t / 2,color)
                    }
                }
            }
        }
        return node
    }
}

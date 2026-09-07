import SceneKit
import StubliCore
import simd

@MainActor
enum FurnitureGeometry {
    static let chalk = NSColor(calibratedRed: 0.87,green: 0.87,blue: 0.82,alpha: 1)
    static let cotton = NSColor(calibratedRed: 0.87,green: 0.83,blue: 0.71,alpha: 1)
    static let sage = NSColor(calibratedRed: 0.30,green: 0.40,blue: 0.32,alpha: 1)
    static let graphite = NSColor(calibratedRed: 0.07,green: 0.075,blue: 0.07,alpha: 1)

    static func cushion(width: Double, depth: Double, height: Double, material: SCNMaterial, folds: Double = 0.008) -> SCNNode {
        // Closed superellipsoid. Soft fullness and a thin perimeter replace box pillows.
        let columns = 48, rows = 24
        var vertices: [SCNVector3] = [], normals: [SCNVector3] = [], uv: [CGPoint] = [], indices: [Int32] = []
        func signed(_ x: Double,_ p: Double) -> Double { (x < 0 ? -1 : 1) * pow(abs(x),p) }
        func point(_ u: Double,_ v: Double) -> SIMD3<Double> {
            let lat = (v - 0.5) * .pi, lon = u * .pi * 2
            let cp = signed(cos(lat),0.46)
            let x = width / 2 * cp * signed(cos(lon),0.35)
            let z = depth / 2 * cp * signed(sin(lon),0.35)
            let ripples = folds * sin(u * 51 + v * 7) * sin(v * .pi) * pow(abs(sin(lat)),0.4)
            let y = height / 2 * signed(sin(lat),0.70) + ripples
            return SIMD3(x,y,z)
        }
        for row in 0...rows { for col in 0...columns {
            let u = Double(col) / Double(columns), v = Double(row) / Double(rows), p = point(u,v)
            let du = point(u + 0.0001,v) - point(u - 0.0001,v)
            let dv = point(u,min(0.99999,v + 0.0001)) - point(u,max(0.00001,v - 0.0001))
            var normal = simd_cross(dv,du)
            if simd_length(normal) < 0.000001 { normal = SIMD3(0,v > 0.5 ? 1 : -1,0) } else { normal = simd_normalize(normal) }
            vertices.append(SCNVector3(p.x,p.y,p.z)); normals.append(SCNVector3(normal.x,normal.y,normal.z)); uv.append(CGPoint(x: u,y: v))
        } }
        for row in 0..<rows { for col in 0..<columns {
            let a = Int32(row * (columns + 1) + col), b = a + 1, c = a + Int32(columns + 1), d = c + 1
            indices += [a,c,b,b,c,d]
        } }
        let g = SCNGeometry(sources: [SCNGeometrySource(vertices: vertices),SCNGeometrySource(normals: normals),SCNGeometrySource(textureCoordinates: uv)], elements: [SCNGeometryElement(indices: indices,primitiveType: .triangles)])
        g.materials = [material]; return SCNNode(geometry: g)
    }
    static func rod(from: SCNVector3, to: SCNVector3, radius: Double, material: SCNMaterial) -> SCNNode {
        let a = SIMD3<Double>(Double(from.x),Double(from.y),Double(from.z)), b = SIMD3<Double>(Double(to.x),Double(to.y),Double(to.z))
        let delta = b - a, length = simd_length(delta)
        let g = SCNCylinder(radius: radius,height: max(0.001,length));g.radialSegmentCount = 12;g.materials = [material]
        let n = SCNNode(geometry: g);n.position = SCNVector3((a.x+b.x)/2,(a.y+b.y)/2,(a.z+b.z)/2)
        if length > 0.0001 { n.simdOrientation = simd_quatf(from: SIMD3<Float>(0,1,0),to: simd_normalize(SIMD3<Float>(delta))) }
        return n
    }
    static func make(_ item: Item) -> SCNNode {
        let root = SCNNode(); root.name = "item:" + item.id;root.position = SCNVector3(item.x,0,item.z);root.eulerAngles.y = CGFloat(item.rotation * .pi / 180)
        let w = item.width, d = item.depth, h = item.height
        let product = Catalog.products.first { $0.id == item.catalogID }
        let lacquer = Materials.finish(chalk,roughness: 0.4)
        let wood = product?.series == "TARVA" ? Materials.wood(width: 1,depth: 1) : lacquer
        let steel = Materials.finish(graphite,metal: 0.65,roughness: 0.33)
        let linen = Materials.cloth(cotton)
        func box(_ width: Double,_ height: Double,_ depth: Double,_ x: Double,_ y: Double,_ z: Double,_ mat: SCNMaterial,_ bevel: Double = 0.004) -> SCNNode {
            let g = SCNBox(width: max(width,0.001),height: max(height,0.001),length: max(depth,0.001),chamferRadius: max(0,min(bevel,min(width,height,depth)/3)))
            g.chamferSegmentCount = 3;g.materials = [mat]
            let n = SCNNode(geometry: g);n.position = SCNVector3(x,y,z);return n
        }
        func add(_ width: Double,_ height: Double,_ depth: Double,_ x: Double,_ y: Double,_ z: Double,_ mat: SCNMaterial,_ bevel: Double = 0.004) {root.addChildNode(box(width,height,depth,x,y,z,mat,bevel))}
        func soft(_ width: Double,_ depth: Double,_ height: Double,_ x: Double,_ y: Double,_ z: Double,_ mat: SCNMaterial,_ fold: Double = 0.008) -> SCNNode {
            let n = cushion(width: width,depth: depth,height: height,material: mat,folds: fold);n.position = SCNVector3(x,y,z);root.addChildNode(n);return n
        }
        switch item.kind {
        case "bed":
            let base = min(0.38,h * 0.43), thickness = min(0.045,w * 0.035)
            if product?.series == "TARVA" {
                for x in [-w/2+thickness/2,w/2-thickness/2] {add(thickness,h,thickness,x,h/2,d/2-thickness/2,wood)}
                add(w,h*0.11,thickness,0,h*0.945,d/2-thickness/2,wood)
                add(w,h*0.10,thickness,0,h*0.69,d/2-thickness/2,wood)
                for i in 0..<8 {add(w/80,h*0.2,thickness*0.5,-w*0.43+w*0.86*Double(i)/7,h*0.80,d/2-thickness/2,wood)}
            } else {add(w,h,thickness,0,h/2,d/2-thickness/2,wood)}
            add(w,base,thickness,0,base/2,-d/2+thickness/2,wood)
            for x in [-w/2+thickness/2,w/2-thickness/2] {add(thickness,base*0.42,d-thickness*2,x,base*0.79,0,wood)}
            let mattressTop = base + h*0.20
            _ = soft(w-thickness*2,d-thickness*2,h*0.20,0,base+h*0.10,0,linen,0.003)
            // Duvet has rounded fullness, a turned-back fold and a slight asymmetric drape.
            _ = soft(w-thickness*2,d*0.69,h*0.095,0,mattressTop+h*0.025,-d*0.13,Materials.cloth(sage),0.012)
            let fold = soft(w*0.91,d*0.14,h*0.07,0,mattressTop+h*0.065,d*0.17,Materials.cloth(sage.blended(withFraction: 0.12,of: .white)!),0.006)
            fold.eulerAngles.x = -0.04
            for (i,x) in [-w*0.235,w*0.235].enumerated() {
                let pillow = soft(w*0.40,d*0.22,h*0.14,x,mattressTop+h*0.06,d*0.32,linen,0.005)
                pillow.eulerAngles.y = i == 0 ? 0.04 : -0.055
            }
        case "desk":
            let top = h*0.04
            add(w,top,d,0,h-top/2,0,wood)
            let isWide = product?.articleNumber == "802.130.74"
            let cabinetWidth = isWide ? w*0.30 : w*0.035
            add(cabinetWidth,h-top,d*0.95,-w/2+cabinetWidth/2,(h-top)/2,0,wood)
            // MICKE's steel loop on the opposite side, rather than four generic legs.
            let x = w/2-w*0.025
            for z in [-d*0.43,d*0.43] {add(w*0.025,h-top,d*0.04,x,(h-top)/2,z,steel)}
            add(w*0.025,h*0.025,d*0.89,x,h*0.0125,0,steel)
            let drawerWidth = w-cabinetWidth-w*0.045, dx = cabinetWidth/2
            add(drawerWidth,h*0.115,d*0.87,dx,h*0.90,-item.openingDistance,wood)
            add(drawerWidth*0.94,0.008,0.005,dx,h*0.958,-d*0.435-item.openingDistance,steel)
            if isWide {add(cabinetWidth-0.012,h*0.78,0.018,-w/2+cabinetWidth/2,h*0.44,-d*0.485,wood)}
        case "chair":
            let scale = h/1.4
            _ = soft(w*0.84,d*0.76,0.085*scale,0,0.51*scale,-d*0.06,Materials.cloth(graphite),0.001)
            let mesh = Materials.cloth(graphite,repeatCount: 7)
            // Gently curved tensioned back. Struts remain visible around the fabric.
            let back = soft(w*0.76,0.052,h*0.61,0,h*0.685,d*0.30,mesh,0.001)
            back.eulerAngles.x = -0.06
            _ = soft(w*0.72,0.095,h*0.13,0,h*0.93,d*0.28,Materials.cloth(graphite),0.001)
            root.addChildNode(rod(from: SCNVector3(0,0.08,0),to: SCNVector3(0,0.47*scale,0),radius: w*0.036,material: steel))
            for i in 0..<5 {
                let angle = Double(i)*2*Double.pi/5
                let end = SCNVector3(sin(angle)*w*0.45,0.065,cos(angle)*d*0.45)
                root.addChildNode(rod(from: SCNVector3(0,0.12,0),to: end,radius: w*0.022,material: steel))
                let caster = SCNCylinder(radius: 0.028*scale,height: 0.045*scale);caster.materials = [steel];caster.radialSegmentCount = 16
                let n = SCNNode(geometry: caster);n.position = SCNVector3(end.x,0.032*scale,end.z);n.eulerAngles.z = .pi/2;root.addChildNode(n)
            }
            for x in [-w*0.46,w*0.46] {
                root.addChildNode(rod(from: SCNVector3(x*0.72,h*0.37,0),to: SCNVector3(x,h*0.49,d*0.1),radius: 0.014*scale,material: steel))
                add(w*0.08,h*0.026,d*0.58,x,h*0.51,-d*0.05,Materials.finish(graphite,roughness: 0.8),0.012)
            }
        case "person":
            // Clear, non-photoreal people markers show occupied space without fake faces.
            let bodyMat = Materials.finish(NSColor(calibratedRed: 0.52,green: 0.38,blue: 0.23,alpha: 1),roughness: 0.9)
            bodyMat.transparency = 0.65
            let radius = min(w,d)*0.24
            let head = SCNSphere(radius: radius);head.segmentCount = 24;head.materials = [bodyMat]
            let hn = SCNNode(geometry: head);hn.position = SCNVector3(0,h-radius,0);root.addChildNode(hn)
            let torso = SCNCapsule(capRadius: min(w,d)*0.31,height: h*0.43);torso.radialSegmentCount = 24;torso.materials = [bodyMat]
            let tn = SCNNode(geometry: torso);tn.position = SCNVector3(0,h*0.63,0);root.addChildNode(tn)
            for x in [-w*0.17,w*0.17] {root.addChildNode(rod(from: SCNVector3(x,0.05,0),to: SCNVector3(x,h*0.43,0),radius: min(w,d)*0.12,material: bodyMat))}
        default:
            let t = min(0.018,min(w,d,h)*0.05)
            let finish = product?.series == "HEMNES" ? Materials.finish(sage,roughness: 0.6) : wood
            if product?.series == "HEMNES" {
                for x in [-w/2+t,w/2-t] {for z in [-d/2+t,d/2-t] {add(t*1.5,h,t*1.5,x,h/2,z,finish)}}
                add(w,t,d,0,h-t/2,0,Materials.wood(width: w,depth: d))
                add(w-t*2,t,d-t*2,0,h*0.37,0,finish)
                add(w-t*2,h*0.20,d-t*2,0,h*0.85,-item.openingDistance,finish)
                let knob = SCNSphere(radius: 0.009);knob.materials = [steel];let n = SCNNode(geometry: knob);n.position = SCNVector3(0,h*0.85,-d/2-item.openingDistance);root.addChildNode(n)
                return root
            }
            add(w,t,d,0,h-t/2,0,finish);add(w,t,d,0,t/2,0,finish)
            for x in [-w/2+t/2,w/2-t/2] {add(t,h,d,x,h/2,0,finish)}
            if item.kind != "shelving" {add(w,h,t,0,h/2,d/2-t/2,finish)}
            if ["bookcase","shelving","wardrobe_frame"].contains(item.kind) {
                let levels = item.kind == "bookcase" ? 6 : item.kind == "shelving" ? 4 : 1
                for i in 1..<levels {add(w,t,d,0,h*Double(i)/Double(levels),0,finish)}
                if item.kind == "shelving" {add(t,h,d,0,h/2,0,finish)}
                if item.kind == "wardrobe_frame" {root.addChildNode(rod(from: SCNVector3(-w*0.46,h*0.86,0),to: SCNVector3(w*0.46,h*0.86,0),radius: 0.012,material: steel))}
            } else if item.kind == "wardrobe" {
                for i in 0..<3 {
                    let dw = (w-2*t)/3, hingeX = -w/2+t+dw*Double(i)
                    let hinge = SCNNode();hinge.position = SCNVector3(hingeX,0,-d/2+t/2)
                    hinge.eulerAngles.y = CGFloat((item.openFraction ?? 0)*Double.pi/2)
                    hinge.addChildNode(box(dw-0.003,h-t*2,t,dw/2,h/2,0,finish))
                    hinge.addChildNode(box(0.012,h*0.08,0.018,dw*0.85,h*0.5,-0.012,steel))
                    root.addChildNode(hinge)
                }
                for y in [h*0.25,h*0.50,h*0.75] {add(w*0.3,t,d*0.92,w*0.32,y,0,finish)}
            } else {
                let count = item.kind == "chest" ? 3 : 2, inner = Materials.wood(width: w,depth: d)
                for i in 0..<count {
                    let dh = (h-2*t)/Double(count), y = t+dh*(Double(i)+0.5)
                    let travel = item.openingDistance
                    add(w-2*t,dh-0.007,t,0,y,-d/2+t/2-travel,finish)
                    if travel > 0 {
                        add(w-t*3,t,d*0.85,0,y-dh*0.42,-travel,inner)
                        for x in [-w/2+t*1.5,w/2-t*1.5] {add(t,dh*0.7,d*0.85,x,y,-travel,inner)}
                    }
                }
            }
        }
        return root
    }
}

import SwiftUI
import StubliCore

struct PlanView: View {
    @EnvironmentObject var store: EditorStore
    @LegacyState private var dragOrigin: Item?
    var body: some View {
        GeometryReader { geometry in
            let room = store.document.room
            let scale = max(1, min((geometry.size.width - 104) / room.width, (geometry.size.height - 120) / room.depth))
            let width = room.width * scale, depth = room.depth * scale
            let ox = (geometry.size.width - width) / 2, oy = (geometry.size.height - depth) / 2 - 8
            ZStack(alignment: .topLeading) {
                Color(red: 0.95, green: 0.95, blue: 0.93).onTapGesture { store.selected = nil }
                Canvas { context, size in
                    let bounds = CGRect(x: ox, y: oy, width: width, height: depth)
                    context.fill(Path(bounds), with: .color(Color(red: 0.99, green: 0.985, blue: 0.965)))
                    for x in 0...Int(room.width * 10) {
                        var line = Path(); line.move(to: CGPoint(x: ox + Double(x) * scale / 10, y: oy)); line.addLine(to: CGPoint(x: ox + Double(x) * scale / 10, y: oy + depth))
                        context.stroke(line, with: .color(.black.opacity(x % 10 == 0 ? 0.10 : 0.035)), lineWidth: 0.7)
                    }
                    for z in 0...Int(room.depth * 10) {
                        var line = Path(); line.move(to: CGPoint(x: ox, y: oy + Double(z) * scale / 10)); line.addLine(to: CGPoint(x: ox + width, y: oy + Double(z) * scale / 10))
                        context.stroke(line, with: .color(.black.opacity(z % 10 == 0 ? 0.10 : 0.035)), lineWidth: 0.7)
                    }
                    context.stroke(Path(bounds), with: .color(Color(red: 0.33, green: 0.37, blue: 0.33)), lineWidth: 5)
                    let door = CGRect(x: ox + room.doorX * scale, y: oy + depth - 4, width: room.doorWidth * scale, height: 8)
                    context.fill(Path(door), with: .color(Color(red: 0.95, green: 0.95, blue: 0.93)))
                    var swing = Path()
                    let hinge = CGPoint(x: ox + room.doorX * scale, y: oy + depth)
                    swing.move(to: hinge); swing.addLine(to: CGPoint(x: hinge.x, y: hinge.y - room.doorWidth * scale))
                    swing.addArc(center: hinge, radius: room.doorWidth * scale, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
                    context.stroke(swing, with: .color(.brown.opacity(0.55)), style: StrokeStyle(lineWidth: 1.2, dash: [4,3]))
                    let window = CGRect(x: ox + room.windowX * scale, y: oy - 3, width: room.windowWidth * scale, height: 6)
                    context.fill(Path(window), with: .color(Color(red: 0.43, green: 0.66, blue: 0.74)))
                    context.draw(Text("\(measure(room.width)) m").font(.caption).foregroundColor(.secondary), at: CGPoint(x: ox + width / 2, y: oy - 25))
                    context.draw(Text("\(measure(room.depth)) m").font(.caption).foregroundColor(.secondary), at: CGPoint(x: max(22, ox - 29), y: oy + depth / 2))
                    context.draw(Text("ENTRY").font(.system(size: 9, weight: .medium)).foregroundColor(.secondary), at: CGPoint(x: hinge.x + room.doorWidth * scale / 2, y: oy + depth + 18))
                    for (index, route) in store.routes.enumerated() where route.reachable {
                        var path = Path()
                        for (i, point) in route.points.enumerated() {
                            let p = CGPoint(x: ox + point[0] * scale, y: oy + depth - point[1] * scale)
                            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
                        }
                        context.stroke(path, with: .color(index % 2 == 0 ? pine : .orange), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [7,5]))
                    }
                }.allowsHitTesting(false)
                ForEach(store.document.openingEnvelopes, id: \.volume.id) { opening in
                    let volume = opening.volume
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.orange.opacity(0.12))
                        .overlay { RoundedRectangle(cornerRadius: 3).stroke(Color.orange.opacity(0.8), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])) }
                        .frame(width: max(volume.width * scale, 5), height: max(volume.depth * scale, 5))
                        .rotationEffect(.degrees(volume.rotation))
                        .position(x: ox + volume.x * scale, y: oy + depth - volume.z * scale)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                ForEach(store.document.items) { item in
                    let selected = store.selected == item.id
                    let w = item.width * scale, d = item.depth * scale
                    ZStack {
                        if item.kind == "person" {
                            Circle().fill(selected ? pine : Color(red: 0.62, green: 0.46, blue: 0.30))
                            Image(systemName: "person.fill").font(.system(size: max(10, min(w * 0.4, 22)))).foregroundStyle(.white)
                        } else {
                            RoundedRectangle(cornerRadius: 3).fill(selected ? pine.opacity(0.16) : Color(red: 0.85, green: 0.81, blue: 0.72))
                            RoundedRectangle(cornerRadius: 3).stroke(selected ? pine : Color(red: 0.56, green: 0.53, blue: 0.46), lineWidth: selected ? 2.5 : 1)
                            if item.kind == "bed" {
                                VStack(spacing: 2) {
                                    HStack(spacing: 4) { RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.85)); RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.85)) }.frame(height: d * 0.18).padding(6)
                                    RoundedRectangle(cornerRadius: 2).fill(pine.opacity(0.12)).padding(.horizontal, 5).padding(.bottom, 5)
                                }
                            }
                            Text(item.name.components(separatedBy: " ").first ?? item.name).font(.system(size: 11, weight: .medium)).foregroundStyle(pine).lineLimit(1).minimumScaleFactor(0.5).padding(3).rotationEffect(.degrees(-item.rotation))
                        }
                    }
                    .frame(width: max(w, 5), height: max(d, 5))
                    .rotationEffect(.degrees(item.rotation))
                    .position(x: ox + item.x * scale, y: oy + depth - item.z * scale)
                    .onTapGesture { store.selected = item.id }
                    .gesture(DragGesture(minimumDistance: 2, coordinateSpace: .named("plan")).onChanged { value in
                        if dragOrigin == nil { dragOrigin = item; store.checkpoint(); store.selected = item.id }
                        guard let origin = dragOrigin else { return }
                        store.move(item.id, x: origin.x + value.translation.width / scale, z: origin.z - value.translation.height / scale)
                    }.onEnded { _ in dragOrigin = nil })
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(item.name), \(measure(item.width)) by \(measure(item.depth)) metres")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { store.selected = item.id }
                }
            }.coordinateSpace(name: "plan").clipped()
        }
    }
}

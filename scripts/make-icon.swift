import AppKit
let folder = URL(fileURLWithPath: CommandLine.arguments[1])
let iconset = folder.appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16,32,128,256,512] {
    for multiplier in [1,2] {
        let pixels = size * multiplier
        let image = NSImage(size: NSSize(width: pixels,height: pixels))
        image.lockFocus()
        let context = NSGraphicsContext.current!.cgContext
        context.scaleBy(x: CGFloat(pixels) / 1024,y: CGFloat(pixels) / 1024)
        NSColor(calibratedRed: 0.13,green: 0.29,blue: 0.25,alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 24,y: 24,width: 976,height: 976),xRadius: 220,yRadius: 220).fill()
        let room = NSBezierPath(); room.move(to: NSPoint(x: 246,y: 315)); room.line(to: NSPoint(x: 246,y: 740)); room.line(to: NSPoint(x: 778,y: 740)); room.line(to: NSPoint(x: 778,y: 284)); room.line(to: NSPoint(x: 425,y: 284))
        NSColor(calibratedRed: 0.93,green: 0.91,blue: 0.83,alpha: 1).setStroke(); room.lineWidth = 40; room.lineJoinStyle = .round; room.lineCapStyle = .round; room.stroke()
        NSColor(calibratedRed: 0.77,green: 0.66,blue: 0.46,alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 460,y: 385,width: 205,height: 265),xRadius: 18,yRadius: 18).fill()
        NSColor(calibratedRed: 0.96,green: 0.95,blue: 0.89,alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 480,y: 576,width: 165,height: 54),xRadius: 10,yRadius: 10).fill()
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let name = "icon_\(size)x\(size)\(multiplier == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png,properties: [:])!.write(to: iconset.appendingPathComponent(name))
    }
}
let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c","icns",iconset.path,"-o",folder.appendingPathComponent("AppIcon.icns").path]
try process.run(); process.waitUntilExit()
if process.terminationStatus != 0 { exit(process.terminationStatus) }
try FileManager.default.removeItem(at: iconset)

import AppKit
import Foundation

let output = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
let icons = [("icon_16x16",16), ("icon_16x16@2x",32), ("icon_32x32",32),
             ("icon_32x32@2x",64), ("icon_128x128",128), ("icon_128x128@2x",256),
             ("icon_256x256",256), ("icon_256x256@2x",512), ("icon_512x512",512),
             ("icon_512x512@2x",1024)]
for (name, size) in icons {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                 isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    let background = NSBezierPath(roundedRect: NSRect(x: 56,y: 56,width: 912,height: 912), xRadius: 210,yRadius: 210)
    NSGradient(colors: [NSColor(srgbRed: 0.12,green: 0.19,blue: 0.24,alpha: 1),
                        NSColor(srgbRed: 0.035,green: 0.06,blue: 0.10,alpha: 1)])!.draw(in: background,angle: -45)
    let mint = NSColor(srgbRed: 0.42,green: 0.94,blue: 0.72,alpha: 1)
    mint.setStroke()
    let glass = NSBezierPath()
    glass.move(to: NSPoint(x: 340,y: 755)); glass.line(to: NSPoint(x: 684,y: 755))
    glass.curve(to: NSPoint(x: 558,y: 512),controlPoint1: NSPoint(x: 684,y: 622),controlPoint2: NSPoint(x: 574,y: 558))
    glass.curve(to: NSPoint(x: 684,y: 269),controlPoint1: NSPoint(x: 574,y: 466),controlPoint2: NSPoint(x: 684,y: 402))
    glass.line(to: NSPoint(x: 340,y: 269))
    glass.curve(to: NSPoint(x: 466,y: 512),controlPoint1: NSPoint(x: 340,y: 402),controlPoint2: NSPoint(x: 450,y: 466))
    glass.curve(to: NSPoint(x: 340,y: 755),controlPoint1: NSPoint(x: 450,y: 558),controlPoint2: NSPoint(x: 340,y: 622))
    glass.close(); glass.lineWidth = 42; glass.lineJoinStyle = .round; glass.stroke()
    mint.setFill()
    let sand = NSBezierPath()
    sand.move(to: NSPoint(x: 389,y: 667)); sand.line(to: NSPoint(x: 635,y: 667))
    sand.curve(to: NSPoint(x: 512,y: 550),controlPoint1: NSPoint(x: 619,y: 615),controlPoint2: NSPoint(x: 551,y: 581))
    sand.curve(to: NSPoint(x: 389,y: 667),controlPoint1: NSPoint(x: 473,y: 581),controlPoint2: NSPoint(x: 405,y: 615))
    sand.close(); sand.fill()
    let base = NSBezierPath()
    base.move(to: NSPoint(x: 389,y: 315)); base.line(to: NSPoint(x: 635,y: 315))
    base.line(to: NSPoint(x: 512,y: 420)); base.close(); base.fill()
    NSBezierPath(ovalIn: NSRect(x: 499,y: 468,width: 26,height: 26)).fill()
    NSGraphicsContext.restoreGraphicsState()
    let png = bitmap.representation(using: .png, properties: [:])!
    try png.write(to: URL(fileURLWithPath: "\(output)/\(name).png"))
}

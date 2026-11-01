import AppKit

let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

func renderIcon(pixels: Int, fileName: String) throws {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    defer { NSGraphicsContext.restoreGraphicsState() }
    let scale = CGFloat(pixels) / 1024
    let transform = NSAffineTransform()
    transform.scale(by: scale)
    transform.concat()

    let rect = NSRect(x: 42, y: 42, width: 940, height: 940)
    let shape = NSBezierPath(roundedRect: rect, xRadius: 210, yRadius: 210)
    NSGradient(starting: NSColor(red: 0.23, green: 0.52, blue: 0.96, alpha: 1),
               ending: NSColor(red: 0.12, green: 0.32, blue: 0.72, alpha: 1))!
        .draw(in: shape, angle: -80)
    let symbol = NSImage(systemSymbolName: "character.bubble.fill", accessibilityDescription: nil)!
        .withSymbolConfiguration(.init(paletteColors: [.white]))!
    symbol.draw(in: NSRect(x: 209, y: 247, width: 606, height: 550))

    let arrows = NSImage(systemSymbolName: "arrow.left.arrow.right", accessibilityDescription: nil)!
        .withSymbolConfiguration(.init(paletteColors: [.white]))!
    arrows.draw(in: NSRect(x: 423, y: 147, width: 178, height: 100))
    let data = bitmap.representation(using: .png, properties: [:])!
    try data.write(to: directory.appendingPathComponent(fileName))
}

for size in [16, 32, 128, 256, 512] {
    try renderIcon(pixels: size, fileName: "icon_\(size)x\(size).png")
    try renderIcon(pixels: size * 2, fileName: "icon_\(size)x\(size)@2x.png")
}

// Modern ICNS representations contain PNG data. Write the standard container
// directly so packaging does not depend on iconutil's image-conversion service.
func uint32(_ value: Int) -> Data {
    var number = UInt32(value).bigEndian
    return withUnsafeBytes(of: &number) { Data($0) }
}
var representations = Data()
for (type, name) in [
    ("icp4", "icon_16x16.png"), ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"), ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"), ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png"), ("ic11", "icon_16x16@2x.png"),
    ("ic12", "icon_32x32@2x.png"), ("ic13", "icon_128x128@2x.png"),
    ("ic14", "icon_256x256@2x.png")
] {
    let png = try Data(contentsOf: directory.appendingPathComponent(name))
    representations.append(Data(type.utf8))
    representations.append(uint32(png.count + 8))
    representations.append(png)
}
var icon = Data("icns".utf8)
icon.append(uint32(representations.count + 8))
icon.append(representations)
let destination = URL(fileURLWithPath: CommandLine.arguments[2])
try icon.write(to: destination)
guard NSImage(contentsOf: destination)?.isValid == true else {
    fatalError("Generated app icon could not be loaded by AppKit")
}

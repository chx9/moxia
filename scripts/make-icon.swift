// 生成应用图标：暖白圆角底 + 墨色「墨」字 + 朱砂印点
// 用法：swift scripts/make-icon.swift <输出 .iconset 目录>
import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func draw(size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // macOS 图标网格：内容区约占 824/1024
    let inset = size * 100 / 1024
    let rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let radius = rect.width * 0.225
    let shape = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    shadow.shadowBlurRadius = size * 0.02
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.008)
    shadow.set()
    NSColor(srgbRed: 0.976, green: 0.965, blue: 0.945, alpha: 1).setFill()
    shape.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    let font = NSFont(name: "Songti SC Bold", size: rect.width * 0.56) ?? .boldSystemFont(ofSize: rect.width * 0.56)
    let glyph = NSAttributedString(string: "墨", attributes: [
        .font: font, .foregroundColor: NSColor(srgbRed: 0.16, green: 0.15, blue: 0.14, alpha: 1),
    ])
    let glyphSize = glyph.size()
    glyph.draw(at: NSPoint(x: rect.midX - glyphSize.width / 2, y: rect.midY - glyphSize.height / 2 + rect.height * 0.02))

    let seal = rect.width * 0.12
    let sealRect = NSRect(x: rect.maxX - seal - rect.width * 0.12, y: rect.minY + rect.width * 0.12, width: seal, height: seal)
    NSColor(srgbRed: 0.66, green: 0.25, blue: 0.18, alpha: 1).setFill()
    NSBezierPath(roundedRect: sealRect, xRadius: seal * 0.18, yRadius: seal * 0.18).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        let data = draw(size: CGFloat(base * scale)).representation(using: .png, properties: [:])!
        try! data.write(to: output.appendingPathComponent(name))
    }
}

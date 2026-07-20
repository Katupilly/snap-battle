// SPIKE: helper for Round 2 measurement/annotation. Disposable, not part of any spec.
// SPIKE helper: measure pill/button geometry and draw annotation lines on screenshots.
// Usage:
//   swift tool.swift measure <png>
//   swift tool.swift annotate <in.png> <out.png> <pillCenterYpt> <btnCenterYpt> <gapX1pt> <gapX2pt>
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func load(_ path: String) -> (CGImage, UnsafeMutablePointer<UInt8>, Int, Int, Int) {
    let url = URL(fileURLWithPath: path) as CFURL
    let src = CGImageSourceCreateWithURL(url, nil)!
    let img = CGImageSourceCreateImageAtIndex(src, 0, nil)!
    let w = img.width, h = img.height, bpr = w * 4
    let data = UnsafeMutablePointer<UInt8>.allocate(capacity: bpr * h)
    let ctx = CGContext(data: data, width: w, height: h, bitsPerComponent: 8,
                        bytesPerRow: bpr, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    return (img, data, w, h, bpr)
}

let args = CommandLine.arguments
let mode = args[1]

if mode == "measure" {
    let (_, d, w, h, bpr) = load(args[2])
    func px(_ x: Int, _ y: Int) -> (Int, Int, Int) {
        let o = y * bpr + x * 4
        return (Int(d[o]), Int(d[o+1]), Int(d[o+2]))
    }
    print("size px \(w)x\(h)  pt \(w/3)x\(h/3)")
    print("bg", px(60, 1200))
    func bright(_ x: Int, _ y: Int) -> Bool {
        let (r, g, b) = px(x, y); return r > 245 && g > 245 && b > 246
    }
    // bright rows in bottom band
    var rowCount = [(Int, Int)]()
    for y in stride(from: 2200, to: h, by: 1) {
        var c = 0
        for x in stride(from: 0, to: w, by: 3) { if bright(x, y) { c += 1 } }
        if c > 5 { rowCount.append((y, c)) }
    }
    guard let y0 = rowCount.first?.0, let y1 = rowCount.last?.0 else { print("no bright rows"); exit(1) }
    print("bright rows span px \(y0)-\(y1)  pt \(y0/3)-\(y1/3)")
    // column clusters
    var colHas = [Int]()
    for x in stride(from: 0, to: w, by: 3) {
        var c = 0
        for y in stride(from: y0, to: y1, by: 1) { if bright(x, y) { c += 1 } }
        if c > 5 { colHas.append(x) }
    }
    var clusters = [(Int, Int)]()
    var start = colHas[0], prev = colHas[0]
    for x in colHas.dropFirst() {
        if x - prev > 30 { clusters.append((start, prev)); start = x }
        prev = x
    }
    clusters.append((start, prev))
    for (i, (a, b)) in clusters.enumerated() {
        var top = h, bot = 0
        for y in stride(from: y0, to: min(y1 + 1, h), by: 1) {
            var hit = false
            for x in stride(from: a, to: b, by: 3) { if bright(x, y) { hit = true; break } }
            if hit { top = min(top, y); bot = max(bot, y) }
        }
        print(String(format: "cluster%d: x pt %.1f-%.1f  y pt %.1f-%.1f  centerY pt %.1f  h pt %.1f",
                     i, Double(a)/3, Double(b)/3, Double(top)/3, Double(bot)/3,
                     Double(top + bot)/6, Double(bot - top)/3))
    }
} else if mode == "annotate" {
    let (img, _, w, h, _) = load(args[2])
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                        bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    let s = 3.0 // pt -> px
    func yPx(_ pt: Double) -> CGFloat { CGFloat(h) - CGFloat(pt) * s } // flip: pt from top
    let pillY = Double(args[4])!, btnY = Double(args[5])!
    let gx1 = Double(args[6])!, gx2 = Double(args[7])!
    ctx.setLineWidth(3)
    // pill center: green
    ctx.setStrokeColor(CGColor(red: 0, green: 0.8, blue: 0, alpha: 1))
    ctx.stroke(CGRect(x: 0, y: yPx(pillY) - 1.5, width: CGFloat(w), height: 3))
    // button center: red
    ctx.setStrokeColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
    ctx.stroke(CGRect(x: 0, y: yPx(btnY) - 1.5, width: CGFloat(w), height: 3))
    // horizontal gap: blue double arrow line at mid height
    let midY = yPx((pillY + btnY) / 2) - 120
    ctx.setStrokeColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
    ctx.stroke(CGRect(x: CGFloat(gx1) * s, y: midY - 1.5, width: CGFloat(gx2 - gx1) * s, height: 3))
    // delta label background (draw simple bars as text substitute is overkill; use quartz text)
    let out = ctx.makeImage()!
    let url = URL(fileURLWithPath: args[3]) as CFURL
    let dest = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, out, nil)
    CGImageDestinationFinalize(dest)
    print("annotated ->", args[3])
}

import AppKit
import CoreGraphics

let W = 1024
let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: W, height: W, bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func fill(_ path: NSBezierPath, _ color: NSColor) {
    ctx.setFillColor(color.cgColor)
    ctx.addPath(path.cgPath)
    ctx.fillPath()
}

func stroke(_ path: NSBezierPath, _ color: NSColor, width: CGFloat) {
    ctx.setStrokeColor(color.cgColor)
    ctx.setLineWidth(width)
    ctx.setLineCap(.round)
    ctx.addPath(path.cgPath)
    ctx.strokePath()
}

func fillStroke(_ path: NSBezierPath, _ fillColor: NSColor, _ lineColor: NSColor, width: CGFloat) {
    ctx.setFillColor(fillColor.cgColor)
    ctx.addPath(path.cgPath)
    ctx.fillPath()
    ctx.setStrokeColor(lineColor.cgColor)
    ctx.setLineWidth(width)
    ctx.setLineJoin(.round)
    ctx.setLineCap(.round)
    ctx.addPath(path.cgPath)
    ctx.strokePath()
}

let ink = NSColor(red: 0.13, green: 0.09, blue: 0.10, alpha: 1)

// 배경
let bg = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: W, height: W), xRadius: 210, yRadius: 210)
ctx.saveGState()
ctx.addPath(bg.cgPath)
ctx.clip()
let colors = [
    NSColor(red: 0.12, green: 0.20, blue: 0.48, alpha: 1).cgColor,
    NSColor(red: 0.30, green: 0.15, blue: 0.55, alpha: 1).cgColor
] as CFArray
let grad = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 512, y: 1100), end: CGPoint(x: 512, y: 0), options: [])
ctx.restoreGState()

// 머리카락 (큰 반월)
let hair = NSBezierPath()
hair.move(to: NSPoint(x: 262, y: 560))
hair.curve(to: NSPoint(x: 762, y: 560),
           controlPoint1: NSPoint(x: 300, y: 1080), controlPoint2: NSPoint(x: 724, y: 1080))
hair.line(to: NSPoint(x: 762, y: 640))
hair.line(to: NSPoint(x: 262, y: 640))
hair.close()
fill(hair, NSColor(red: 0.24, green: 0.14, blue: 0.10, alpha: 1))

// 얼굴 (큰 타원 + 선화 아웃라인)
let face = NSBezierPath(ovalIn: NSRect(x: 512 - 230, y: 360, width: 460, height: 500))
fillStroke(face, NSColor(red: 1.0, green: 0.88, blue: 0.76, alpha: 1), ink, width: 26)

// 눈 (미니멀 점)
fill(NSBezierPath(ovalIn: NSRect(x: 408, y: 640, width: 34, height: 46)), ink)
fill(NSBezierPath(ovalIn: NSRect(x: 582, y: 640, width: 34, height: 46)), ink)

// 볼터치
fill(NSBezierPath(ovalIn: NSRect(x: 368, y: 560, width: 60, height: 32)),
     NSColor(red: 0.95, green: 0.45, blue: 0.42, alpha: 0.4))
fill(NSBezierPath(ovalIn: NSRect(x: 596, y: 560, width: 60, height: 32)),
     NSColor(red: 0.95, green: 0.45, blue: 0.42, alpha: 0.4))

// 미소
let smile = NSBezierPath()
smile.appendArc(withCenter: NSPoint(x: 512, y: 570), radius: 85, startAngle: 15, endAngle: 165, clockwise: false)
stroke(smile, ink, width: 24)

// 다운로드 배지 (흰 원 + 남색 화살표)
let badge = NSBezierPath(ovalIn: NSRect(x: 512 - 100, y: 140, width: 200, height: 200))
fill(badge, NSColor.white)
fill(NSBezierPath(roundedRect: NSRect(x: 512 - 26, y: 190, width: 52, height: 92), xRadius: 26, yRadius: 26),
     NSColor(red: 0.18, green: 0.38, blue: 0.72, alpha: 1))
let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 512 - 78, y: 200))
arrow.line(to: NSPoint(x: 512 + 78, y: 200))
arrow.line(to: NSPoint(x: 512, y: 285))
arrow.close()
fill(arrow, NSColor(red: 0.18, green: 0.38, blue: 0.72, alpha: 1))

let cgImage = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: cgImage)
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: "images/EveryWebtoon.png"))
print("written \(png.count) bytes")

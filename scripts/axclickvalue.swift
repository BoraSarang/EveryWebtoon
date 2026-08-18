import Foundation
import ApplicationServices
import AppKit
import CoreGraphics

func axValue(_ e: AXUIElement, _ a: String) -> Any? {
    var v: CFTypeRef?
    guard AXUIElementCopyAttributeValue(e, a as CFString, &v) == .success else { return nil }
    return v
}
func txt(_ e: AXUIElement, _ a: String) -> String {
    guard let v = axValue(e, a) else { return "" }
    return "\(v)"
}
func findIn(_ el: AXUIElement, value: String, depth: Int, wantRole: String?) -> AXUIElement? {
    let v = txt(el, kAXValueAttribute)
    if v == value && (wantRole == nil || txt(el, kAXRoleAttribute) == wantRole) { return el }
    guard depth < 20 else { return nil }
    if let kids = axValue(el, kAXChildrenAttribute) as? [AXUIElement] {
        for k in kids {
            if let f = findIn(k, value: value, depth: depth + 1, wantRole: wantRole) { return f }
        }
    }
    return nil
}
func clickCenter(_ el: AXUIElement) {
    let pos = axValue(el, kAXPositionAttribute) as! AXValue
    let size = axValue(el, kAXSizeAttribute) as! AXValue
    var p = CGPoint.zero; var s = CGSize.zero
    AXValueGetValue(pos, .cgPoint, &p)
    AXValueGetValue(size, .cgSize, &s)
    let cx = p.x + s.width / 2, cy = p.y + s.height / 2
    let src = CGEventSource(stateID: .hidSystemState)
    let down = CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: CGPoint(x: cx, y: cy), mouseButton: .left)
    let up = CGEvent(mouseEventSource: src, mouseType: .leftMouseUp, mouseCursorPosition: CGPoint(x: cx, y: cy), mouseButton: .left)
    down?.post(tap: .cghidEventTap)
    up?.post(tap: .cghidEventTap)
    print("clicked (\(cx),\(cy))")
}
let value = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "전체보기"
let role = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : nil
guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.borasarang.everywebtoon").first else { exit(1) }
let axApp = AXUIElementCreateApplication(app.processIdentifier)
guard let w = axValue(axApp, kAXWindowsAttribute) as? [AXUIElement] else { exit(1) }
for window in w {
    if let el = findIn(window, value: value, depth: 0, wantRole: role) {
        clickCenter(el)
        exit(0)
    }
}
print("not found: \(value)")
exit(1)
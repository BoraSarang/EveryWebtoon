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
func findField(_ el: AXUIElement, depth: Int) -> AXUIElement? {
    if txt(el, kAXRoleAttribute) == kAXTextFieldRole { return el }
    guard depth < 12 else { return nil }
    if let kids = axValue(el, kAXChildrenAttribute) as? [AXUIElement] {
        for k in kids { if let f = findField(k, depth: depth + 1) { return f } }
    }
    return nil
}
guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.borasarang.everywebtoon").first else { exit(1) }
let axApp = AXUIElementCreateApplication(app.processIdentifier)
guard let w = axValue(axApp, kAXWindowsAttribute) as? [AXUIElement], let field = findField(w[0], depth: 0) else {
    print("field not found")
    exit(1)
}
let pos = axValue(field, kAXPositionAttribute) as! AXValue
let size = axValue(field, kAXSizeAttribute) as! AXValue
var p = CGPoint.zero; var s = CGSize.zero
AXValueGetValue(pos, .cgPoint, &p)
AXValueGetValue(size, .cgSize, &s)
let cx = p.x + s.width / 2, cy = p.y + s.height / 2
let src = CGEventSource(stateID: .hidSystemState)
let down = CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: CGPoint(x: cx, y: cy), mouseButton: .left)
let up = CGEvent(mouseEventSource: src, mouseType: .leftMouseUp, mouseCursorPosition: CGPoint(x: cx, y: cy), mouseButton: .left)
down?.post(tap: .cghidEventTap)
up?.post(tap: .cghidEventTap)
usleep(400000)
print("clicked (\(cx),\(cy))")
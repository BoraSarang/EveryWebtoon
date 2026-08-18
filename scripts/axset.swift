import Foundation
import ApplicationServices
import AppKit

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
let text = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "신체"
let err = AXUIElementSetAttributeValue(field, kAXValueAttribute as CFString, text as CFString)
print("set value err=\(err.rawValue)")
usleep(600000)
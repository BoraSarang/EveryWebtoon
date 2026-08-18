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
let bundleId = "com.borasarang.everywebtoon"
guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first else {
    print("not running")
    exit(1)
}
let axApp = AXUIElementCreateApplication(app.processIdentifier)
let fe = axValue(axApp, kAXFocusedUIElementAttribute) as! AXUIElement
print("focused: role=\(txt(fe, kAXRoleAttribute)) title=\(txt(fe, kAXTitleAttribute)) desc=\(txt(fe, kAXDescriptionAttribute)) value=\(txt(fe, kAXValueAttribute))")
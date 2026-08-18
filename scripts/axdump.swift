import Foundation
import ApplicationServices
import AppKit

let appName = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "EveryWebtoon"

func axValue(_ element: AXUIElement, _ attr: String) -> Any? {
    var value: CFTypeRef?
    let err = AXUIElementCopyAttributeValue(element, attr as CFString, &value)
    guard err == .success else { return nil }
    return value
}

func attrText(_ element: AXUIElement, _ attr: String) -> String {
    guard let v = axValue(element, attr) else { return "" }
    return "\(v)"
}

func roleText(_ element: AXUIElement) -> String {
    return attrText(element, kAXRoleAttribute)
}

func dumpTree(_ element: AXUIElement, depth: Int) -> String {
    var out = ""
    let indent = String(repeating: "  ", count: depth)
    let role = roleText(element)
    if role.isEmpty { return out }
    let title = attrText(element, kAXTitleAttribute)
    let desc = attrText(element, kAXDescriptionAttribute)
    let value = attrText(element, kAXValueAttribute)
    var line = indent + role
    if !title.isEmpty, title != role { line += " title=\"\(title)\"" }
    if !desc.isEmpty { line += " desc=\"\(desc)\"" }
    if !value.isEmpty, value != "Optional(missing value)" { line += " value=\"\(value)\"" }
    out += line + "\n"
    if let children = axValue(element, kAXChildrenAttribute) as? [AXUIElement] {
        for child in children {
            out += dumpTree(child, depth: depth + 1)
        }
    }
    return out
}

guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.borasarang.everywebtoon").first else {
    print("App not found by bundle id com.borasarang.everywebtoon")
    exit(1)
}

let axApp = AXUIElementCreateApplication(app.processIdentifier)
if let windows = axValue(axApp, kAXWindowsAttribute) as? [AXUIElement] {
    for window in windows {
        let wTitle = attrText(window, kAXTitleAttribute)
        print("== WINDOW: \(wTitle) ==")
        print(dumpTree(window, depth: 0))
    }
} else {
    print("No windows found")
}
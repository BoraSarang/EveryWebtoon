import SwiftUI
import AppKit

struct ScrollViewFinder: NSViewRepresentable {
    let onFound: (NSScrollView) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        func findScroll(_ root: NSView) -> NSScrollView? {
            if let scroll = root as? NSScrollView { return scroll }
            for sub in root.subviews {
                if let found = findScroll(sub) { return found }
            }
            return nil
        }
        let attempt: () -> Bool = {
            var superview = view.superview
            while let s = superview {
                if let scroll = s as? NSScrollView {
                    onFound(scroll)
                    return true
                }
                superview = s.superview
            }
            guard let window = view.window else { return false }
            if let content = window.contentView, let found = findScroll(content) {
                onFound(found)
                return true
            }
            return false
        }
        for delay in [0.0, 0.1, 0.3, 0.6, 1.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                _ = attempt()
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
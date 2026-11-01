import UIKit

enum ReplayMasks {
    static let budget: TimeInterval = 0.002

    static func collect(in window: UIWindow, options: ReplayOptions) -> [CGRect]? {
        let deadline = CACurrentMediaTime() + budget
        var rects: [CGRect] = []
        var visited = 0
        let webViewClass: AnyClass? = NSClassFromString("WKWebView")

        func visit(_ view: UIView, forced: Bool, released: Bool) -> Bool {
            visited += 1
            if visited % 32 == 0 && CACurrentMediaTime() > deadline { return false }
            if view.isHidden || view.alpha < 0.01 || view.bounds.isEmpty { return true }
            let override = view.buizStackReplayMasked
            let masked = forced || override == true
            let unmasked = !masked && (released || override == false)
            let mask: Bool
            switch view {
            case _ where masked: mask = true
            case is UITextField: mask = true
            case let text as UITextView: mask = text.isEditable || text.isSecureTextEntry || options.maskAllText
            case is UILabel: mask = options.maskAllText
            case is UIImageView: mask = options.maskImages && !unmasked
            default: mask = webViewClass.map { view.isKind(of: $0) } ?? false
            }
            if mask {
                rects.append(view.convert(view.bounds, to: window).insetBy(dx: -1, dy: -1))
                return true
            }
            for child in view.subviews where !visit(child, forced: masked, released: unmasked) { return false }
            return true
        }

        return visit(window, forced: false, released: false) ? rects : nil
    }
}

import ObjectiveC
import UIKit

enum Instrumentation {
    static var onTouch: ((UIWindow, CGPoint) -> Void)?
    static var onScreen: ((String) -> Void)?
    private static var installed = false

    static func install() {
        guard !installed else { return }
        installed = true
        swap(UIWindow.self, #selector(UIWindow.sendEvent(_:)), #selector(UIWindow.buizStack_sendEvent(_:)))
        swap(UIViewController.self, #selector(UIViewController.viewDidAppear(_:)), #selector(UIViewController.buizStack_viewDidAppear(_:)))
    }

    private static func swap(_ type: AnyClass, _ original: Selector, _ replacement: Selector) {
        guard let a = class_getInstanceMethod(type, original), let b = class_getInstanceMethod(type, replacement) else { return }
        method_exchangeImplementations(a, b)
    }

    static func screenName(_ controller: UIViewController) -> String? {
        if controller is UINavigationController || controller is UITabBarController || controller is UIPageViewController
            || controller is UISplitViewController
        {
            return nil
        }
        let name = String(describing: type(of: controller))
        let trimmed = String(name.prefix { $0 != "<" })
        if trimmed.hasPrefix("_") || (trimmed.hasPrefix("UI") && !(trimmed.hasPrefix("UIHosting"))) { return nil }
        return trimmed == "UIHostingController" ? nil : trimmed
    }
}

extension UIWindow {
    @objc func buizStack_sendEvent(_ event: UIEvent) {
        if event.type == .touches, let touches = event.allTouches {
            for touch in touches where touch.phase == .began {
                Instrumentation.onTouch?(self, touch.location(in: self))
            }
        }
        buizStack_sendEvent(event)
    }
}

extension UIViewController {
    @objc func buizStack_viewDidAppear(_ animated: Bool) {
        buizStack_viewDidAppear(animated)
        if let name = Instrumentation.screenName(self) { Instrumentation.onScreen?(name) }
    }
}

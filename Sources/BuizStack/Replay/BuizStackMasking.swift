import SwiftUI
import UIKit

private var maskKey: UInt8 = 0

extension UIView {
    public var buizStackReplayMasked: Bool? {
        get { (objc_getAssociatedObject(self, &maskKey) as? NSNumber)?.boolValue }
        set { objc_setAssociatedObject(self, &maskKey, newValue.map { NSNumber(value: $0) }, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

final class BuizStackMaskMarkerView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        buizStackReplayMasked = true
    }

    required init?(coder: NSCoder) { nil }
}

private struct BuizStackMaskMarker: UIViewRepresentable {
    func makeUIView(context: Context) -> BuizStackMaskMarkerView { BuizStackMaskMarkerView() }

    func updateUIView(_ uiView: BuizStackMaskMarkerView, context: Context) {}
}

extension View {
    public func buizStackReplayMask() -> some View { background(BuizStackMaskMarker()) }
}

import Foundation

public struct ReplayItem: Equatable {
    public enum Kind: String { case viewport, screen, tap, breadcrumb, event }

    public let at: Date
    public let kind: Kind
    public var name: String?
    public var category: String?
    public var x: Double?
    public var y: Double?
    public var width: Int?
    public var height: Int?

    public static func viewport(_ at: Date, _ width: Int, _ height: Int) -> ReplayItem { ReplayItem(at: at, kind: .viewport, width: width, height: height) }

    public static func screen(_ at: Date, _ name: String) -> ReplayItem { ReplayItem(at: at, kind: .screen, name: name) }

    public static func tap(_ at: Date, _ x: Double, _ y: Double) -> ReplayItem { ReplayItem(at: at, kind: .tap, x: x, y: y) }

    public static func event(_ at: Date, _ name: String) -> ReplayItem { ReplayItem(at: at, kind: .event, name: name) }

    var json: [String: Any] {
        var json: [String: Any] = ["t": Int64(at.timeIntervalSince1970 * 1000), "type": kind.rawValue]
        json["name"] = name
        json["category"] = category
        json["x"] = x
        json["y"] = y
        json["w"] = width
        json["h"] = height
        return json
    }
}

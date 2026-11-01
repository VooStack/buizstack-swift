import Foundation

public struct BuizStackDsn: Equatable {
    public let ingestBase: URL
    public let publicKey: String

    public init?(_ value: String?) {
        guard let value, let components = URLComponents(string: value), let scheme = components.scheme, let host = components.host,
            let user = components.user, !user.isEmpty
        else { return nil }
        let appId = components.path.replacingOccurrences(of: "/", with: "")
        guard !appId.isEmpty else { return nil }
        var base = URLComponents()
        base.scheme = scheme
        base.host = host
        base.port = components.port
        base.path = "/\(appId)"
        guard let url = base.url else { return nil }
        ingestBase = url
        publicKey = user.removingPercentEncoding ?? user
    }

    public func signal(_ name: String) -> URL { ingestBase.appendingPathComponent("v1").appendingPathComponent(name) }
}

import Foundation

open class HttpTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) { self.session = session }

    open func post(_ url: URL, key: String, contentType: String, body: Data) -> Int {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "x-buizstack-key")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return send(request).0
    }

    open func get(_ url: URL, key: String) -> (Int, Data) {
        var request = URLRequest(url: url, timeoutInterval: 3)
        request.setValue(key, forHTTPHeaderField: "x-buizstack-key")
        return send(request)
    }

    private func send(_ request: URLRequest) -> (Int, Data) {
        let done = DispatchSemaphore(value: 0)
        var result: (Int, Data) = (0, Data())
        session.dataTask(with: request) { data, response, _ in
            result = ((response as? HTTPURLResponse)?.statusCode ?? 0, data ?? Data())
            done.signal()
        }.resume()
        done.wait()
        return result
    }
}

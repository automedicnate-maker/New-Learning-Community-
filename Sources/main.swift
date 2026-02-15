import Foundation
import Glibc

struct HTTPRequest {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data
}

struct HTTPResponse {
    let status: Int
    let contentType: String
    let body: Data

    static func json<T: Encodable>(_ value: T, status: Int = 200) -> HTTPResponse {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return HTTPResponse(status: status, contentType: "application/json", body: (try? encoder.encode(value)) ?? Data("{}".utf8))
    }

    static func text(_ value: String, status: Int = 200) -> HTTPResponse {
        HTTPResponse(status: status, contentType: "text/plain; charset=utf-8", body: Data(value.utf8))
    }

    static func html(_ value: String, status: Int = 200) -> HTTPResponse {
        HTTPResponse(status: status, contentType: "text/html; charset=utf-8", body: Data(value.utf8))
    }
}

nonisolated(unsafe) let store = LearningDataStore.bootstrap()
let landingHTML: String = {
    if let resourceURL = Bundle.module.url(forResource: "index", withExtension: "html"),
       let value = try? String(contentsOf: resourceURL, encoding: .utf8) {
        return value
    }
    return "<h1>French Monkeys Academy</h1>"
}()

func bearerToken(from headers: [String: String]) -> String? {
    guard let auth = headers["authorization"], auth.lowercased().hasPrefix("bearer ") else { return nil }
    return String(auth.dropFirst(7))
}

func handle(_ request: HTTPRequest) -> HTTPResponse {
    switch (request.method, request.path) {
    case ("GET", "/"):
        return .html(landingHTML)
    case ("GET", "/api/bootstrap"):
        return .json(AdminBootstrapResponse(message: "Use /api/auth/login to get a token.", defaults: store.snapshot()))
    case ("POST", "/api/auth/login"):
        guard let payload = try? JSONDecoder().decode(LoginRequest.self, from: request.body),
              let user = store.login(email: payload.email) else {
            return .text("{\"error\":\"invalid email\"}", status: 404)
        }
        return .json(LoginResponse(token: user.token, role: user.role, name: user.name))
    case ("GET", "/api/dashboard"), ("GET", "/api/courses"), ("GET", "/api/tests"), ("GET", "/api/announcements"):
        guard let user = store.user(token: bearerToken(from: request.headers)) else {
            return .text("{\"error\":\"unauthorized\"}", status: 401)
        }
        if request.path == "/api/dashboard" { return .json(store.dashboard(user: user)) }
        if request.path == "/api/courses" { return .json(store.listCourses(for: user)) }
        if request.path == "/api/tests" { return .json(store.listTests()) }
        return .json(store.listAnnouncements())
    case ("POST", "/api/admin/courses"), ("POST", "/api/admin/tests"), ("POST", "/api/admin/announcements"), ("POST", "/api/admin/pages"), ("POST", "/api/admin/toolbar"):
        guard let user = store.user(token: bearerToken(from: request.headers)), user.role == .admin else {
            return .text("{\"error\":\"forbidden\"}", status: 403)
        }
        switch request.path {
        case "/api/admin/courses": if let v = try? JSONDecoder().decode(Course.self, from: request.body) { store.addCourse(v) }
        case "/api/admin/tests": if let v = try? JSONDecoder().decode(Test.self, from: request.body) { store.addTest(v) }
        case "/api/admin/announcements": if let v = try? JSONDecoder().decode(Announcement.self, from: request.body) { store.addAnnouncement(v) }
        case "/api/admin/pages": if let v = try? JSONDecoder().decode(Page.self, from: request.body) { store.addPage(v) }
        default: if let v = try? JSONDecoder().decode(ToolbarLink.self, from: request.body) { store.addToolbar(v) }
        }
        return .text("created", status: 201)
    default:
        return .text("Not Found", status: 404)
    }
}

func parseRequest(_ data: Data) -> HTTPRequest? {
    guard let text = String(data: data, encoding: .utf8),
          let splitRange = text.range(of: "\r\n\r\n") else { return nil }
    let headerText = String(text[..<splitRange.lowerBound])
    let bodyText = String(text[splitRange.upperBound...])
    let headerLines = headerText.split(separator: "\r\n", omittingEmptySubsequences: false)
    guard let requestLine = headerLines.first else { return nil }
    let parts = requestLine.split(separator: " ")
    guard parts.count >= 2 else { return nil }

    var headers: [String: String] = [:]
    for line in headerLines.dropFirst() {
        let pair = line.split(separator: ":", maxSplits: 1)
        if pair.count == 2 {
            headers[String(pair[0]).lowercased()] = String(pair[1]).trimmingCharacters(in: .whitespaces)
        }
    }

    return HTTPRequest(method: String(parts[0]), path: String(parts[1]), headers: headers, body: Data(bodyText.utf8))
}

func statusText(_ code: Int) -> String {
    switch code {
    case 200: return "OK"
    case 201: return "Created"
    case 401: return "Unauthorized"
    case 403: return "Forbidden"
    case 404: return "Not Found"
    default: return "OK"
    }
}

let socketFD = socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
var value: Int32 = 1
setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, &value, socklen_t(MemoryLayout<Int32>.size))

var addr = sockaddr_in()
addr.sin_family = sa_family_t(AF_INET)
addr.sin_port = in_port_t(8080).bigEndian
addr.sin_addr = in_addr(s_addr: in_addr_t(0))

withUnsafePointer(to: &addr) { ptr in
    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
        _ = bind(socketFD, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
    }
}

listen(socketFD, 128)
print("French Monkeys Academy running at http://0.0.0.0:8080")

while true {
    var clientAddr = sockaddr()
    var len: socklen_t = socklen_t(MemoryLayout<sockaddr>.size)
    let client = accept(socketFD, &clientAddr, &len)
    if client < 0 { continue }

    var buffer = [UInt8](repeating: 0, count: 65536)
    let readCount = read(client, &buffer, buffer.count)
    if readCount > 0 {
        let data = Data(buffer.prefix(Int(readCount)))
        if let request = parseRequest(data) {
            let response = handle(request)
            let header = "HTTP/1.1 \(response.status) \(statusText(response.status))\r\nContent-Type: \(response.contentType)\r\nContent-Length: \(response.body.count)\r\nConnection: close\r\n\r\n"
            _ = header.withCString { send(client, $0, strlen($0), 0) }
            response.body.withUnsafeBytes { ptr in
                _ = send(client, ptr.baseAddress, response.body.count, 0)
            }
        }
    }
    close(client)
}

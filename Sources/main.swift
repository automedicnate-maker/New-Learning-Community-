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

    static func error(_ message: String, status: Int) -> HTTPResponse {
        HTTPResponse(status: status, contentType: "application/json", body: Data("{\"error\":\"\(message)\"}".utf8))
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
    return "<h1>WRENCH</h1>"
}()

func bearerToken(from headers: [String: String]) -> String? {
    guard let auth = headers["authorization"], auth.lowercased().hasPrefix("bearer ") else { return nil }
    return String(auth.dropFirst(7))
}

func authenticatedUser(from request: HTTPRequest) -> User? {
    store.user(token: bearerToken(from: request.headers))
}

func requireAdmin(_ request: HTTPRequest) -> User? {
    guard let user = authenticatedUser(from: request), user.role == .admin else { return nil }
    return user
}

func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try? decoder.decode(T.self, from: data)
}

func handle(_ request: HTTPRequest) -> HTTPResponse {
    switch (request.method, request.path) {
    case ("GET", "/"):
        return .html(landingHTML)

    case ("GET", "/api/bootstrap"):
        return .json(PublicBootstrapResponse(platformName: "WRENCH", hasDefaultAdmin: store.hasDefaultAdmin()))

    case ("POST", "/api/auth/login"):
        guard let payload = decode(LoginRequest.self, from: request.body),
              let user = store.login(username: payload.username, password: payload.password) else {
            return .error("invalid credentials", status: 401)
        }
        return .json(LoginResponse(token: user.token, role: user.role, name: user.name, username: user.username, level: user.level))

    case ("POST", "/api/auth/signup"):
        guard let payload = decode(SignupRequest.self, from: request.body) else {
            return .error("invalid payload", status: 400)
        }
        let result = store.signup(payload)
        switch result {
        case .success(let user):
            return .json(LoginResponse(token: user.token, role: user.role, name: user.name, username: user.username, level: user.level), status: 201)
        case .failure(let error):
            return .error(error.text, status: 400)
        }

    case ("GET", "/api/dashboard"):
        guard let user = authenticatedUser(from: request) else { return .error("unauthorized", status: 401) }
        return .json(store.dashboard(for: user))

    case ("GET", "/api/courses"):
        guard let user = authenticatedUser(from: request) else { return .error("unauthorized", status: 401) }
        return .json(store.courseAccessList(for: user))

    case ("GET", "/api/tests"):
        guard authenticatedUser(from: request) != nil else { return .error("unauthorized", status: 401) }
        return .json(store.allTests())

    case ("GET", "/api/tools"):
        guard authenticatedUser(from: request) != nil else { return .error("unauthorized", status: 401) }
        return .json(store.allTools())

    case ("GET", "/api/announcements"):
        guard authenticatedUser(from: request) != nil else { return .error("unauthorized", status: 401) }
        return .json(store.allAnnouncements())

    case ("POST", "/api/tests/submit"):
        guard let user = authenticatedUser(from: request) else { return .error("unauthorized", status: 401) }
        guard let payload = decode(SubmitTestRequest.self, from: request.body) else { return .error("invalid payload", status: 400) }
        switch store.submitTest(user: user, payload: payload) {
        case .success(let attempt): return .json(attempt, status: 201)
        case .failure(let err): return .error(err.text, status: 400)
        }

    case ("GET", "/api/admin/overview"):
        guard requireAdmin(request) != nil else { return .error("forbidden", status: 403) }
        return .json(store.adminOverview())

    case ("POST", "/api/admin/invite-codes"):
        guard let admin = requireAdmin(request) else { return .error("forbidden", status: 403) }
        guard let payload = decode(CreateInviteCodeRequest.self, from: request.body) else { return .error("invalid payload", status: 400) }
        return .json(store.createInviteCode(uses: payload.uses, adminID: admin.id), status: 201)

    case ("POST", "/api/admin/tools"):
        guard requireAdmin(request) != nil else { return .error("forbidden", status: 403) }
        guard let payload = decode(CreateToolRequest.self, from: request.body) else { return .error("invalid payload", status: 400) }
        return .json(store.addTool(payload), status: 201)

    case ("POST", "/api/admin/courses"):
        guard requireAdmin(request) != nil else { return .error("forbidden", status: 403) }
        guard let payload = decode(CreateCourseRequest.self, from: request.body) else { return .error("invalid payload", status: 400) }
        return .json(store.addCourse(payload), status: 201)

    case ("POST", "/api/admin/tests"):
        guard requireAdmin(request) != nil else { return .error("forbidden", status: 403) }
        guard let payload = decode(CreateTestRequest.self, from: request.body) else { return .error("invalid payload", status: 400) }
        switch store.addTest(payload) {
        case .success(let test): return .json(test, status: 201)
        case .failure(let err): return .error(err.text, status: 400)
        }

    case ("POST", "/api/admin/announcements"):
        guard requireAdmin(request) != nil else { return .error("forbidden", status: 403) }
        guard let payload = decode(CreateAnnouncementRequest.self, from: request.body) else { return .error("invalid payload", status: 400) }
        return .json(store.addAnnouncement(payload), status: 201)

    default:
        return .error("not found", status: 404)
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
    case 400: return "Bad Request"
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
print("WRENCH running at http://0.0.0.0:8080")

while true {
    var clientAddr = sockaddr()
    var len: socklen_t = socklen_t(MemoryLayout<sockaddr>.size)
    let client = accept(socketFD, &clientAddr, &len)
    if client < 0 { continue }

    var buffer = [UInt8](repeating: 0, count: 131072)
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

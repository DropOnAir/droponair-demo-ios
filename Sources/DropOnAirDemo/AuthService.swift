import Foundation

/// Minimal auth service that calls the demo backend login endpoint.
@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var userId: String?
    @Published private(set) var displayName: String?
    private var jwt: String?

    struct LoginResponse: Decodable {
        let jwt: String
        let userId: String
        let displayName: String
    }

    func login(userId: String, displayName: String? = nil) async throws {
        let url  = URL(string: "\(backendURL)/api/auth/login")!
        var req  = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "userId": userId,
            "displayName": displayName ?? userId,
        ]
        req.httpBody = try JSONEncoder().encode(body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let result = try JSONDecoder().decode(LoginResponse.self, from: data)
        jwt              = result.jwt
        self.userId      = result.userId
        self.displayName = result.displayName
    }

    func getJwt() async throws -> String {
        guard let jwt else { throw URLError(.userAuthenticationRequired) }
        return jwt
    }

    func logout() {
        jwt         = nil
        userId      = nil
        displayName = nil
    }

    var isLoggedIn: Bool { jwt != nil }
}

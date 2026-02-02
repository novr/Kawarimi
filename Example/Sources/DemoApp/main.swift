import DemoAPI
import Foundation
import OpenAPIURLSession

@main
struct DemoApp {
    static func main() async throws {
        let serverURL = URL(string: "http://localhost:8080/api")!

        let mockClient = Client(serverURL: serverURL, transport: Kawarimi())
        let mockResponse = try await mockClient.getGreeting(.init())
        switch mockResponse {
        case .ok(let ok):
            if case .json(let body) = ok.body {
                print("[Kawarimi] \(body.message)")
            }
        default:
            print("[Kawarimi] Unexpected: \(mockResponse)")
        }

        let client = Client(serverURL: serverURL, transport: URLSessionTransport())
        let response = try await client.getGreeting(.init())
        switch response {
        case .ok(let ok):
            if case .json(let body) = ok.body {
                print("[Server] \(body.message)")
            }
        default:
            print("Unexpected: \(response)")
        }
    }
}

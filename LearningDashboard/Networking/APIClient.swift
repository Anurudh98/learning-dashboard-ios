//
//  APIClient.swift
//  LearningDashboard
//

import Foundation

/// Real `URLSession`-based client. It is not used while `AppConfiguration.useMockBackend` is `true`,
/// but it is the production shape: swap it in and nothing above it changes.
final class APIClient: APIClientProtocol {

    private let session: URLSession
    private let decoder: JSONDecoder
    private let tokenProvider: () -> String?

    init(session: URLSession = .shared, tokenProvider: @escaping () -> String? = { nil }) {
        self.session = session
        self.tokenProvider = tokenProvider

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
    }

    func request<T: Decodable>(
        _ endpoint: Endpoint,
        as responseType: T.Type
    ) async throws -> T {

        let urlRequest = try endpoint.urlRequest(token: tokenProvider())

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as URLError where error.code == .notConnectedToInternet
                    || error.code == .networkConnectionLost
                    || error.code == .dataNotAllowed {
            throw NetworkError.noInternet
        } catch {
            throw NetworkError.unknownError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard 200...299 ~= httpResponse.statusCode else {
            if httpResponse.statusCode == 401 { throw NetworkError.unauthorized }
            throw NetworkError.serverError(httpResponse.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed
        }
    }
}

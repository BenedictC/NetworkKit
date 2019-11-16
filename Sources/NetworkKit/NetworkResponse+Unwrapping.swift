//
//  NetworkResponse+Unwrapping.swift
//  Benedict Cohen
//
//  Created by Benedict Cohen on 16/11/2019.
//  Copyright © 2019 Benedict Cohen. All rights reserved.
//

import Foundation


// MARK: - Base response unwrapping

public extension NetworkResponse {

    var value: ValueType {
        return self[keyPath: valueKeyPath]
    }

    static func unwrap(urlResponse: URLResponse?, error: Error?) throws -> URLResponse {
        if let error = error {
            throw NetworkResponseError.underlyingError(error)
        }
        guard let response = urlResponse else {
            throw NetworkResponseError.invalidURLResponse(urlResponse)
        }
        return response
    }

    static func unwrap(httpURLResponse: URLResponse?, error: Error?) throws -> HTTPURLResponse {
        guard let httpResponse = try unwrap(urlResponse: httpURLResponse, error: error) as? HTTPURLResponse else {
            throw NetworkResponseError.invalidURLResponse(httpURLResponse)
        }
        return httpResponse
    }
}


// MARK: - Data response unwrapping

public extension NetworkResponse {

    static func unwrap(data: Data?, urlResponse: URLResponse?, error: Error?) throws -> (Data, URLResponse) {
        let response = try unwrap(urlResponse: urlResponse, error: error)

        guard let data = data else {
            throw NetworkResponseError.missingBodyData
        }
        return (data, response)
    }

    static func unwrap(data: Data?, httpURLResponse: URLResponse?, error: Error?) throws -> (Data, HTTPURLResponse) {
        guard let (data, httpResponse) = try unwrap(data: data, urlResponse: httpURLResponse, error: error) as? (Data, HTTPURLResponse) else {
            throw NetworkResponseError.invalidURLResponse(httpURLResponse)
        }
        return (data, httpResponse)
    }
}


// MARK: - JSON decodable response unwrapping

public extension NetworkResponse {

    static func unwrap<T: Decodable>(jsonDecodable data: Data?, urlResponse: URLResponse?, error: Error?) throws -> (T, URLResponse) {
        let response = try unwrap(urlResponse: urlResponse, error: error)

        guard let data = data else {
            throw NetworkResponseError.missingBodyData
        }

        do {
            let decoded = try JSONDecoder().decode(T.self, from: data)
            return (decoded, response)
        } catch {
            throw NetworkResponseError.decodingError(error)
        }
    }

    static func unwrap<T: Decodable>(jsonDecodable data: Data?, httpURLResponse: URLResponse?, error: Error?) throws -> (T, HTTPURLResponse) {
        guard let (data, httpResponse) = try unwrap(data: data, urlResponse: httpURLResponse, error: error) as? (Data, HTTPURLResponse) else {
            throw NetworkResponseError.invalidURLResponse(httpURLResponse)
        }

        do {
            let decoded = try JSONDecoder().decode(T.self, from: data)
            return (decoded, httpResponse)
        } catch {
            throw NetworkResponseError.decodingError(error)
        }
    }
}

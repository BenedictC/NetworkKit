//
//  NetworkRequest-NetworkResponse.swift
//  Benedict Cohen
//
//  Created by Benedict Cohen on 16/11/2019.
//  Copyright © 2019 Benedict Cohen. All rights reserved.
//

import Foundation


// MARK: - NetworkRequest

public enum NetworkRequestError: Error {
    case unableToCreateURL
    case invalidParameters
}

public protocol NetworkRequest {

    associatedtype ResponseType: NetworkResponse where ResponseType.RequestType == Self

    func makeURLRequest(with baseURL: URL) throws -> URLRequest
}



// MARK: - NetworkResponse

public enum NetworkResponseError: Error {
    case underlyingError(Error)
    case invalidURLResponse(URLResponse?)
    case missingBodyData
    case decodingError(Error)
    case unexpectedResponse
    case unspecifiedFailure
}

public protocol NetworkResponse {

    associatedtype RequestType
    associatedtype ValueType

    var valueKeyPath: KeyPath<Self, ValueType> { get }

    static func makeResponse(request: RequestType, bodyData: Data?, urlResponse: URLResponse?, error: Error?) throws -> Self
}

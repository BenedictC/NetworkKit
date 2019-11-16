//
//  NetworkSession.swift
//  Benedict Cohen
//
//  Created by Benedict Cohen on 16/11/2019.
//  Copyright © 2019 Benedict Cohen. All rights reserved.
//

import Foundation
import Properations


// MARK: - NetworkSessionDelegate

public protocol NetworkSessionDelegate: class {
    func networkSession<T: NetworkRequest>(_ networkSession: NetworkSession, requestQueueIDFor networkRequest: T) -> String?
    func networkSession<T: NetworkRequest>(_ networkSession: NetworkSession, urlRequestFor networkRequest: T, baseURL: URL, completion: @escaping (URLRequest?) -> Void)
    func networkSession<T: NetworkRequest>(_ networkSession: NetworkSession, shouldRetry networkRequest: T, failedResponses: [(error: Error?, urlResponse: URLResponse?)], completion: @escaping (Bool) -> Void)
}


extension NetworkSessionDelegate {

    func networkSession<T: NetworkRequest>(_ networkSession: NetworkSession, requestQueueIDFor networkRequest: T) -> String? {
        return nil
    }

    func networkSession<T: NetworkRequest>(_ networkSession: NetworkSession, urlRequestFor networkRequest: T, baseURL: URL, completion: @escaping (URLRequest?) -> Void) {
        do {
            let urlRequest = try networkRequest.makeURLRequest(with: baseURL)
            completion(urlRequest)
        } catch {
            completion(nil)
        }
    }

    func networkSession<T: NetworkRequest>(_ networkSession: NetworkSession, shouldRetry networkRequest: T, failedResponses: [(error: Error?, urlResponse: URLResponse?)], completion: @escaping (Bool) -> Void) {
        completion(false)
    }
}


// MARK: - NetworkSessionError

public enum NetworkSessionError: Error {
    case cancelled
}


// MARK: - NetworkSession

public final class NetworkSession: NSObject {

    // MARK: State

    public let baseURL: URL
    public var configuration: URLSessionConfiguration {
        return urlSession.configuration
    }
    weak public private(set) var delegate: NetworkSessionDelegate?

    private var urlSession: URLSession! // This can't be a let because URLSession takes a delegate (self), but self can't be used until an object is fully initalized. Catch 22.

    private var requestQueues = [String: OperationQueue]()

    private let defaultQueue = OperationQueue()


    // MARK: Instance life cycle

    public init(baseURL: URL, configuration: URLSessionConfiguration, delegate: NetworkSessionDelegate?) {
        self.baseURL = baseURL
        self.delegate = delegate
        super.init()
        self.urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }


    // MARK: Request handling

    @discardableResult
    public func enqueue<T: NetworkRequest>(_ request: T, completion convenienceCompletion: ((FutureResult<T.ResponseType.ValueType>) -> Void)? = nil) -> Future<T.ResponseType> {
        // # Get the work queue
        let workQueueID = delegate?.networkSession(self, requestQueueIDFor: request)
        let workQueue = requestQueue(for: workQueueID)

        // # Create the responsePromise
        let responseFuture = Promises.makeBlocking(on: workQueue, promising: T.ResponseType.self) { promise in
            self.immediatelyPerformNetworkRequest(request, completionPromise: promise)
        }

        // Append the convenience completion
        if let convenienceCompletion = convenienceCompletion {
            responseFuture
                .mapToValue { $0.value }
                .onCompletion { responseValue in
                    convenienceCompletion(responseValue)
            }
        }

        return responseFuture
    }

    private func requestQueue(for queueID: String?) -> OperationQueue {
        assert(Thread.isMainThread)
        // If a queue isn't specified then use the default
        guard let queueID = queueID else {
            return defaultQueue
        }

        // Attempt to fetch existing queue
        if let queue = requestQueues[queueID] {
            return queue
        }

        //Create and store a new queue
        let newQueue = OperationQueue()
        newQueue.maxConcurrentOperationCount = 1
        newQueue.name = queueID
        requestQueues[queueID] = newQueue

        return newQueue
    }

    private func immediatelyPerformNetworkRequest<T: NetworkRequest>(_ networkRequest: T, completionPromise: Promise<T.ResponseType>, failedResponses: [(Error?, URLResponse?)] = []) {
        let delegate = self.delegate ?? DefaultNetworkSessionDelegate.shared

        func handleResponse(data: Data?, urlResponse: URLResponse?, error: Error?) {
//            guard let httpResponse = (urlResponse as? HTTPURLResponse) else { fatalError() }
            do {
                let response = try T.ResponseType.makeResponse(request: networkRequest, bodyData: data, urlResponse: urlResponse, error: error)
//                print("Success: \(httpResponse.statusCode) - \(httpResponse.url!)")
                completionPromise.succeed(with: response)
            } catch {
                let responses = failedResponses + [(error, urlResponse)]
                delegate.networkSession(self, shouldRetry: networkRequest, failedResponses: responses) { shouldRetry in
                    if shouldRetry {
//                        print("Retry: \(httpResponse.statusCode) - \(httpResponse.url!)")
                        self.immediatelyPerformNetworkRequest(networkRequest, completionPromise: completionPromise, failedResponses: responses)
                    } else {
//                        print("Failed: \(httpResponse.statusCode) - \(httpResponse.url!)")
                        completionPromise.fail(with: error)
                    }
                }
            }
        }

        OperationQueue.main.addOperation {
            delegate.networkSession(self, urlRequestFor: networkRequest, baseURL: self.baseURL) { urlRequest in
                // A. Validate the request
                guard let urlRequest = urlRequest else {
                    completionPromise.fail(with: NetworkSessionError.cancelled)
                    return
                }
                // B. Create the task
                let task = self.urlSession.dataTask(with: urlRequest) { data, urlResponse, error in
                    OperationQueue.main.addOperation {
                        handleResponse(data: data, urlResponse: urlResponse, error: error)
                    }
                }
                // C. Begin the task
                task.resume()
            }
        }
    }
}


// MARK: - DefaultNetworkSessionDelegate

private class DefaultNetworkSessionDelegate: NetworkSessionDelegate {

    static let shared = DefaultNetworkSessionDelegate()

    private init() { }
}


// MARK: - URLSessionDelegate

extension NetworkSession: URLSessionDelegate {

}

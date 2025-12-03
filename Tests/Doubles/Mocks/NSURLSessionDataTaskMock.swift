//
//  NSURLSessionDataTaskMock.swift
//  attentive-ios-sdk Tests
//
//  Created by Vladimir - Work on 2024-06-05.
//

import Foundation
import XCTest

class NSURLSessionDataTaskMock: URLSessionDataTask {
    let completionHandler: (Data?, URLResponse?, Error?) -> Void

    init(completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) {
        self.completionHandler = completionHandler
    }

    override func resume() {
        completionHandler(nil, nil, nil)
    }
}

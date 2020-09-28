//
//  TestRunner.swift
//  CodeEditViewSample
//
//  Created by Marcin Krzyzanowski on 28/09/2020.
//

#if canImport(XCTest)
import XCTest

class TestRunner {
    struct TestFailed: Swift.Error, LocalizedError {
        let message: String

        var errorDescription: String? {
            message
        }
    }

    static func run() throws {
        let suite = XCTestSuite.default
        for test in suite.tests {
            if let testRun = test.testRun {
                test.perform(testRun)
                if !testRun.hasSucceeded {
                    throw TestFailed(message: "Failed \(testRun.test.name)")
                }
            }
        }
    }
}
#endif

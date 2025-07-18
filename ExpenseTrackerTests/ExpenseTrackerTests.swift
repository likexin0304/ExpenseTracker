//
//  ExpenseTrackerTests.swift
//  ExpenseTrackerTests
//
//  Created by 李可心(Daniel.L) on 2025/6/9.
//

import XCTest
@testable import ExpenseTracker

final class ExpenseTrackerTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
    // MARK: - 🆕 OCR URL构建测试
    
    /// 测试OCR端点URL构建是否正确
    func testOCREndpointURLConstruction() throws {
        // 测试基本端点URL构建
        let parseURL = APIConfig.OCREndpoint.parse.fullURL()
        XCTAssertTrue(parseURL.contains("/api/ocr/parse"), "Parse端点URL应该包含正确的路径")
        XCTAssertFalse(parseURL.contains("/api/api/"), "URL不应该包含重复的/api路径")
        
        let parseAutoURL = APIConfig.OCREndpoint.parseAuto.fullURL()
        XCTAssertTrue(parseAutoURL.contains("/api/ocr/parse-auto"), "ParseAuto端点URL应该包含正确的路径")
        XCTAssertFalse(parseAutoURL.contains("/api/api/"), "URL不应该包含重复的/api路径")
        
        let recordsURL = APIConfig.OCREndpoint.records.fullURL()
        XCTAssertTrue(recordsURL.contains("/api/ocr/records"), "Records端点URL应该包含正确的路径")
        XCTAssertFalse(recordsURL.contains("/api/api/"), "URL不应该包含重复的/api路径")
        
        let statisticsURL = APIConfig.OCREndpoint.statistics.fullURL()
        XCTAssertTrue(statisticsURL.contains("/api/ocr/statistics"), "Statistics端点URL应该包含正确的路径")
        XCTAssertFalse(statisticsURL.contains("/api/api/"), "URL不应该包含重复的/api路径")
    }
    
    /// 测试带路径参数的OCR端点URL构建
    func testOCREndpointURLWithPathComponent() throws {
        let recordId = "test-record-123"
        
        // 测试记录详情URL
        let recordDetailURL = APIConfig.OCREndpoint.records.fullURL(with: recordId)
        XCTAssertTrue(recordDetailURL.contains("/api/ocr/records/test-record-123"), "记录详情URL应该包含正确的路径和参数")
        XCTAssertFalse(recordDetailURL.contains("/api/api/"), "URL不应该包含重复的/api路径")
        
        // 测试确认记录URL
        let confirmURL = APIConfig.OCREndpoint.records.fullURL(with: "confirm/\(recordId)")
        XCTAssertTrue(confirmURL.contains("/api/ocr/records/confirm/test-record-123"), "确认记录URL应该包含正确的路径和参数")
        XCTAssertFalse(confirmURL.contains("/api/api/"), "URL不应该包含重复的/api路径")
    }
    
    /// 测试所有OCR端点都不包含重复的/api路径
    func testAllOCREndpointsNoDuplicateAPI() throws {
        for endpoint in APIConfig.OCREndpoint.allCases {
            let url = endpoint.fullURL()
            XCTAssertFalse(url.contains("/api/api/"), "\(endpoint)端点URL不应该包含重复的/api路径: \(url)")
            XCTAssertTrue(url.hasPrefix("https://"), "\(endpoint)端点URL应该以https://开头: \(url)")
            XCTAssertTrue(url.contains("/api/ocr/"), "\(endpoint)端点URL应该包含/api/ocr/路径: \(url)")
        }
    }
    
    /// 测试OCR端点枚举的完整性
    func testOCREndpointEnumCompleteness() throws {
        // 确保所有必要的OCR端点都已定义
        let expectedEndpoints: Set<String> = [
            "/api/ocr/parse",
            "/api/ocr/parse-auto",
            "/api/ocr/records",
            "/api/ocr/statistics",
            "/api/ocr/merchants",
            "/api/ocr/merchants/match",
            "/api/ocr/shortcuts/generate"
        ]
        
        let actualEndpoints = Set(APIConfig.OCREndpoint.allCases.map { $0.rawValue })
        
        XCTAssertEqual(expectedEndpoints, actualEndpoints, "OCR端点枚举应该包含所有预期的端点")
        XCTAssertEqual(APIConfig.OCREndpoint.allCases.count, 7, "应该有7个OCR端点")
    }

}

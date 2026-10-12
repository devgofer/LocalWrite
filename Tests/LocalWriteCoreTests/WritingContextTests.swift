import XCTest
@testable import LocalWriteCore

final class WritingContextTests: XCTestCase {
    func testGreetingFollowsDestinationApp() {
        let text = "Hi, Anna, can we meet tomorrow?"
        XCTAssertEqual(WritingContext(style: .email).formatGreeting(text), "Hi Anna,\n\nCan we meet tomorrow?")
        XCTAssertEqual(WritingContext(style: .chat).formatGreeting("Hi Anna. Can we meet tomorrow?"), "Hi, Anna, can we meet tomorrow?")
        XCTAssertEqual(WritingContext(style: .document).formatGreeting(text), text)
        XCTAssertEqual(WritingContext(style: .email).formatGreeting("我明天請假。"), "我明天請假。")
    }

    func testClassifiesAppsAndBrowserTabs() {
        XCTAssertEqual(WritingContext.classify(bundleID: "net.whatsapp.WhatsApp", appName: "WhatsApp").style, .chat)
        XCTAssertEqual(WritingContext.classify(bundleID: "com.apple.mail", appName: "Mail").style, .email)
        XCTAssertEqual(WritingContext.classify(bundleID: "com.google.Chrome", appName: "Chrome", windowTitle: "Inbox - Gmail").style, .email)
        XCTAssertEqual(WritingContext.classify(bundleID: "com.apple.dt.Xcode", appName: "Xcode").style, .general)
    }
}

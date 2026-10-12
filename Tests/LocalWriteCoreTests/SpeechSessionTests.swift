import XCTest
@testable import LocalWriteCore

final class SpeechSessionTests: XCTestCase {
    func testManualFinishWaitsForFinalResult() {
        var session = SpeechSession()
        let id = session.begin(at: 0)
        _ = session.receive(id: id, text: "明天下午", final: false, error: nil)
        XCTAssertEqual(session.finish(at: 1), .endAudio)
        XCTAssertNil(session.finish(at: 1.1))
        XCTAssertEqual(session.receive(id: id, text: "明天下午三點", final: true, error: nil), .finished("明天下午三點"))
    }

    func testOldCallbackCannotFinishNewRecording() {
        var session = SpeechSession()
        let old = session.begin(at: 0)
        session.cancel()
        let current = session.begin(at: 1)
        XCTAssertNil(session.receive(id: old, text: "old", final: true, error: nil))
        XCTAssertEqual(session.id, current)
        XCTAssertEqual(session.transcript, "")
    }

    func testSilenceWaitsForFinalAndPreservesSentenceEnding() {
        var session = SpeechSession()
        let id = session.begin(at: 0)
        _ = session.receive(id: id, text: "明天下午", final: false, error: nil)
        session.audio(id: id, speechLike: true, at: 1)
        XCTAssertEqual(session.tick(at: 2.3), .endAudio)
        XCTAssertNil(session.tick(at: 2.4))
        XCTAssertEqual(session.receive(id: id, text: "明天下午三點", final: true, error: nil), .finished("明天下午三點"))
        XCTAssertNil(session.receive(id: id, text: "duplicate", final: true, error: nil))
    }

    func testErrorBeforeFirstResultEndsSession() {
        var session = SpeechSession()
        let id = session.begin(at: 0)
        XCTAssertEqual(session.receive(id: id, text: nil, final: false, error: "failed"), .failed("failed"))
        XCTAssertNil(session.id)
    }

    func testEmptyAudioTimesOut() {
        var session = SpeechSession()
        _ = session.begin(at: 0)
        XCTAssertEqual(session.tick(at: 10), .failed("No speech detected. Please try again."))
        XCTAssertNil(session.id)
    }

    func testFinalTimeoutFallsBackToLatestPartial() {
        var session = SpeechSession()
        let id = session.begin(at: 0)
        _ = session.receive(id: id, text: "hello", final: false, error: nil)
        session.audio(id: id, speechLike: true, at: 0.5)
        XCTAssertEqual(session.tick(at: 2), .endAudio)
        XCTAssertEqual(session.tick(at: 5), .finished("hello"))
    }

    func testErrorWithPartialPreservesTextButReportsFailure() {
        var session = SpeechSession()
        let id = session.begin(at: 0)
        _ = session.receive(id: id, text: "keep me", final: false, error: nil)
        XCTAssertEqual(session.receive(id: id, text: nil, final: false, error: "offline"), .failed("offline"))
        XCTAssertEqual(session.transcript, "keep me")
    }

    func testContinuousNoiseStillHasBoundedDuration() {
        var session = SpeechSession()
        let id = session.begin(at: 0)
        session.audio(id: id, speechLike: true, at: 59)
        XCTAssertEqual(session.tick(at: 60), .endAudio)
        XCTAssertEqual(session.tick(at: 63), .failed("No speech detected. Please try again."))
    }

    func testKeyboardDictationRunsPastSixtySecondsUntilItsLimit() {
        var session = SpeechSession()
        let id = session.begin(at: 0, maxDuration: 180)
        _ = session.receive(id: id, text: "long thought", final: false, error: nil)
        XCTAssertNil(session.tick(at: 90))
        XCTAssertEqual(session.tick(at: 180), .endAudio)
    }
}

import XCTest
import AVFoundation
@testable import LocalWriteCore

private final class TapBox: @unchecked Sendable {
    let callback: AVAudioNodeTapBlock
    init(_ callback: @escaping AVAudioNodeTapBlock) { self.callback = callback }
}

final class AudioCallbackTests: XCTestCase {
    @MainActor func testAudioTapCanRunOnAudioThread() async {
        let feed = SpeechAudioFeed()
        let box = TapBox(feed.makeTapHandler())
        let completed = await Task.detached {
            let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 32)!
            buffer.frameLength = 32
            box.callback(buffer, AVAudioTime(sampleTime: 0, atRate: 16000))
            return true
        }.value
        XCTAssertTrue(completed)
    }
}

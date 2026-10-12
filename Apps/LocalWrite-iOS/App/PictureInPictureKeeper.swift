import AVKit
import CoreMedia
import SwiftUI
import UIKit

/// A small floating window, as Typeless does, that keeps LocalWrite running while the
/// user is in another app. The microphone stays off; only this status frame is shown.
@MainActor
final class PictureInPictureKeeper: NSObject, ObservableObject {
    let layer = AVSampleBufferDisplayLayer()
    @Published private(set) var active = false
    var onStop: (() -> Void)?
    private var controller: AVPictureInPictureController?

    static var isSupported: Bool { AVPictureInPictureController.isPictureInPictureSupported() }

    func prepare() {
        guard controller == nil, Self.isSupported else { return }
        layer.videoGravity = .resizeAspect
        let source = AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer: layer, playbackDelegate: self)
        let controller = AVPictureInPictureController(contentSource: source)
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.requiresLinearPlayback = true
        controller.delegate = self
        self.controller = controller
        show("LocalWrite 待命中", symbol: "mic")
    }

    /// Starts the floating window; possible only once the layer has a frame on screen.
    func start() async {
        prepare()
        guard let controller else { return }
        for _ in 0..<40 where !controller.isPictureInPicturePossible {
            do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
        }
        if controller.isPictureInPicturePossible, !controller.isPictureInPictureActive {
            controller.startPictureInPicture()
        }
    }

    func stop() { controller?.stopPictureInPicture() }

    func show(_ text: String, symbol: String) {
        let size = CGSize(width: 320, height: 180)
        let format = UIGraphicsImageRendererFormat(); format.scale = 2
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.black.setFill(); context.fill(CGRect(origin: .zero, size: size))
            let configuration = UIImage.SymbolConfiguration(pointSize: 44, weight: .semibold)
            if let icon = UIImage(systemName: symbol, withConfiguration: configuration)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) {
                icon.draw(at: CGPoint(x: (size.width - icon.size.width) / 2, y: 40))
            }
            let style = NSMutableParagraphStyle(); style.alignment = .center
            (text as NSString).draw(in: CGRect(x: 10, y: 118, width: size.width - 20, height: 40), withAttributes: [
                .font: UIFont.systemFont(ofSize: 20, weight: .medium),
                .foregroundColor: UIColor.white, .paragraphStyle: style
            ])
        }
        guard let cgImage = image.cgImage, let sample = Self.sampleBuffer(from: cgImage) else { return }
        layer.sampleBufferRenderer.flush()
        layer.sampleBufferRenderer.enqueue(sample)
    }

    private static func sampleBuffer(from image: CGImage) -> CMSampleBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attributes = [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary
        guard CVPixelBufferCreate(kCFAllocatorDefault, image.width, image.height, kCVPixelFormatType_32BGRA,
                                  attributes, &pixelBuffer) == kCVReturnSuccess, let pixelBuffer else { return nil }
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        let context = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer), width: image.width, height: image.height,
                                bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

        var description: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer,
                                                     formatDescriptionOut: &description)
        guard let description else { return nil }
        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
                                        decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer,
                                                 formatDescription: description, sampleTiming: &timing, sampleBufferOut: &sample)
        if let sample, let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: true),
           CFArrayGetCount(attachments) > 0 {
            let dictionary = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(dictionary, Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                                 Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
        }
        return sample
    }
}

extension PictureInPictureKeeper: AVPictureInPictureControllerDelegate {
    nonisolated func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
        Task { @MainActor in self.active = true }
    }
    nonisolated func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        Task { @MainActor in self.active = false; self.onStop?() }
    }
}

extension PictureInPictureKeeper: AVPictureInPictureSampleBufferPlaybackDelegate {
    nonisolated func pictureInPictureController(_ controller: AVPictureInPictureController, setPlaying playing: Bool) {}
    nonisolated func pictureInPictureControllerTimeRangeForPlayback(_ controller: AVPictureInPictureController) -> CMTimeRange {
        CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity)
    }
    nonisolated func pictureInPictureControllerIsPlaybackPaused(_ controller: AVPictureInPictureController) -> Bool { false }
    nonisolated func pictureInPictureController(_ controller: AVPictureInPictureController,
                                                didTransitionToRenderSize newRenderSize: CMVideoDimensions) {}
    nonisolated func pictureInPictureController(_ controller: AVPictureInPictureController, skipByInterval skipInterval: CMTime,
                                                completion completionHandler: @escaping () -> Void) { completionHandler() }
}

/// Hosts the PiP source layer in the app's window, as AVKit requires.
struct PictureInPictureSourceView: UIViewRepresentable {
    let layer: AVSampleBufferDisplayLayer
    func makeUIView(context: Context) -> LayerView { LayerView(layer: layer) }
    func updateUIView(_ view: LayerView, context: Context) {}

    final class LayerView: UIView {
        private let hosted: CALayer
        init(layer: CALayer) { hosted = layer; super.init(frame: .zero); self.layer.addSublayer(layer) }
        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
        override func layoutSubviews() { super.layoutSubviews(); hosted.frame = bounds }
    }
}

import Foundation
import WebRTC
import AVKit


// Define closure type for handling CMSampleBuffer, orientation, scaleFactor
public typealias CMSampleBufferRenderer = (CMSampleBuffer?, CGImagePropertyOrientation, CGFloat) -> ()

// Define closure variables for handling CMSampleBuffer from FrameRenderer
var getCMSampleBufferFromFrameRenderer: CMSampleBufferRenderer = { _,_,_ in }
var getCMSampleBufferFromFrameRendererForPIP: CMSampleBufferRenderer = { _,_,_ in }
var getLocalVideoCMSampleBufferFromFrameRenderer:
CMSampleBufferRenderer = { _,_,_  in }

// Define the FrameRenderer class responsible for rendering video frames
@objc open class FrameRenderer: NSObject, RTCVideoRenderer {
    // VARIABLES
    @objc var recUserID: Int = 1
    @objc var scaleF: CGFloat = 1
    @objc var frameImage = UIImage()
    @objc var videoFormatDescription: CMFormatDescription?
    @objc var didGetFrame: ((CMSampleBuffer) -> ())?
    @objc private var ciContext = CIContext()
    
    // Set the aspect ratio based on the size
    @objc public func setSize(_ size: CGSize) {
        self.scaleF = .maximum(size.width/size.height, size.height/size.width)
//        if #available(iOS 15.0, *) {
//            PipViewController.pipVideoCallViewController?.preferredContentSize = CGSize(width: size.width, height: size.height)
//        }
    }
    
    // Render a video frame received from WebRTC
    @objc public func renderFrame(_ frame: RTCVideoFrame?) {
        guard let pixelBuffer = self.getCVPixelBuffer(frame: frame) else {
            return
        }
        
        // Extract timing information from the frame and create a CMSampleBuffer
        var timingInfo = self.covertFrameTimestampToTimingInfo(frame: frame)!
        let cmSampleBuffer = self.createSampleBufferFrom(pixelBuffer: pixelBuffer, timingInfo: timingInfo)!
        
        
        // Determine the video orientation and handle the CMSampleBuffer accordingly
        let oriented: CGImagePropertyOrientation?
        switch frame!.rotation.rawValue {
        case RTCVideoRotation._0.rawValue:
            oriented = .right
        case RTCVideoRotation._90.rawValue:
            oriented = .right
        case RTCVideoRotation._180.rawValue:
            oriented = .right
        case RTCVideoRotation._270.rawValue:
            oriented = .left
        default:
            oriented = .right
        }
        getCMSampleBufferFromFrameRendererForPIP(cmSampleBuffer, oriented!, self.scaleF)
        
//         Call the didGetFrame closure if it exists
        if let closure = self.didGetFrame {
            closure(cmSampleBuffer)
        }
        
    }
    
    // Function to create a CVPixelBuffer from a CIImage
    @objc func createPixelBufferFrom(image: CIImage) -> CVPixelBuffer? {
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: false,
            kCVPixelBufferCGBitmapContextCompatibilityKey: false,
            kCVPixelBufferWidthKey: Int(image.extent.width),
            kCVPixelBufferHeightKey: Int(image.extent.height)
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(image.extent.width), Int(image.extent.height), kCVPixelFormatType_32BGRA, attrs, &pixelBuffer)
        
        if status == kCVReturnSuccess {
            self.ciContext.render(image, to: pixelBuffer!)
            return pixelBuffer
        }
        // Failed to create a CVPixelBuffer
        print("Error creating CVPixelBuffer.")
        return nil
    }
    
    // Function to create a CVPixelBuffer from a CIImage using an existing CVPixelBuffer
    @objc func buffer(from image: CIImage, oldCVPixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        let attrs = [
            kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(image.extent.width), Int(image.extent.height), kCVPixelFormatType_32BGRA, attrs, &pixelBuffer)
        
        if status == kCVReturnSuccess {
            oldCVPixelBuffer.propagateAttachments(to: pixelBuffer!)
            return pixelBuffer
        } else {
            // Failed to create a CVPixelBuffer
            print("Error creating CVPixelBuffer.")
            return nil
        }
    }
    
    /// Convert RTCVideoFrame to CVPixelBuffer
    @objc func getCVPixelBuffer(frame: RTCVideoFrame?) -> CVPixelBuffer? {
        var buffer : RTCCVPixelBuffer?
        var pixelBuffer: CVPixelBuffer?
        
        buffer = frame?.buffer as? RTCCVPixelBuffer
        pixelBuffer = buffer?.pixelBuffer
        return pixelBuffer
    }
    /// Convert RTCVideoFrame to CMSampleTimingInfo
    func covertFrameTimestampToTimingInfo(frame: RTCVideoFrame?) -> CMSampleTimingInfo? {
        let scale = CMTimeScale(NSEC_PER_SEC)
        let pts = CMTime(value: CMTimeValue(Double(frame!.timeStamp) * Double(scale)), timescale: scale)
        let timingInfo = CMSampleTimingInfo(duration: CMTime.invalid,
                                            presentationTimeStamp: pts,
                                            decodeTimeStamp: CMTime.invalid)
        return timingInfo
    }
    
    /// Convert CVPixelBuffer to CMSampleBuffer
    @objc func createSampleBufferFrom(pixelBuffer: CVPixelBuffer, timingInfo: CMSampleTimingInfo) -> CMSampleBuffer? {
        var sampleBuffer: CMSampleBuffer?
        
        var timimgInfo = timingInfo
        var formatDescription: CMFormatDescription? = nil
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, formatDescriptionOut: &formatDescription)
        
        CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: formatDescription!,
            sampleTiming: &timimgInfo,
            sampleBufferOut: &sampleBuffer
        )
        
        guard let buffer = sampleBuffer else {
            return nil
        }
        let attachments: NSArray = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: true)! as NSArray
        let dict: NSMutableDictionary = attachments[0] as! NSMutableDictionary
        dict[kCMSampleAttachmentKey_DisplayImmediately as NSString] = true as NSNumber
        return buffer
 
    }
}


@objc open class SampleBufferVideoCallView: UIView {
    @objc public override init(frame: CGRect) {
        super.init(frame: frame)
        self.transform = CGAffineTransformMakeScale(-1.0, 1.0)
//        self.sampleBufferDisplayLayer.videoGravity = .resizeAspectFill
//        self.contentMode = .scaleAspectFill
    }
    
    @objc required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    @objc open override class var layerClass: AnyClass {
        AVSampleBufferDisplayLayer.self
    }
    @objc var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer {
        layer as! AVSampleBufferDisplayLayer
    }
}

@available(iOS 15.0, *)
@objc open class PipViewController: NSObject {
    
    // MARK: Singleton
    @objc public static let shared = PipViewController()
    
    // MARK: Public static variables
    @objc public static var pipController: AVPictureInPictureController?
    @objc public static var pipContentSource: AVPictureInPictureController.ContentSource?
    @objc public static var frameRenderer: FrameRenderer?
    @objc public static var sampleBufferVideoCallView: SampleBufferVideoCallView?
    @objc public static var webrtcModule: WebRTCModule?
    
    @objc public static var pipVideoCallViewController: AVPictureInPictureVideoCallViewController?
    
    @objc public static func preparePictureInPicture(rootView: UIView) {
        PipViewController.pipVideoCallViewController = AVPictureInPictureVideoCallViewController()
       
        PipViewController.pipVideoCallViewController!.view.clipsToBounds = true
        PipViewController.pipVideoCallViewController?.preferredContentSize = CGSize(width: 140, height: 240)
        
        PipViewController.pipContentSource = AVPictureInPictureController.ContentSource(
            activeVideoCallSourceView: rootView,
            contentViewController: PipViewController.pipVideoCallViewController!
        )
    }
    
    @objc public func startPIP() {
        PipViewController.pipController?.startPictureInPicture()
    }
    @objc public func stopPIP() {
        PipViewController.pipController?.stopPictureInPicture()
    }
    @objc public func enablePIP(reactTag: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
            if AVPictureInPictureController.isPictureInPictureSupported() {
                PipViewController.frameRenderer = FrameRenderer()
                PipViewController.sampleBufferVideoCallView = SampleBufferVideoCallView(frame: CGRectMake(0, 0, 140, 240))
                PipViewController.sampleBufferVideoCallView!.translatesAutoresizingMaskIntoConstraints = false
                PipViewController.sampleBufferVideoCallView!.bounds = PipViewController.pipVideoCallViewController!.view.frame
                
                PipViewController.pipVideoCallViewController?.view.addSubview(PipViewController.sampleBufferVideoCallView!)
              
                getCMSampleBufferFromFrameRendererForPIP = { cmSampleBuffer, videosOrientation, scaleF  in
                    
                    if let sampleBuffer = cmSampleBuffer {
                       
                            PipViewController.sampleBufferVideoCallView!.sampleBufferDisplayLayer.enqueue(sampleBuffer)
                    }
                }
                
                
                let videoTrack = PipViewController.webrtcModule?.stream(forReactTag: reactTag).videoTracks.first
                if let videoTrack = videoTrack {
                    videoTrack.add(PipViewController.frameRenderer!)
                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
                        PipViewController.pipController = AVPictureInPictureController(contentSource: PipViewController.pipContentSource!)
                        PipViewController.pipController?.canStartPictureInPictureAutomaticallyFromInline = true;
                    }
                    //                PipViewController.pipController?.delegate = self
                }
            }
        }

    }
    @objc public func disablePIP(reactTag: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
            PipViewController.pipController?.canStartPictureInPictureAutomaticallyFromInline = false;
            PipViewController.pipController?.stopPictureInPicture()
            
            let videoTrack = PipViewController.webrtcModule?.stream(forReactTag: reactTag).videoTracks.first
            if let videoTrack = videoTrack {
                videoTrack.remove(PipViewController.frameRenderer!)
            }
            PipViewController.sampleBufferVideoCallView?.removeFromSuperview()
            PipViewController.sampleBufferVideoCallView = nil
            PipViewController.pipController = nil
            PipViewController.frameRenderer = nil
        }
        
    }
    
}

@available(iOS 15.0, *)
extension PipViewController:AVPictureInPictureControllerDelegate {
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: any Error) {
        
    }
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        completionHandler(true)
    }
    public func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        
    }
    public func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        
    }
    public func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        
    }
    public func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        
    }
}

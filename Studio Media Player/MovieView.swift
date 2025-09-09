//
//  MovieView.swift
//  Studio Media Player
//
//  Created by DannyNiu on 2022-07-03.
//

import Foundation
import Cocoa
import Dispatch

import AVFoundation
import AVKit
import CoreVideo
import VideoToolbox

class MovieView : NSView
{
    var asset: AVAsset?
    var item: AVPlayerItem?
    var vlink: CADisplayLink?
    var timer: Timer?
//* #unless USE_AV_PLAYERV_VIEW
    var player: AVPlayer?
    var playinglayer: CALayer = .init()
    var playingcontent: CGImage?
    var vidout: AVPlayerVideoOutput = .init(
        specification: .init(tagCollections: [
            .stereoscopicForVideoOutput(),
            .monoscopicForVideoOutput()
        ]))
//*/
    
    let clockid = CLOCK_REALTIME
    
    override var isOpaque: Bool { get { return true } }
    override var wantsUpdateLayer: Bool { get { return true } }
    
    func setup() -> Bool
    {
        self.asset = nil
        self.item = nil
        self.player = .init()
        
        self.player!.preventsDisplaySleepDuringVideoPlayback = true;
        
        clock_gettime(clockid, &ts_last)
        
        vlink = self.displayLink(target: self, selector: #selector(video_render))
        if( vlink == nil ) { return false }
        
        NSCursor.setHiddenUntilMouseMoves(true)
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true, block: {(timer: Timer) in
            NSCursor.setHiddenUntilMouseMoves(true)
        })
        timer!.fire()
        return true
    }
    
    var ts_last: timespec = .init()
    var flip: Bool = false
    var eye_right: Bool = false
    var irect: CGRect = .init()
    var srect: CGRect = .init()
    var orect: CGRect = .init()
    var vrect: CGRect = .init()
    var track_is_multiview: Bool = false
    
    func assign_asset(_ asset: AVAsset) async
    {
        self.asset = asset
        item = .init(asset: self.asset!)
        self.player?.replaceCurrentItem(with: item)
        self.player?.videoOutput = self.vidout
        
        await get_track_attrs(try! await asset.load(.tracks))
        self.layer = self.playinglayer
    }
    
    func get_track_attrs(_ tracks: [AVAssetTrack]) async
    {
        for track: AVAssetTrack in tracks
        {
            if( track.mediaType != AVMediaType.video ) { continue }
            if( (try? await track.load(.isEnabled)) ?? false )
            {
                self.irect.size = try! await track.load(.naturalSize)
            }
            
            if( (try? await track.load(.mediaCharacteristics))?.contains(
                AVMediaCharacteristic.containsStereoMultiviewVideo) ?? false )
            {
                self.track_is_multiview = true
            }
            else { self.track_is_multiview = false }
        }
    }
    
    func rects_recalc()
    {
        orect = NSRectToCGRect(bounds)
        
        var oy: CGFloat = 0
        
        if( orect.width > 1 && irect.width > 1 )
        {
            oy = (orect.height -
                  irect.height *
                  orect.width /
                  irect.width) / 2
        }
        
        let oh: CGFloat = irect.height * orect.width / irect.width
        let osize: CGSize = CGSize(width: orect.width * 2,
                                   height: oh)
        
        if( eye_right != flip ) // right eye.
        {
            vrect = CGRect(origin: CGPoint(x: -orect.width, y: oy),
                           size: osize)
        }
        else // left eye.
        {
            vrect = CGRect(origin: CGPoint(x: 0, y: oy),
                           size: osize)
        }
    }
    
    func rects_fix()
    {
        orect = NSRectToCGRect(bounds)
        
        var oy: CGFloat = 0
        
        if( orect.width > 1 && irect.width > 1 )
        {
            oy = (orect.height -
                  irect.height *
                  orect.width /
                  irect.width) / 2
        }
        
        let oh: CGFloat = irect.height * orect.width / irect.width
        let osize: CGSize = CGSize(width: orect.width, height: oh)
        
        vrect = CGRect(origin: CGPoint(x: 0, y: oy), size: osize)
    }
    
    @IBOutlet var progelem: NSSlider!
    
    @objc func video_render(displink: CADisplayLink)
    {
        let t: Double = player!.currentTime().seconds
        let duration: Double = player!.currentItem?.duration.seconds ?? 1
        progelem.doubleValue = t * (progelem.maxValue - progelem.minValue) / duration + progelem.minValue
        // freq = CVGetHostClockFrequency()
        
        let freq = self.window!.screen!.maximumFramesPerSecond // Should be 120.
        
        let d: CFTimeInterval = displink.targetTimestamp;
        
        if( Int64(d * CFTimeInterval(freq)) % 2 == 1 )
        {
            eye_right = true
        }
        else { eye_right = false }
        
        if( self.asset != nil && self.irect.width > 0 )
        {
            var pixbuf: CVPixelBuffer?
            var taggedBufferGroup: [CMTaggedBuffer]?
            
            (taggedBufferGroup, _, _) =
                vidout.taggedBuffers(
                    forHostTime: CMClockGetTime(
                        .hostTimeClock)) ?? (nil, nil, nil)
            if( taggedBufferGroup == nil ){ return }
            switch( taggedBufferGroup![0].buffer ) {
            case let .pixelBuffer(res): pixbuf = res
            default: return }
            
            let tx: CGAffineTransform
            
            if( !self.track_is_multiview )
            {
                //== not multi-view codec ==//
                
                VTCreateCGImageFromCVPixelBuffer(
                    pixbuf!, options: nil, imageOut: &playingcontent)
                playinglayer.contents = playingcontent
                
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                tx = .init(scaleX: 2.0, y: 1.0)
                self.layer!.setAffineTransform(tx)
                self.rects_recalc()
                self.layer!.frame = self.vrect
                //print(self.eye_right, self.vrect)
                CATransaction.commit()
            }
            else
            {
                //== multi-view codec ==//
                
                for taggedBuffer in taggedBufferGroup! {
                    let dispcond = eye_right != flip
                    let src_reye = taggedBuffer.tags.contains(.stereoView(.rightEye))
                    let src_leye = !taggedBuffer.tags.contains(.stereoView(.leftEye))
                    if( dispcond == src_reye && src_reye == src_leye )
                    {
                        switch( taggedBuffer.buffer ) {
                        case let .pixelBuffer(res): pixbuf = res
                        default: return }
                        break
                    }
                }
                
                VTCreateCGImageFromCVPixelBuffer(
                    pixbuf!, options: nil, imageOut: &playingcontent)
                playinglayer.contents = playingcontent
                
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                tx = .init(scaleX: 2.0, y: 1.0)
                self.layer!.setAffineTransform(tx)
                self.rects_fix()
                self.layer!.frame = self.vrect
                //print(self.eye_right, self.vrect)
                CATransaction.commit()
            }
        }
        //self.needsDisplay = true
        self.window!.display()
    }
    
    
    @IBAction func skipforward(_ sender: Any)
    {
        player!.seek(to: CMTime(seconds: player!.currentTime().seconds + 1,
                                preferredTimescale: 600))
    }
    
    @IBAction func skipbackward(_ sender: Any)
    {
        player!.seek(to: CMTime(seconds: player!.currentTime().seconds - 1,
                                preferredTimescale: 600))
    }
    
    @IBAction func seekforward(_ sender: Any)
    {
        player!.seek(to: CMTime(seconds: player!.currentTime().seconds + 5,
                                preferredTimescale: 600))
    }
    
    @IBAction func seekbackward(_ sender: Any)
    {
        player!.seek(to: CMTime(seconds: player!.currentTime().seconds - 5,
                                preferredTimescale: 600))
    }
    
    @IBAction func fastforward(_ sender: Any)
    {
        player!.seek(to: CMTime(seconds: player!.currentTime().seconds + 15,
                                preferredTimescale: 600))
    }
    
    @IBAction func fastbackward(_ sender: Any)
    {
        player!.seek(to: CMTime(seconds: player!.currentTime().seconds - 15,
                                preferredTimescale: 600))
    }
    
    @IBAction func rewind(_ sender: Any)
    {
        player!.seek(to: CMTime(seconds: 0,
                                preferredTimescale: 600))
    }
    
    @IBAction func play_or_pause(_ sender: Any)
    {
        if( player!.rate > 0 ) { player!.pause() }
        else { player!.rate = 1.0 }
    }
    
    func unitrange(_ slider: NSSlider) -> Double
    {
        let p: Double = slider.doubleValue - slider.minValue
        let l: Double = slider.maxValue - slider.minValue
        return p / l
    }
    
    @IBAction func seek_progress(_ sender: NSSlider)
    {
        let duration: Double = player!.currentItem?.duration.seconds ?? 0
        let t: CMTime = .init(seconds: unitrange(sender) * duration,
                              preferredTimescale: 600)
        player!.seek(to: t)
    }
    
    @IBAction func setvol(_ sender: NSSlider)
    {
        player!.volume = Float(unitrange(sender))
    }
}

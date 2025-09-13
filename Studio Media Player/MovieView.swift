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

class MovieView : NSView, NSWindowDelegate
{
    var asset: AVAsset?
    var item: AVPlayerItem?
    var vlink: CADisplayLink?
    var player: AVPlayer?
    var vidout: AVPlayerVideoOutput = .init(
        specification: .init(tagCollections: [
            .stereoscopicForVideoOutput(),
            .monoscopicForVideoOutput()
        ]))
    
    override var isOpaque: Bool { get { return true } }
    override var wantsUpdateLayer: Bool { get { return true } }
    
    var cgimg0: CGImage?
    var cgimg1: CGImage?
    func setup() -> Bool
    {
        asset = nil
        item = nil
        player = .init()
        
        player!.preventsDisplaySleepDuringVideoPlayback = true;
        
        wantsLayer = true
        layer!.isOpaque = true
        
        vlink = window!.screen!.displayLink(target: self, selector: #selector(video_render))
        if( vlink == nil ) { return false }
        
        return true
    }
    
    var flip: Bool = false
    var eye_right: Bool = false
    var screenfps: TimeInterval = 1
    var irect: CGRect = .init()
    var track_is_multiview: Bool = false
    var track_frame_dur: CMTime = CMTime(value: 1, timescale: 1)
    
    func assign_asset(_ asset: AVAsset) async
    {
        self.asset = asset
        item = .init(asset: self.asset!)
        player?.replaceCurrentItem(with: item)
        player?.videoOutput = vidout
        lastTime = CMTime(value: -1, timescale: 1)
        
        await get_track_attrs(try! await asset.load(.tracks))
    }
    
    var lastTime: CMTime = CMTime(value: -1, timescale: 1)
    
    func PrepareGraphics()
    {
        screenfps = 1 / self.window!.screen!.displayUpdateGranularity
        bw = bounds.width
        bh = bounds.height
        
            let duration = player!.currentItem?.duration.seconds ?? 1.0
            progelem.doubleValue = player!.currentTime().seconds * (
                progelem.maxValue - progelem.minValue
            ) / duration + progelem.minValue
            
        var pixbuf0: CVPixelBuffer?
        var pixbuf1: CVPixelBuffer?
        var taggedBufferGroup: [CMTaggedBuffer]?
        
        taggedBufferGroup = nil
        var ptime: CMTime = lastTime
        
        (taggedBufferGroup, ptime, _) =
            vidout.taggedBuffers(
                forHostTime: CMClockGetTime(
                    .hostTimeClock)) ?? (nil, lastTime, nil)
        
        if( taggedBufferGroup == nil ) { return }
        if( CMTimeCompare(lastTime, ptime) == 0 ) { return }
        else { lastTime = ptime }
        
        pixbuf0 = nil
        cgimg0 = nil
        
        if( !track_is_multiview )
        {
            //== not multi-view codec ==//
            
            switch( taggedBufferGroup![0].buffer ) {
            case let .pixelBuffer(res): pixbuf0 = res
            default: return }
            
            VTCreateCGImageFromCVPixelBuffer(pixbuf0!, options: nil, imageOut: &cgimg0)
        }
        else
        {
            //== multi-view codec ==//
            
            pixbuf1 = nil
            cgimg1 = nil
            
            for taggedBuffer in taggedBufferGroup! {
                let src_leye = taggedBuffer.tags.contains(.stereoView(.leftEye))
                switch( taggedBuffer.buffer ) {
                case let .pixelBuffer(res):
                    if( src_leye ) { pixbuf0 = res }
                    else { pixbuf1 = res }
                default: return }
            }
            
            VTCreateCGImageFromCVPixelBuffer(pixbuf0!, options: nil, imageOut: &cgimg0)
            VTCreateCGImageFromCVPixelBuffer(pixbuf1!, options: nil, imageOut: &cgimg1)
        }
    }
    
    func get_track_attrs(_ tracks: [AVAssetTrack]) async
    {
        for track: AVAssetTrack in tracks
        {
            if( track.mediaType != AVMediaType.video ) { continue }
            if( (try? await track.load(.isEnabled)) ?? false )
            {
                irect.size = try! await track.load(.naturalSize)
            }
            
            track_frame_dur = try! await track.load(.minFrameDuration)
            
            if( (try? await track.load(.mediaCharacteristics))?.contains(
                AVMediaCharacteristic.containsStereoMultiviewVideo) ?? false )
            {
                track_is_multiview = true
            }
            else { track_is_multiview = false }
        }
    }
    
    var bw: CGFloat = 0.5
    var bh: CGFloat = 0.5
    
    func rects_recalc() -> CGRect
    {
        var oy: CGFloat = 0
        
        if( bw > 1 && irect.width > 1 )
        {
            oy = (bh - irect.height *
                  bw / irect.width) / 2
        }
        
        let oh: CGFloat = irect.height * bw / irect.width
        let osize: CGSize = CGSize(width: bw * 2, height: oh)
        
        if( eye_right != flip ) // right eye.
        {
            return CGRect(origin: CGPoint(x: -bw, y: oy), size: osize)
        }
        else // left eye.
        {
            return CGRect(origin: CGPoint(x: 0, y: oy), size: osize)
        }
    }
    
    func rects_fix() -> CGRect
    {
        var oy: CGFloat = 0
        
        if( bw > 1 && irect.width > 1 )
        {
            oy = (bh - irect.height *
                  bw / irect.width) / 2
        }
        
        let oh: CGFloat = irect.height * bw / irect.width
        let osize: CGSize = CGSize(width: bw, height: oh)
        
        return CGRect(origin: CGPoint(x: 0, y: oy), size: osize)
    }
    
    @IBOutlet var progelem: NSSlider!
    
    /*
    let fmt = NumberFormatter()
    required init(coder: NSCoder)
    {
        fmt.numberStyle = .decimal
        fmt.maximumFractionDigits = 8
        fmt.minimumFractionDigits = 8
        super.init(coder: coder)!
    }// */
    
    @objc func video_render(displink: CADisplayLink)
    {
        PrepareGraphics()
        if( asset == nil || irect.width <= 1 ) { return }
        if( cgimg0 == nil ) { return }
        
        screenfps = 1 / self.window!.screen!.displayUpdateGranularity
        bw = bounds.width
        bh = bounds.height
        
        let d: CFTimeInterval = displink.targetTimestamp
        
        if( fmod(d * screenfps + 0.13, 2) >= 1 )
        {
            eye_right = true
        }
        else { eye_right = false }
        
        if( !track_is_multiview )
        {
            //== not multi-view codec ==//
            
            //if( cgimg0 != nil )
            layer!.contents = cgimg0
            
            //CATransaction.begin()
            layer!.frame = rects_recalc()
            //CATransaction.commit()
        }
        else
        {
            //== multi-view codec ==//
            
            layer!.contents = (eye_right != flip) ? cgimg0 : cgimg1
            
            // CATransaction.begin()
            layer!.frame = rects_fix()
            // CATransaction.commit()
        }
        
        layer!.setNeedsDisplay()
        needsDisplay = true
        window!.viewsNeedDisplay = true
        display()
        window!.display()
        window!.displayIfNeeded()
        //let b = CACurrentMediaTime()
        //print("timediff="+(fmt.string(from: NSNumber(value: d-b)) ?? "-"))
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
    
    @IBAction func hideCursor(_ sender: Any)
    {
        NSCursor.setHiddenUntilMouseMoves(true)
    }
    
    func windowDidEnterFullScreen(_ notification: Notification)
    {
        NSCursor.setHiddenUntilMouseMoves(true)
    }
}

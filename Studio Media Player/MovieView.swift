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

class MovieView : NSView
{
    var asset: AVAsset?
    var item: AVPlayerItem?
    var vlink: CVDisplayLink?
    var freq: Double = 1
    var timer: Timer?
//* #unless USE_AV_PLAYERV_VIEW
    var player: AVPlayer?
    var playinglayer: AVPlayerLayer?
//*/
    
    let clockid = CLOCK_REALTIME
    
    override var isOpaque: Bool { get { return true } }
    override var wantsUpdateLayer: Bool { get { return true} }
    
    func setup() -> Bool
    {
        self.asset = nil
        self.item = nil
        self.player = .init()
        
        clock_gettime(clockid, &ts_last)
        
        var cvret: CVReturn
        NSCursor.setHiddenUntilMouseMoves(true)
        
        cvret = CVDisplayLinkCreateWithCGDisplay(
            CGMainDisplayID(), &vlink)
        if( vlink == nil ) { return false }
        
        let me: UnsafeMutableRawPointer =
        Unmanaged.passUnretained(self).toOpaque()
        cvret = CVDisplayLinkSetOutputCallback(
            vlink!, vlink_callback, me)
        
        if( cvret == kCVReturnSuccess ) {
            timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true, block: {(timer: Timer) in
                NSCursor.setHiddenUntilMouseMoves(true)
            })
            timer!.fire()
            return true
        } else { return false }
        // return true
    }
    
    var ts_last: timespec = .init()
    var flip: Bool = false
    var eye_right: Bool = false
    var irect: CGRect = .init()
    var srect: CGRect = .init()
    var orect: CGRect = .init()
    var vrect: CGRect = .init()
    
    func assign_asset(_ asset: AVAsset) async
    {
        self.asset = asset
        item = .init(asset: self.asset!)
        self.player?.replaceCurrentItem(with: item)
        
        for track: AVAssetTrack in self.asset!.tracks
        {
            if( (try? await track.load(.isEnabled)) ?? false &&
                track.mediaType == AVMediaType.video )
            {
                self.irect.size = try! await track.load(.naturalSize)
            }
        }
        
        self.playinglayer = .init(player: self.player!)
        self.layer = self.playinglayer
    }
    
    func rects_recalc()
    {
        //DispatchQueue.main.sync { orect = NSRectToCGRect(bounds) }
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
        
        if( eye_right != flip )
        {
            vrect = CGRect(origin: CGPoint(x: -orect.width, y: oy),
                           size: osize)
        }
        else
        {
            vrect = CGRect(origin: CGPoint(x: 0, y: oy),
                           size: osize)
        }
    }
    
    func video_render(_ d: CVTimeStamp)
    {
        // let t: CMTime = player!.currentTime()
        // freq = CVGetHostClockFrequency()
        
        var ts: timespec = .init()
        var elapsed: Int64
        
        clock_gettime(clockid, &ts)
        elapsed = Int64(ts.tv_sec) - Int64(ts_last.tv_sec)
        elapsed *= 1000_000_000
        elapsed += Int64(ts.tv_nsec) - Int64(ts_last.tv_nsec)
        elapsed *= 120
        elapsed /= 2000_000_750
        flip = elapsed % 2 == 1
        ts_last = ts
        
        if( (d.videoTime * 120) % // should be 120.
            (Int64(d.videoTimeScale) * 2) >=
            Int64(d.videoTimeScale) ) // */
        /* if( CVGetCurrentHostTime() * 120 %
            UInt64(freq * 2) >= UInt64(freq) ) // */
        // if( !eye_right )
        {
            eye_right = true
        }
        else { eye_right = false }
        
        DispatchQueue.main.async {
            if( self.layer != nil && self.irect.width > 0 )
            {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                let tx: CGAffineTransform = .init(scaleX: 2.0, y: 1.0)
                self.layer!.setAffineTransform(tx)
                self.rects_recalc()
                self.layer!.frame = self.vrect
                //print(self.eye_right, self.vrect)
                CATransaction.commit()
            }
            //self.needsDisplay = true
            self.window!.display()
        }
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
}

//* #unless USE_AV_PLAYERV_VIEW
func vlink_callback(
    displayLink: CVDisplayLink,
    inNow: UnsafePointer<CVTimeStamp>,
    inOutputTime: UnsafePointer<CVTimeStamp>,
    flagsIn: CVOptionFlags,
    flagsOut: UnsafeMutablePointer<CVOptionFlags>,
    arg_mvview: UnsafeMutableRawPointer?
) -> CVReturn
{
    let mvview: MovieView =
    Unmanaged.fromOpaque(arg_mvview!).takeUnretainedValue()
    mvview.video_render(inOutputTime.pointee)
    
    return kCVReturnSuccess
}
// */

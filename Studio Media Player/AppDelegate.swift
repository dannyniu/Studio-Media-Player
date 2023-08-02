//
//  AppDelegate.swift
//  Studio Media Player
//
//  Created by DannyNiu on 2022-07-03.
//

import Cocoa
import AVFoundation

@main
class AppDelegate: NSObject, NSApplicationDelegate
{
    @IBOutlet var window: NSWindow!
    @IBOutlet var mvv: MovieView!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        window.backgroundColor = NSColor.black
        
        //mvv.setup()
        if( !mvv.setup() ) { exit(1) }
        CVDisplayLinkStart(mvv.vlink!) // #unless USE_AV_PLAYER_VIEW: 
    }
    
    @IBAction func playOpenMedia(_ sender: Any)
    {
        let opp: NSOpenPanel = .init()
        opp.canChooseFiles = true
        opp.canChooseDirectories = false
        opp.allowsMultipleSelection = false
        
        opp.begin(completionHandler: {
            (res: NSApplication.ModalResponse) -> Void in
            if( res != NSApplication.ModalResponse.OK ) { return }
            
            Task.detached {
                let ass: AVURLAsset = await .init(url: opp.urls[0])
                await self.mvv.assign_asset(ass)
                await self.mvv.player?.play()
            }
        })
        
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return false
    }
}


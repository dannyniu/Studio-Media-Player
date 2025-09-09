//
//  AppDelegate.swift
//  Studio Media Player
//
//  Created by DannyNiu on 2022-07-03.
//

import Cocoa
import Foundation
import AVFoundation

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate
{
    @IBOutlet var window: NSWindow!
    @IBOutlet var mvv: MovieView!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        window.backgroundColor = NSColor.black
        
        //mvv.setup()
        if( !mvv.setup() ) { exit(1) }
        mvv.vlink!.add(to: .current, forMode: .default)
    }
    
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let url: URL = .init(filePath: filename)
        
        Task.detached {
            let ass: AVURLAsset = .init(url: url)
            await self.mvv.assign_asset(ass)
            await self.mvv.player?.play()
        }
        
        return true
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return false
    }

    @IBOutlet var widgetview: NSView!
    
    @IBAction func ToggleWidgetView(_ sender: Any)
    {
        widgetview.isHidden = !widgetview.isHidden;
    }
}


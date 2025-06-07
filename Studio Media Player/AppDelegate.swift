//
//  AppDelegate.swift
//  Studio Media Player
//
//  Created by DannyNiu on 2022-07-03.
//

import Cocoa
import Foundation
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
        mvv.vlink!.add(to: .current, forMode: .default)
    }
    
    @IBAction func open1media(_ sender: Any)
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
            }
        })
        
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


//
//  AppDelegate.swift
//  Tiling window manager
//
//  Created by Kari Kammonen on 16/11/2018.
//  Copyright © 2018 Kari Kammonen. All rights reserved.
//

import Cocoa
import Swift
import AXSwift
import Swindler
import PromiseKit

struct Constants {
    static let LIMIT_TRACKED_APPLICATIONS = 25
    static let DO_NOT_TRACK_APPS = [
    "iterm", "Xcode", "kkammone"
    ]

}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var windows: [Swindler.Window] = []
    var swindler: Swindler.State!
    var sizingStrategy = ""

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        self.intializeGraphics()
        self.initialize()
    }
    func intializeGraphics() {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }
    
    func initialize() {
        self.accessibilityCheck()
        self.listenKeypresses()
        //self.printWindows()
        self.initSwindle()
    }
    
    func accessibilityCheck() {
        print("===BE AWARE! THIS APPLICATION IS BASICALLY A KEY LOGGER. ALWAYS EVALUATE CODE BEFORE RUNNING===")
        print("===This application has to be accessibility trusted, checking...")
        guard AXSwift.checkIsProcessTrusted(prompt: true) else {
            print("Not trusted as an AX process; please authorize and re-launch")
            print("FAILED AXIsProcessTrustedWithOptions, which means that you are either running in app sandbox in xcode")
            print("or you haven't enabled accessibility setting for this application")
           // NSApp.terminate(self)
            return
        }
        print("===PASSED AXIsProcessTrustedWithOptions, Listening keypresses, monitoring windows")
    }
    
 /*
    func getWindows() -> [[String : Any]]{
        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
        let windowsListInfo = CGWindowListCopyWindowInfo(options, CGWindowID(0))
        let infoList = windowsListInfo as! [[String:Any]]
        return infoList.filter{ $0["kCGWindowLayer"] as! Int == 0 }
    }
    
    func printWindows() {
        print("===ACTIVE: LISTING WINDOWS===")
        print(getWindows())
    }
   */
    
    func listenKeypresses() {
        print("Listening keypresses......")
        let opts = NSDictionary(object: kCFBooleanTrue, forKey: kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString) as CFDictionary
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: self.keypress)
    }
    
    func keypress(event: NSEvent) {
        if(event.type == NSEvent.EventType.keyDown && event.characters == "å" ) {
            self.adjustSizing()
           //NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func adjustSizing() {
        print("adjustSizing")
        if(self.sizingStrategy != "sizingStrategy4" ) {
            print("Choosing sizingStrategy4")
            self.sizingStrategy4(xRes: self.swindler.screens.first!.frame.maxX,
                                 yRes: self.swindler.screens.first!.frame.maxY,
                                 windows: getRecentWindowsList())
        } else {
            print("Choosing sizingStrategyLatestMax")
            self.sizingStrategyLatestMax(xRes: self.swindler.screens.first!.frame.maxX,
                                 yRes: self.swindler.screens.first!.frame.maxY,
                                 windows: getRecentWindowsList())
        }
    }
       
    
    func initSwindle() {
        Swindler.initialize().then { (swindler) -> Void in
            self.swindler = swindler
            swindler.on { (event: FrontmostApplicationChangedEvent) in
               // print("new frontmost app: \(event.newValue?.bundleIdentifier ?? ååå"unknown").",
               //     "[old: \(event.oldValue?.bundleIdentifier ?? "unknown")]")
                if(event.newValue != nil && event.newValue?.focusedWindow.value != nil) {
                    self.addWindowToRecentsList(value: ((event.newValue?.focusedWindow.value)!))
                }
            }
        }
    }
    
    func getRecentWindowsList() -> [Swindler.Window] {
        return self.windows.reversed()
    }
    
    func addWindowToRecentsList(value: Swindler.Window) {
        let index = self.windows.index(of: value)
        if(index != nil && index! > -1) {
            //print("DOES CONTAIN!")
            self.windows.remove(at: index!)
        }
        if(self.windows.count > Constants.LIMIT_TRACKED_APPLICATIONS) {
            self.windows.removeLast()
        }
        var notTracked = false
        for notTrackStr in Constants.DO_NOT_TRACK_APPS {
            if(value.application.description.contains(notTrackStr)){
                notTracked = true
                break;
            }
        }
        if(!notTracked) {
            print("new active application")
            print(value.application.description)
            self.windows.append(value)
            print("Active window list changed:")
            for w in self.windows {
                print(w.application.description)
            }
        }
    }
    func sizingStrategyLatestMax(xRes:CGFloat, yRes:CGFloat, windows: [Swindler.Window])  {
        self.sizingStrategy = "sizingStrategyLatestMax"
          for (index,window) in windows.enumerated() {
              if(index == 0){
                window.size.set(CGSize(width: xRes, height: yRes))
                window.position.set(CGPoint(x: 0, y: 0))
                window.isMinimized.set(false)
              } else {
                window.isMinimized.set(true)
            }
        }
    }
    
    func sizingStrategy4(xRes:CGFloat, yRes:CGFloat, windows: [Swindler.Window]) {
        self.sizingStrategy = "sizingStrategy4"
         //print("SITTEN resu ja POW!!:\(xRes) x \(yRes)")
        // print(windows)
        for (index,window) in windows.enumerated() {
            //let title = window.title.value
            //print("resizing \(title)")
            if(index == 0){
               // print("EKA!")
                window.size.set(CGSize(width: xRes/2, height: yRes))
                window.position.set(CGPoint(x: 0, y: 0))
                window.isMinimized.set(false)
                win
            } else if(index < 4) {
                //print("SITTEN INDEX:\(index)")
                window.size.set(CGSize(width: xRes/2, height: yRes/3))
                window.position.set(CGPoint(x: xRes/2, y: (CGFloat(index-1)*(yRes/3.0))))
                window.isMinimized.set(false)
            } else {
               window.isMinimized.set(true)
            }
        }
    }
}

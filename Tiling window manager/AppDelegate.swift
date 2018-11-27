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
    static let LIMIT_TRACKED_APPLICATIONS = 100
    static let MAGIC_KEY = "å"
    static let INACTIVE_TEXT = "N/A"
    static let DO_NOT_TRACK_APPS = [
    "iterm", "kkammone"
    ]
}

class Strategy :NSObject {
    var text: String
    var strategy: String
    var keyEquivalent:String
    var function: (CGFloat, CGFloat, [Window]) -> ()
    init(text:String, strategy:String, function:@escaping (CGFloat, CGFloat, [Window]) -> (), keyEquivalent: String) {
        self.text=text
        self.strategy = strategy
        self.function = function
        self.keyEquivalent = keyEquivalent
    }
}

@NSApplicationMain //
class AppDelegate: NSObject, NSApplicationDelegate {

    var windows: [Swindler.Window] = []
    var swindler: Swindler.State!
    var sizingStrategyAlternated = false
    var sizingStrategy: String = "sizingStrategy4"
    var sizingStrategies : [String : Strategy] = [
        "sizingStrategy2" : Strategy(text:"1+1 windows", strategy:"sizingStrategy2",  function: sizingStrategy2, keyEquivalent:"2"),
        "sizingStrategy4" : Strategy(text:"1+3 windows", strategy:"sizingStrategy4",  function: sizingStrategy4, keyEquivalent:"4")
    ]
    
    var statusItem = NSStatusBar.system.statusItem(withLength: -1)

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        self.intializeMenu()
        self.initialize()
    }
    
    func intializeMenu() {
        self.statusItem.title = Constants.INACTIVE_TEXT
        self.statusItem.image = NSImage(named:NSImage.enterFullScreenTemplateName)
        self.statusItem.image?.size = NSSize(width: 18, height: 18)
        self.statusItem.length = 50
        self.statusItem.image?.isTemplate = true
        self.statusItem.highlightMode = true

        let menu = NSMenu()
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        for(key, value) in self.sizingStrategies {
            let item = createMenuItem(title: value.text, keyEquivalent: value.keyEquivalent, strategy: value.strategy)
            item.state = value.strategy == self.sizingStrategy ? NSControl.StateValue.on : NSControl.StateValue.off
            menu.addItem(item)
        }
        self.statusItem.menu = menu
    }
    func createMenuItem(title: String, keyEquivalent: String, strategy:String) -> NSMenuItem {
        let item =  NSMenuItem()
        item.title = title
        item.keyEquivalent = keyEquivalent
        item.action = #selector(changeStrategy(_:))
        item.representedObject = strategy
        return item
    }
    @objc func changeStrategy(_ sender: NSMenuItem) {
        for i in statusItem.menu!.items {
            i.state = NSControl.StateValue.off
        }
        print("setting on")
        sender.state = NSControl.StateValue.on
        print(sender.state)
        self.sizingStrategy = sender.representedObject as! String
        print(self.sizingStrategy)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }
    
    func initialize() {
        self.accessibilityCheck()
        self.listenKeypresses()
        self.initSwindle()
    }
    
    func accessibilityCheck() {
        print("===BE AWARE! THIS APPLICATION IS BASICALLY A KEY LOGGER. ALWAYS EVALUATE CODE BEFORE RUNNING===")
        print("===This application has to be accessibility trusted, checking...")
        guard AXSwift.checkIsProcessTrusted(prompt: true) else {
            print("Not trusted as an AX process; please authorize and re-launch")
            print("FAILED AXIsProcessTrustedWithOptions, which means that you are either running in app sandbox in xcode")
            print("or you haven't enabled accessibility setting for this application")
            return
        }
        self.statusItem.title = Constants.MAGIC_KEY
        print("===PASSED AXIsProcessTrustedWithOptions, Listening keypresses, monitoring windows")
    }
    
    func listenKeypresses() {
        print("Listening keypresses......")
        let opts = NSDictionary(object: kCFBooleanTrue, forKey: kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString) as CFDictionary
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: self.keypress)
    }
    
    func keypress(event: NSEvent) {
        if(event.type == NSEvent.EventType.keyDown && event.characters == Constants.MAGIC_KEY) {
            self.adjustSizing()
           //NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func adjustSizing() {
        self.sizingStrategyAlternated = !self.sizingStrategyAlternated
        print("adjustSizing")
        if(self.sizingStrategyAlternated) {
            print("Choosing sizingStrategy4")
            self.sizingStrategies[self.sizingStrategy]!.function( self.swindler.screens.first!.frame.maxX,
                                  self.swindler.screens.first!.frame.maxY,
                                  getRecentWindowsList())
        } else {
            print("Choosing sizingStrategyLatestMax")
            sizingStrategyLatestMax(xRes: self.swindler.screens.first!.frame.maxX,
                                 yRes: self.swindler.screens.first!.frame.maxY,
                                 windows: getRecentWindowsList())
        }
    }
       
    let debouncedFunction = Debouncer(delay: 0.3)

    func initSwindle() {
        Swindler.initialize().then { (swindler) -> Void in
            self.swindler = swindler
            swindler.on { (event: FrontmostApplicationChangedEvent) in
                if(event.newValue != nil && event.newValue?.focusedWindow.value != nil) {
                    self.addWindowToRecentsList(value: ((event.newValue?.focusedWindow.value)!))
                }
            }
            swindler.on { (event: WindowPosChangedEvent) in
                guard event.external == true else {
                    return
                }
                print("WINDOW MOVE EVENT ")
                print(event)
                self.debouncedFunction.setCallback {
                    print("DEBOUNCED EVENT")
                    self.snapToGrid(event: event)
                }
            }
        }
    }
    
    func snapToGrid(event: WindowPosChangedEvent) {
        let snapped = closestGridPosition(event: event)
        if(snapped != nil)  {
            event.window.position.set(snapped!.origin)
            event.window.size.set(snapped!.size)
        }
    }

    func closestGridPosition(event: WindowPosChangedEvent) -> NSRect?{
        let Y_MATCH_MULTIPLIER = CGFloat(0.1)
        let point = event.newValue
        let xRes = self.swindler.screens.first!.frame.maxX
        let yRes = self.swindler.screens.first!.frame.maxY
        if(point.y <  yRes*Y_MATCH_MULTIPLIER) {
            if(point.x < (xRes/2) ){
                return CGRect(x: 0, y: 0, width: xRes/2, height: yRes)
            } else if(point.x > (xRes/2)) {
                return CGRect(x: xRes/2, y: 0, width: xRes/2, height: yRes)
            }
        }
      return nil
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
        print("new active application")
        print(value.application.description)
        if(!notTracked) {
            print("tracked app, adding to list")
            self.windows.append(value)
            print("Active window list changed:")
            for w in self.windows {
                print(w.application.description)
            }
        } else {
            print("NOT tracked app, IGNORING")

        }
    }
    
   

}

func sizingStrategyLatestMax(xRes:CGFloat, yRes:CGFloat, windows: [Swindler.Window])  {
    for (index,window) in windows.enumerated() {
        if(index == 0){
            //window.frame.set(CGRect(x: 0, y: 0, width: xRes, height: yRes))
            window.position.set(CGPoint(x: 0, y: 0))
            window.size.set(CGSize(width: xRes, height: yRes))
            window.isMinimized.set(false)
        } else {
            window.isMinimized.set(true)
        }
    }
}

func sizingStrategy4(xRes:CGFloat, yRes:CGFloat, windows: [Swindler.Window]) {
    for (index,window) in windows.enumerated() {
        if(index == 0){
            // window.frame.set(CGRect(x: 0, y: 0, width: xRes/2, height: yRes))
            window.position.set(CGPoint(x: 0, y: 0))
            window.size.set(CGSize(width: xRes/2, height: yRes))
            window.isMinimized.set(false)
        } else if(index < 4) {
            //window.frame.set(CGRect(x: xRes/2, y: (CGFloat(index-1)*(yRes/3.0)), width: xRes/2, height:  yRes/3))
            window.position.set(CGPoint(x: xRes/2, y: (CGFloat(index-1)*(yRes/3.0))))
            window.size.set(CGSize(width: xRes/2, height:  yRes/3))
            window.isMinimized.set(false)
        } else {
            window.isMinimized.set(true)
        }
    }
}
func sizingStrategy2(xRes:CGFloat, yRes:CGFloat, windows: [Swindler.Window]) {
    for (index,window) in windows.enumerated() {
        if(index == 0){
            // window.frame.set(CGRect(x: 0, y: 0, width: xRes/2, height: yRes))
            window.position.set(CGPoint(x: 0, y: 0))
            window.size.set(CGSize(width: xRes/2, height: yRes))
            window.isMinimized.set(false)
        } else if(index <= 1) {
            //window.frame.set(CGRect(x: xRes/2, y: (CGFloat(index-1)*(yRes/3.0)), width: xRes/2, height:  yRes/3))
            window.position.set(CGPoint(x: xRes/2, y: 0))
            window.size.set(CGSize(width: xRes/2, height:  yRes))
            window.isMinimized.set(false)
        } else {
            window.isMinimized.set(true)
        }
    }
}

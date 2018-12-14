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



@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem = NSStatusBar.system.statusItem(withLength: -1)
    var windowing : Windowing = Windowing()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        self.intializeMenu()
        self.initialize()
        readConfig()
    }
    
    func intializeMenu() {
        self.statusItem.title = config.INACTIVE_TEXT
        self.statusItem.image = NSImage(named:NSImage.enterFullScreenTemplateName)
        self.statusItem.image?.size = NSSize(width: 18, height: 18)
        self.statusItem.length = 50
        self.statusItem.image?.isTemplate = true
        self.statusItem.highlightMode = true

        let menu = NSMenu()
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        menu.addItem(NSMenuItem(title: "Edit config", action: #selector(editConfig(_:)), keyEquivalent: "e"))
        menu.addItem(NSMenuItem(title: "Reload config", action: #selector(reloadConfig(_:)), keyEquivalent: "r"))

        for(key, value) in self.windowing.getSizingStrategies() {
            let item = createMenuItem(title: value.text, keyEquivalent: value.keyEquivalent, strategy: value.strategy)
            item.state = value.strategy == self.windowing.getSizingStrategy() ? NSControl.StateValue.on : NSControl.StateValue.off
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
    
    //    open func openFile(_ fullPath: String, withApplication appName: String?) -> Bool

    @objc func editConfig(_ sender: NSMenuItem) {
        NSWorkspace.shared.openFile(configPath , withApplication: "/Applications/TextEdit.app")
    }
    
    @objc func reloadConfig(_ sender: NSMenuItem) {
        Tiling_window_manager.reloadConfig()
    }
    
    @objc func changeStrategy(_ sender: NSMenuItem) {
        for i in statusItem.menu!.items {
            i.state = NSControl.StateValue.off
        }
        print("setting on")
        sender.state = NSControl.StateValue.on
        print(sender.state)
        self.windowing.setSizingStrategy(strategy: sender.representedObject as! String)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }
    
    func initialize() {
        self.accessibilityCheck()
        self.listenKeypresses()
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
        self.statusItem.title = config.MAGIC_KEY
        print("===PASSED AXIsProcessTrustedWithOptions, Listening keypresses, monitoring windows")
    }
    
    func listenKeypresses() {
        print("Listening keypresses......")
        let opts = NSDictionary(object: kCFBooleanTrue, forKey: kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString) as CFDictionary
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: self.keypress)
    }
    
    func keypress(event: NSEvent) {
        if(event.type == NSEvent.EventType.keyDown && event.characters == config.MAGIC_KEY) {
            self.windowing.adjustSizing()
           //NSApp.activate(ignoringOtherApps: true)
        }
    }

}

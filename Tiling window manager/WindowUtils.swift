
//
//  File.swift
//  Tiling window manager
//
//  Created by Kari Kammonen on 10/12/2018.
//  Copyright © 2018 Kari Kammonen. All rights reserved.
//

import Foundation
import Cocoa
import Swift
import AXSwift
import Swindler
import PromiseKit

class Strategy :NSObject {
    var text: String
    var strategy: String
    var keyEquivalent:String
    var function: (WindowsForScreen) -> ()
    init(text:String, strategy:String, function:@escaping (WindowsForScreen) -> (), keyEquivalent: String) {
        self.text=text
        self.strategy = strategy
        self.function = function
        self.keyEquivalent = keyEquivalent
    }
}

class WindowsForScreen : NSObject {
    var screen: Swindler.Screen
    var windows : [Swindler.Window] = []
    init(screen : Swindler.Screen) {
        self.screen = screen
    }
    func getWindows() -> [Swindler.Window] {
        return self.windows
    }
    func addWindow(window : Swindler.Window) {
        self.windows.append(window)
    }
}

class Windowing: NSObject {
    
    override init() {
        super.init()
        self.initSwindle()
    }

    var windows: [Swindler.Window] = []
    var swindler: Swindler.State!
    var sizingStrategyAlternated = false
    var sizingStrategy: String = "sizingStrategy4"
    var sizingStrategies : [String : Strategy] = [
        "sizingStrategy2" : Strategy(text:"1+1 windows", strategy:"sizingStrategy2",  function: sizingStrategy2, keyEquivalent:"2"),
        "sizingStrategy3" : Strategy(text:"1+2 windows", strategy:"sizingStrategy3",  function: sizingStrategy3, keyEquivalent:"3"),
        "sizingStrategy4" : Strategy(text:"1+3 windows", strategy:"sizingStrategy4",  function: sizingStrategy4, keyEquivalent:"4")
    ]
    
    func getSizingStrategies() -> [String : Strategy] {
        return self.sizingStrategies
    }
    
    func getSizingStrategy() -> String {
        return self.sizingStrategy
    }
    func setSizingStrategy(strategy: String)  {
         self.sizingStrategy = strategy
    }
    
    func changeStrategy(strategy: String){
        self.sizingStrategy = strategy
    }
    
    func adjustSizing() {
        self.sizingStrategyAlternated = !self.sizingStrategyAlternated
        print("adjustSizing")
        for a in self.getRecentWindowsList() {
            if(self.sizingStrategyAlternated) {
                self.sizingStrategies[self.sizingStrategy]!.function(a)
            } else {
                sizingStrategyLatestMax(ws: a)
            }
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
        
        guard event.window.screen != nil else {
            return nil
        }
        
        let Y_MATCH_MULTIPLIER = CGFloat(0.1)
        let point = event.newValue
        let xRes = event.window.screen!.frame.maxX
        let x = event.window.screen!.frame.minX
        let yRes = event.window.screen!.frame.maxY
        let y = event.window.screen!.frame.minY
        let width = event.window.screen!.frame.width
        let height = event.window.screen!.frame.height
        
        if(point.y <  yRes*Y_MATCH_MULTIPLIER) {
            if(point.x < (x + width/2) ){
                return CGRect(x: x, y: y, width: width/2, height: height)
            } else if(point.x > (xRes/2)) {
                return CGRect(x: x + width/2, y: y, width: width/2, height: height)
            }
        }
        return nil
    }
    
    func containsScreen(screen : Swindler.Screen, windowsForScreen :  [ WindowsForScreen ]) -> WindowsForScreen?{
        for w in windowsForScreen {
            if(w.screen == screen) {return w}
        }
        return nil
    }
    
    func getRecentWindowsList() -> [ WindowsForScreen ] {
        var ws : [ WindowsForScreen ] = []
        for w in self.windows.reversed() {
            guard w.screen != nil else {
                continue;
            }
            let a = self.containsScreen(screen: w.screen!, windowsForScreen: ws)
            if(a == nil) {
                let a1 = WindowsForScreen(screen: w.screen!)
                a1.addWindow(window: w)
                ws.append(a1)
            } else {
                a!.addWindow(window: w)
            }
        }
        return ws
    }
    
    func addWindowToRecentsList(value: Swindler.Window) {
        let index = self.windows.index(of: value)
        if(index != nil && index! > -1) {
            //print("DOES CONTAIN!")
            self.windows.remove(at: index!)
        }
        if(self.windows.count > config.LIMIT_TRACKED_APPLICATIONS) {
            self.windows.removeLast()
        }
        var notTracked = false
        for notTrackStr in config.DO_NOT_TRACK_APPS {
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

func sizingStrategyLatestMax(ws : WindowsForScreen)  {
    for (index,window) in ws.windows.enumerated() {
        if(index == 0){
            //window.frame.set(CGRect(x: 0, y: 0, width: xRes, height: yRes))
            window.position.set(CGPoint(x: ws.screen.frame.minX, y: ws.screen.frame.minY))
            window.size.set(CGSize(width: ws.screen.frame.width, height: ws.screen.frame.height))
            window.isMinimized.set(false)
        } else {
            window.isMinimized.set(true)
        }
    }
}

func sizingStrategy4(ws : WindowsForScreen) {
    for (index,window) in ws.windows.enumerated() {
        if(index == 0){
            // window.frame.set(CGRect(x: 0, y: 0, width: xRes/2, height: yRes))
            window.position.set(CGPoint(x: ws.screen.frame.minX, y: ws.screen.frame.minY))
            window.size.set(CGSize(width: ws.screen.frame.width/2, height: ws.screen.frame.height))
            window.isMinimized.set(false)
        } else if(index < 4) {
            //window.frame.set(CGRect(x: xRes/2, y: (CGFloat(index-1)*(yRes/3.0)), width: xRes/2, height:  yRes/3))
            window.position.set(CGPoint(x:ws.screen.frame.minX + ws.screen.frame.width / 2, y: ws.screen.frame.minY + (CGFloat(index-1)*( ws.screen.frame.height / 3))))
            window.size.set(CGSize(width:ws.screen.frame.width / 2, height:  ws.screen.frame.height / 3 ))
            window.isMinimized.set(false)
        } else {
            window.isMinimized.set(true)
        }
    }
}
func sizingStrategy3(ws : WindowsForScreen) {
    for (index,window) in ws.windows.enumerated() {
        if(index == 0){
            window.position.set(CGPoint(x: ws.screen.frame.minX, y: ws.screen.frame.minY))
            window.size.set(CGSize(width: ws.screen.frame.width/2, height: ws.screen.frame.height))
            window.isMinimized.set(false)
        } else if(index < 3) {
        
            window.position.set(CGPoint(x:ws.screen.frame.minX + ws.screen.frame.width / 2, y: ws.screen.frame.minY + (CGFloat(index-1)*( ws.screen.frame.height / 2))))
            window.size.set(CGSize(width:ws.screen.frame.width / 2, height:  ws.screen.frame.height / 2 ))
            window.isMinimized.set(false)
        } else {
            window.isMinimized.set(true)
        }
    }
}
func sizingStrategy2(ws : WindowsForScreen) {
    for (index,window) in ws.windows.enumerated() {
        if(index == 0){
            window.position.set(CGPoint(x: ws.screen.frame.minX, y: ws.screen.frame.minY))
            window.size.set(CGSize(width: ws.screen.frame.width/2, height: ws.screen.frame.height))
            window.isMinimized.set(false)
        } else if(index <= 1) {
            window.position.set(CGPoint(x:  ws.screen.frame.minX +  ws.screen.frame.width / 2, y:  ws.screen.frame.minY))
            window.size.set(CGSize(width: ws.screen.frame.width/2, height: ws.screen.frame.height))
            window.isMinimized.set(false)
        } else {
            window.isMinimized.set(true)
        }
    }

}


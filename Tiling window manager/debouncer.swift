// file: Debouncer.swift
import Foundation

class Debouncer: NSObject {
    var callback: (() -> ())?
    var delay: Double
    weak var timer: Timer?
    
    init(delay: Double) {
        self.delay = delay
    }
    
    func setCallback( callback: @escaping (() -> ())) {
        self.callback = callback
        call()
    }
    func call() {
        timer?.invalidate()
        let nextTimer = Timer.scheduledTimer(timeInterval: delay, target: self, selector: #selector(Debouncer.fireNow), userInfo: nil, repeats: false)
        timer = nextTimer
    }
    
    @objc func fireNow() {
        if(self.callback != nil){
            self.callback!()
        }
    }
}

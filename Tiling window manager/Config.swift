//
//  Config.swift
//  Tiling window manager
//
//  Created by Kari Kammonen on 14/12/2018.
//  Copyright © 2018 Kari Kammonen. All rights reserved.
//

import Foundation

let configPath = NSString(string: "~/.awithdot.config").expandingTildeInPath

struct Config : Codable {
    let LIMIT_TRACKED_APPLICATIONS :Int
    let MAGIC_KEY :String
    let INACTIVE_TEXT :String
    let DO_NOT_TRACK_APPS :[String]
}

let defaultConfig = Config(LIMIT_TRACKED_APPLICATIONS: 100,
                           MAGIC_KEY: "å",
                           INACTIVE_TEXT: "N/A",
                           DO_NOT_TRACK_APPS: [
                                "iterm", "kkammone"
                           ])

var config = readConfig(defaultConfig: defaultConfig)

func reloadConfig() {
    print("===RELOAD CONFIG")
    config = readConfig(defaultConfig: defaultConfig)
}

func readConfig(defaultConfig: Config) -> Config{
    do {
        let contents = try NSString(contentsOfFile: configPath, encoding: String.Encoding.utf8.rawValue).data(using: String.Encoding.utf8.rawValue)
        let config = try JSONDecoder().decode(Config.self, from: contents!)
        print("read config:")
        print(config)
        return config
    } catch let error as NSError { //file didn't exist, create a new one
        print("Failed to read config, created a new one: " + configPath)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(defaultConfig)
            let jsonString = String(data: jsonData, encoding: .utf8)
            try jsonString?.write(to:URL(fileURLWithPath:configPath), atomically: true, encoding: String.Encoding.utf8)
            return defaultConfig
        } catch let error as NSError {
            
        }
    }
    return defaultConfig
}

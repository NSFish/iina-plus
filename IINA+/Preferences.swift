//
//  Preferences.swift
//  iina+
//
//  Created by xjbeta on 2018/7/17.
//  Copyright © 2018 xjbeta. All rights reserved.
//

import Cocoa

class Preferences: NSObject {
    static let shared = Preferences()
    
    private override init() {
    }

    let prefs = UserDefaults.standard
    let keys = PreferenceKeys.self
    
    var livePlayer: LivePlayer {
        get {
            return LivePlayer(raw: defaults(.livePlayer) as? String ?? "")
        }
        set {
            defaultsSet(newValue.rawValue, forKey: .livePlayer)
        }
    }
    
    var liveDecoder: LiveDecoder {
        get {
            return LiveDecoder(raw: defaults(.liveDecoder) as? String ?? "")
        }
        set {
            defaultsSet(newValue.rawValue, forKey: .liveDecoder)
        }
    }
    
    @objc var enableDanmaku: Bool {
        get {
            return defaults(.enableDanmaku) as? Bool ?? false
        }
        set {
            defaultsSet(newValue, forKey: .enableDanmaku)
        }
    }
    
    var dmBlockType: [String] {
        get {
            return defaults(.dmBlockType) as? [String] ?? []
        }
        set {
            defaultsSet(newValue, forKey: .dmBlockType)
        }
    }
    
    var dmBlockList: BlockList {
        get {
            if let data = defaults(.dmBlockList) as? Data,
                let dmBlockList = BlockList(data: data) {
                return dmBlockList
            } else {
                return BlockList()
            }
        }
        set {
            defaultsSet(newValue.encode(), forKey: .dmBlockList)
        }
    }
    
    @objc dynamic var danmukuBlockListChanged: String {
        get {
            return defaults(.danmukuBlockListChanged) as? String ?? "YES"
        }
        set {
            defaultsSet(newValue, forKey: .danmukuBlockListChanged)
            didChangeValue(for: \.danmukuBlockListChanged)
        }
    }
    
    @objc var danmukuFontFamilyName: String {
        get {
            return defaults(.danmukuFontFamilyName) as? String ?? "SimHei"
        }
        set {
            defaultsSet(newValue, forKey: .danmukuFontFamilyName)
            didChangeValue(for: \.danmukuFontFamilyName)
        }
    }
    
    @objc var danmukuFontWeight: String {
        get {
            return defaults(.danmukuFontWeight) as? String ?? "Regular"
        }
        set {
            defaultsSet(newValue, forKey: .danmukuFontWeight)
            didChangeValue(for: \.danmukuFontWeight)
        }
    }
    
    @objc var danmukuFontSize: Int {
        get {
//            return defaults(.danmukuFontSize) as? Int ?? 24
            return 24
        }
        set {
            defaultsSet(newValue, forKey: .danmukuFontSize)
            didChangeValue(for: \.danmukuFontSize)
        }
    }
    
    @objc dynamic var dmSpeed: Double {
        get {
            return defaults(.dmSpeed) as? Double ?? 680
        }
        set {
            defaultsSet(newValue, forKey: .dmSpeed)
            didChangeValue(for: \.dmSpeed)
        }
    }
    
    @objc dynamic var dmOpacity: Double {
        get {
            return defaults(.dmOpacity) as? Double ?? 1
        }
        set {
            defaultsSet(newValue, forKey: .dmOpacity)
            didChangeValue(for: \.dmOpacity)
        }
    }
    
    @objc dynamic var dmPort: Int {
        get {
            
            if Processes.shared.iinaBuildVersion() > 16 {
                return defaults(.dmPort) as? Int ?? 19080
            } else {
                return 19080
            }
        }
        set {
            defaultsSet(newValue, forKey: .dmPort)
            didChangeValue(for: \.dmPort)
        }
    }

}

private extension Preferences {
    
    func defaults(_ key: PreferenceKeys) -> Any? {
        return prefs.value(forKey: key.rawValue) as Any?
    }
    
    func defaultsSet(_ value: Any, forKey key: PreferenceKeys) {
        prefs.setValue(value, forKey: key.rawValue)
    }
}

enum PreferenceKeys: String {
    case livePlayer
    case liveDecoder
    case enableDanmaku
    case danmukuBlockListChanged
    case danmukuFontFamilyName
    case danmukuFontWeight
    case danmukuFontSize
    case dmSpeed
    case dmOpacity
    case dmBlockType
    case dmBlockList
    case dmPort
}

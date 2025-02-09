//
//  StringExtension.swift
//  iina+
//
//  Created by xjbeta on 2018/8/10.
//  Copyright © 2018 xjbeta. All rights reserved.
//

import Cocoa

extension String {
    func subString(from startString: String, to endString: String) -> String {
        var str = self
        if let startIndex = self.range(of: startString)?.upperBound {
            str.removeSubrange(str.startIndex ..< startIndex)
            if let endIndex = str.range(of: endString)?.lowerBound {
                str.removeSubrange(endIndex ..< str.endIndex)
                return str
            }
        }
        return ""
    }
    
    func subString(from startString: String) -> String {
        var str = self
        if let startIndex = self.range(of: startString)?.upperBound {
            str.removeSubrange(self.startIndex ..< startIndex)
            return str
        }
        return ""
    }
    
    func subString(to endString: String) -> String {
        var str = self
        if let endIndex = str.range(of: endString)?.lowerBound {
            str.removeSubrange(endIndex ..< str.endIndex)
            return str
        }
        return ""
    }
    
    func delete(between startString: String, and endString: String) -> String {
        var str = self
        if let start = self.range(of: startString), let end = self.range(of: endString) {
            str.removeSubrange(start.upperBound ..< end.lowerBound)
            return str
        }
        return ""
    }
    
    //MARK: - String Path
    var pathComponents: [String] {
        get {
            return (self.standardizingPath as NSString).pathComponents
        }
    }
    
    var lastPathComponent: String {
        get {
            return (self as NSString).lastPathComponent
        }
    }
    
    var standardizingPath: String {
        get {
            return (self as NSString).standardizingPath
        }
    }
    
    mutating func deleteLastPathComponent() {
        self = (self.standardizingPath as NSString).deletingLastPathComponent
    }
    
    mutating func deletePathExtension() {
        self = (self.standardizingPath as NSString).deletingPathExtension
    }
    
    mutating func appendingPathComponent(_ str: String) {
        self = (self.standardizingPath as NSString).appendingPathComponent(str)
    }
    
    func isChildPath(of url: String) -> Bool {
        guard self.pathComponents.count > url.pathComponents.count else {
            return false
        }
        var t = self.pathComponents
        t.removeSubrange(url.pathComponents.count ..< self.pathComponents.count)
        return t == url.pathComponents
    }
    
    func isChildItem(of url: String) -> Bool {
        var pathComponents = self.pathComponents
        pathComponents.removeLast()
        return pathComponents == url.pathComponents
    }

    var isUrl: Bool {
        get {
            do {
                let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
                let matches = detector.matches(in: self, options: [], range: NSRange(location: 0, length: self.utf16.count))
                return matches.count == 1
            } catch {
                return false
            }
        }
    }
    
    mutating func coverUrlFormatter(
        site: SupportSites,
        maxH: Int = 200) {
            
        var u = self
        switch site {
        case .bilibili, .bangumi:
            u += "@\(maxH)h.jpg"
        case .biliLive:
            u += "@\(maxH)w_\(maxH)h_1c.jpg"
        case .huya:
//            default 140x140
            break
        case .douyu, .cc163:
//            default 200x200
            break
        default:
            break
        }
        self = u
    }
    
    func toHexString() -> String {
        self.data(using: .utf8)?.toHexString() ?? ""
    }
    
    func base64Decode() -> String {
        guard let data = Data(base64Encoded: self), let s = String(data: data, encoding: .utf8) else {
            return ""
        }
        return s
    }
}


// https://stackoverflow.com/a/32306142
extension StringProtocol {
    func index(of string: Self, options: String.CompareOptions = []) -> Index? {
        return range(of: string, options: options)?.lowerBound
    }
    
    func endIndex(of string: Self, options: String.CompareOptions = []) -> Index? {
        return range(of: string, options: options)?.upperBound
    }
    
    func indexes(of string: Self, options: String.CompareOptions = []) -> [Index] {
        var result: [Index] = []
        var startIndex = self.startIndex
        while startIndex < endIndex,
            let range = self[startIndex...].range(of: string, options: options) {
                result.append(range.lowerBound)
                startIndex = range.lowerBound < range.upperBound ? range.upperBound :
                    index(range.lowerBound, offsetBy: 1, limitedBy: endIndex) ?? endIndex
        }
        return result
    }
}

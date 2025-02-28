//
//  BiliLive.swift
//  IINA+
//
//  Created by xjbeta on 4/26/22.
//  Copyright © 2022 xjbeta. All rights reserved.
//

import Cocoa
import PromiseKit
import Alamofire
import PMKAlamofire
import Marshal

class BiliLive: NSObject, SupportSiteProtocol {
    
    enum APIType {
        case playUrl, roomPlayInfo, html
    }
    
    let apiType = APIType.roomPlayInfo
    
    func liveInfo(_ url: String) -> Promise<LiveInfo> {
        var info = BiliLiveInfo()
        return getBiliLiveRoomId(url).get {
            info = $0
        }.then {
            self.getBiliUserInfo($0.roomId)
        }.map {
            info.name = $0.name
            info.avatar = $0.avatar
            return info
        }
    }
    
    func decodeUrl(_ url: String) -> Promise<YouGetJSON> {
        var yougetJson = YouGetJSON(rawUrl: url)
        return getBiliLiveRoomId(url).get {
            yougetJson.title = $0.title
            yougetJson.id = $0.roomId
        }.get {
            yougetJson.id = $0.roomId
        }.then { _ in
            self.getBiliLiveJSON(yougetJson)
        }
    }
    
    func getBiliLiveRoomId(_ url: String) -> Promise<(BiliLiveInfo)> {
        AF.request("https://api.live.bilibili.com/room/v1/Room/get_info?room_id=\(url.lastPathComponent)").responseData().map {
            let json: JSONObject = try JSONParser.JSONObjectWithData($0.data)
            let longID: Int = try json.value(for: "data.room_id")

            var info = BiliLiveInfo()
            info.title = try json.value(for: "data.title")
            info.isLiving = try json.value(for: "data.live_status") == 1
            info.roomId = longID
            info.cover = try json.value(for: "data.user_cover")
            return info
        }
    }
    
    func getBiliUserInfo(_ roomId: Int) -> Promise<(BiliLiveInfo)> {
        AF.request("https://api.live.bilibili.com/live_user/v1/UserInfo/get_anchor_in_room?roomid=\(roomId)").responseData().map {
            let json: JSONObject = try JSONParser.JSONObjectWithData($0.data)
            var info = BiliLiveInfo()
            info.name = try json.value(for: "data.info.uname")
            info.avatar = try json.value(for: "data.info.face")
            return info
        }
    }
    
    func getBiliLiveJSON(_ yougetJSON: YouGetJSON, _ quality: Int = 20000) -> Promise<(YouGetJSON)> {
        
        let result = yougetJSON
        let roomID = result.id
        
        
        switch apiType {
        case .playUrl:
            let u = "https://api.live.bilibili.com/room/v1/Room/playUrl?cid=\(roomID)&qn=\(quality)&platform=web"
            
            return AF.request(u).responseData().map {
                let json: JSONObject = try JSONParser.JSONObjectWithData($0.data)
                let playUrl: BiliLiveOldPlayUrl = try BiliLiveOldPlayUrl(object: json)
                return playUrl.write(to: result)
            }
        case .roomPlayInfo:
            let u = "https://api.live.bilibili.com/xlive/web-room/v2/index/getRoomPlayInfo?room_id=\(roomID)&protocol=0,1&format=0,1,2&codec=0,1&qn=\(quality)&platform=web&ptype=8&dolby=5"

            return AF.request(u).responseData().map {
                let json: JSONObject = try JSONParser.JSONObjectWithData($0.data)
                
                if try json.value(for: "data.encrypted") == true,
                   try json.value(for: "data.pwd_verified") == false {
                    throw VideoGetError.needPassWork
                }
                
                let playUrl: BiliLivePlayUrl = try BiliLivePlayUrl(object: json)
                return playUrl.write(to: result)
            }
        case .html:
            let u = "https://live.bilibili.com/\(roomID)"
            return AF.request(u).responseString().map {
                let s = $0.string.subString(from: "<script>window.__NEPTUNE_IS_MY_WAIFU__=", to: "</script>")
                let data = s.data(using: .utf8) ?? Data()
                
                let json: JSONObject = try JSONParser.JSONObjectWithData(data)
                let playUrl: BiliLivePlayUrl = try json.value(for: "roomInitRes")
                return playUrl.write(to: result)
            }
        }
    }
    
    func getRoomList(_ url: String) -> Promise<(String, [BiliLiveVideoSelector])> {
        var re = [BiliLiveVideoSelector]()
        
        return AF.request(url).responseString().map { res -> [BiliLiveVideoSelector] in
            let s = res.string.subString(from: "window.__initialState = ", to: ";\n")
            guard let data = s.data(using: .utf8),
                  let json: JSONObject = try? JSONParser.JSONObjectWithData(data) else { return [] }
            
            let list: [BiliLiveRoomList] = try json.value(for: "live-non-revenue-player")
            
            re = list.first?.roomList.enumerated().map {
                BiliLiveVideoSelector(
                    id: $0.element.roomId,
                    sid: "",
                    index: $0.offset,
                    title: $0.element.tabText,
                    url: "")
            } ?? []
            return re
        }.then {
            self.liveInfos($0.compactMap({ Int($0.id) }))
        }.map {
            guard let json: JSONObject = try? JSONParser.JSONObjectWithData($0) else { return ("", []) }
            
            let rooms: [String: BiliLiveBaseInfo] = try json.value(for: "data.by_room_ids")
            
            re.enumerated().forEach { s in
                let id = s.element.id
                guard let info = rooms[id] ?? rooms.values.first(where: { $0.shortId == Int(id) }) else {
                    re[s.offset].url = "https://live.bilibili.com/\(id)"
                    return
                }
                
                re[s.offset].isLiving = info.isLiving
                re[s.offset].url = info.url
                re[s.offset].sid = "\(info.shortId)"
                if re[s.offset].title == "" {
                    re[s.offset].title = info.uname
                }
            }
            return ("", re)
        }
    }
    
    func liveInfos(_ roomIds: [Int]) -> Promise<Data> {
        let s = roomIds.filter {
            $0 > 0
        }.map {
            "room_ids=\($0)"
        }.joined(separator: "&")
        
        guard s.count > 0 else { return .value(Data()) }
        
        let u = "https://api.live.bilibili.com/xlive/web-room/v1/index/getRoomBaseInfo?\(s)&req_biz=web_room_componet"
        
        return AF.request(u).responseData().map({ $0.data })
    }
}

struct BiliLiveInfo: Unmarshaling, LiveInfo {
    var title: String = ""
    var name: String = ""
    var avatar: String = ""
    var isLiving = false
    var roomId: Int = -1
    var cover: String = ""
    
    var site: SupportSites = .biliLive
    
    init() {
    }
    
    init(object: MarshaledObject) throws {
        title = try object.value(for: "title")
        name = try object.value(for: "info.uname")
        avatar = try object.value(for: "info.face")
        isLiving = "\(try object.any(for: "live_status"))" == "1"
    }
}

struct BiliLiveBaseInfo: Unmarshaling {
    let roomId: Int
    let shortId: Int
    let isLiving: Bool
    let url: String
    
    let title: String
    let uname: String
    
    init(object: MarshaledObject) throws {
        roomId = try object.value(for: "room_id")
        shortId = try object.value(for: "short_id")
        isLiving = try object.value(for: "live_status") == 1
        url = try object.value(for: "live_url")
        title = try object.value(for: "title")
        uname = try object.value(for: "uname")
    }
}

struct BiliLiveOldPlayUrl: Unmarshaling {
    let currentQuality: Int
    let acceptQuality: [String]
    let currentQn: Int
    let qualityDescription: [QualityDescription]
    let durl: [Durl]
    
    struct QualityDescription: Unmarshaling {
        let qn: Int
        let desc: String
        init(object: MarshaledObject) throws {
            qn = try object.value(for: "qn")
            desc = try object.value(for: "desc")
        }
    }
    
    struct Durl: Unmarshaling {
        var url: String
        init(object: MarshaledObject) throws {
            url = try object.value(for: "url")
        }
    }
    
    init(object: MarshaledObject) throws {
        currentQuality = try object.value(for: "data.current_quality")
        acceptQuality = try object.value(for: "data.accept_quality")
        currentQn = try object.value(for: "data.current_qn")
        qualityDescription = try object.value(for: "data.quality_description")
        durl = try object.value(for: "data.durl")
    }
    
    func write(to yougetJson: YouGetJSON) -> YouGetJSON {
        var json = yougetJson
        let urls = durl.map {
            $0.url
        }
        let cqn = currentQn
        
        qualityDescription.forEach {
            var s = Stream(url: "")
            s.quality = $0.qn
            if cqn == $0.qn {
                s.src = urls
                s.url = urls.first
            }
            json.streams[$0.desc] = s
        }
        return json
    }
}

struct BiliLivePlayUrl: Unmarshaling {
    let qualityDescriptions: [QualityDescription]
    let streams: [BiliLiveStream]

    struct QualityDescription: Unmarshaling {
        let qn: Int
        let desc: String
        init(object: MarshaledObject) throws {
            qn = try object.value(for: "qn")
            desc = try object.value(for: "desc")
        }
    }
    
    struct BiliLiveStream: Unmarshaling {
        let protocolName: String
        let formats: [Format]
        init(object: MarshaledObject) throws {
            protocolName = try object.value(for: "protocol_name")
            formats = try object.value(for: "format")
        }
    }
    
    struct Format: Unmarshaling {
        let formatName: String
        let codecs: [Codec]
        init(object: MarshaledObject) throws {
            formatName = try object.value(for: "format_name")
            codecs = try object.value(for: "codec")
        }
    }
    
    struct Codec: Unmarshaling {
        let codecName: String
        let currentQn: Int
        let acceptQns: [Int]
        let baseUrl: String
        let urlInfos: [UrlInfo]
        init(object: MarshaledObject) throws {
            codecName = try object.value(for: "codec_name")
            currentQn = try object.value(for: "current_qn")
            acceptQns = try object.value(for: "accept_qn")
            baseUrl = try object.value(for: "base_url")
            urlInfos = try object.value(for: "url_info")
        }
        
        func urls() -> [String] {
            urlInfos.map {
                $0.host + baseUrl + $0.extra
            }
        }
    }
    
    struct UrlInfo: Unmarshaling {
        let host: String
        let extra: String
        let streamTtl: Int
        init(object: MarshaledObject) throws {
            host = try object.value(for: "host")
            extra = try object.value(for: "extra")
            streamTtl = try object.value(for: "stream_ttl")
        }
    }
    
    init(object: MarshaledObject) throws {
        qualityDescriptions = try object.value(for: "data.playurl_info.playurl.g_qn_desc")
        streams = try object.value(for: "data.playurl_info.playurl.stream")
    }
    
    func write(to yougetJson: YouGetJSON) -> YouGetJSON {
        var json = yougetJson
        
        func write(_ codec: BiliLivePlayUrl.Codec) {
            qualityDescriptions.filter {
                codec.acceptQns.contains($0.qn)
            }.forEach {
                var s = Stream(url: "")
                s.quality = $0.qn
                if codec.currentQn == $0.qn {
                    var urls = MBGA.update(codec.urls())
                    s.url = urls.removeFirst()
                    s.src = urls
                }
                json.streams[$0.desc] = s
            }
        }
        
        // FLV AVC
        if let codec = streams.first(where: { $0.protocolName == "http_stream" })?.formats.first(where: { $0.formatName == "flv" })?.codecs.first(where: { $0.codecName == "avc" }) {
            write(codec)
        }
        
        // M3U8 HEVC
        if Preferences.shared.bililiveHevc,
           let codec = streams.first(where: { $0.protocolName == "http_hls" })?.formats.first(where: { $0.formatName == "fmp4" })?.codecs.first(where: { $0.codecName == "hevc" }) {
            write(codec)
        }
        return json
    }
}

struct BiliLiveRoomList: Unmarshaling {
    let defaultRoomId: String
    let roomList: [Room]
    
    struct Room: Unmarshaling {
        let roomId: String
        let tabText: String
        init(object: MarshaledObject) throws {
            roomId = try object.value(for: "roomId")
            tabText = try object.value(for: "tabText")
        }
    }
    
    init(object: MarshaledObject) throws {
        defaultRoomId = try object.value(for: "defaultRoomId")
        roomList = try object.value(for: "roomsConfig")
    }
}


struct BiliLiveVideoSelector: VideoSelector {
    let id: String
    var sid: String
    var coverUrl: URL?
    var isLiving: Bool = false
    
    let site = SupportSites.biliLive
    let index: Int
    var title: String
    var url: String
}

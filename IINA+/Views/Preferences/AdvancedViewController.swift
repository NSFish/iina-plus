//
//  AdvancedViewController.swift
//  iina+
//
//  Created by xjbeta on 2018/8/13.
//  Copyright © 2018 xjbeta. All rights reserved.
//

import Cocoa
import SDWebImage

class AdvancedViewController: NSViewController, NSMenuDelegate {
    
    @IBOutlet weak var scrollButton: NSButton!
    @IBOutlet weak var topButton: NSButton!
    @IBOutlet weak var bottomButton: NSButton!
    @IBOutlet weak var colorButton: NSButton!
    @IBOutlet weak var advancedButton: NSButton!
    
    @IBOutlet weak var cacheSizeTextField: NSTextField!
    @IBAction func cleanUpCache(_ sender: NSButton) {
        SDImageCache.shared.clearDisk(onCompletion: nil)
        initCacheSize()
    }
    
    var blockTypeButtons: [NSButton: String] = [:]
    @IBAction func chooseBlockType(_ sender: NSButton) {
        Preferences.shared.dmBlockType = blockTypeButtons.filter {
            $0.key.state == .on
        }.map {
            $0.value
        }
    }
    
    lazy var choosePanel: NSOpenPanel = {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedFileTypes = ["xml"]
        panel.prompt = "Select"
        return panel
    }()
    
    @IBOutlet weak var blockListPopUpButton: NSPopUpButton!
    
// MARK: - Live State Color
    @IBOutlet var livingColorPick: ColorPickButton!
    @IBOutlet var offlineColorPick: ColorPickButton!
    @IBOutlet var replayColorPick: ColorPickButton!
    @IBOutlet var unknownColorPick: ColorPickButton!
    
    
    var colorPanelCloseNotification: NSObjectProtocol?
    var currentPicker: ColorPickButton?
    
    @IBAction func pickColor(_ sender: ColorPickButton) {
        currentPicker = sender
        
        let colorPanel = NSColorPanel.shared
        colorPanel.color = sender.color
        colorPanel.setTarget(self)
        colorPanel.setAction(#selector(colorDidChange))
        colorPanel.makeKeyAndOrderFront(self)
        colorPanel.isContinuous = true
    }
    
    let pref = Preferences.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        blockTypeButtons[scrollButton] = "Scroll"
        blockTypeButtons[topButton] = "Top"
        blockTypeButtons[bottomButton] = "Bottom"
        blockTypeButtons[colorButton] = "Color"
        blockTypeButtons[advancedButton] = "Advanced"
        blockTypeButtons.filter {
            Preferences.shared.dmBlockType.contains($0.value)
            }.forEach {
                $0.key.state = .on
        }
        
        initBlockListMenu()
        
        colorPanelCloseNotification = NotificationCenter.default.addObserver(forName: NSColorPanel.willCloseNotification, object: nil, queue: .main) { _ in
            self.currentPicker = nil
        }
        
        livingColorPick.color = pref.stateLiving
        offlineColorPick.color = pref.stateOffline
        replayColorPick.color = pref.stateReplay
        unknownColorPick.color = pref.stateUnknown
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        initCacheSize()
    }
    
    func initCacheSize() {
        SDImageCache.shared.calculateSize { count, size in
            let s = String(format: "%.2f MB", Double(size) / 1024 / 1024)
            self.cacheSizeTextField.stringValue = s
        }
    }
    
    func initBlockListMenu() {
        let blockList = Preferences.shared.dmBlockList
    
        // Add the custom block list item
        if blockList.customBlockListData != nil {
            let title = blockList.customBlockListName
            if blockListPopUpButton.itemArray.count == 6 {
                let item = blockListPopUpButton.itemArray[3]
                item.title = title
            } else if blockListPopUpButton.itemArray.count == 5 {
                blockListPopUpButton.menu?.insertItem(withTitle: title, action: nil, keyEquivalent: "", at: 3)
            }
        }
        
        blockListPopUpButton.selectItem(at: blockList.type.rawValue)
    }
    
    func menuDidClose(_ menu: NSMenu) {
        guard menu == blockListPopUpButton.menu, let item = blockListPopUpButton.selectedItem else { return }
        if item == menu.items.last {
            guard let window = self.view.window else { return }
            choosePanel.beginSheetModal(for: window) {
                guard $0 == .OK,
                    let url = self.choosePanel.url,
                    let content = FileManager.default.contents(atPath: url.path) else {
                        self.initBlockListMenu()
                        return
                }
                var fileName = url.lastPathComponent
                fileName.deletePathExtension()
                Preferences.shared.dmBlockList.customBlockListName = fileName
                Preferences.shared.dmBlockList.customBlockListData = content
                Preferences.shared.dmBlockList.type = .custom
                self.initBlockListMenu()
            }
        } else {
            let index = blockListPopUpButton.indexOfSelectedItem
            Preferences.shared.dmBlockList.type = BlockList.BlockListType(rawValue: index) ?? .none
        }
    }
    
    @objc func colorDidChange(sender: NSColorPanel) {
        let colorPanel = sender
        guard let picker = currentPicker else { return }
        
        picker.color = colorPanel.color
        
        switch picker {
        case livingColorPick:
            pref.stateLiving = colorPanel.color
        case offlineColorPick:
            pref.stateOffline = colorPanel.color
        case replayColorPick:
            pref.stateReplay = colorPanel.color
        case unknownColorPick:
            pref.stateUnknown = colorPanel.color
        default:
            break
        }
    }
    
    deinit {
        if let n = colorPanelCloseNotification {
            NotificationCenter.default.removeObserver(n)
        }
    }
}


struct BlockList {
    enum BlockListType: Int {
        case none, basic, plus, custom
    }
    var type: BlockListType = .none
    var customBlockListData: Data?
    var customBlockListName = ""
    
    init() {
    }
    
    init?(data: Data) {
        if let coding = NSKeyedUnarchiver.unarchiveObject(with: data) as? Encoding {
            type = coding.type
            customBlockListData = coding.customBlockListData
            customBlockListName = coding.customBlockListName
        } else {
            return nil
        }
    }
    
    
    func encode() -> Data {
        return NSKeyedArchiver.archivedData(withRootObject: Encoding(self))
    }
    
    @objc(_TtCV5iina_9BlockListP33_B396274A33D598332DFAB276960FF64F8Encoding)
    private class Encoding: NSObject, NSCoding {
        
        var type: BlockListType = .none
        var customBlockListData: Data?
        var customBlockListName = ""
        
        init(_ blockList: BlockList) {
            type = blockList.type
            customBlockListData = blockList.customBlockListData
            customBlockListName = blockList.customBlockListName
        }
        
        required init?(coder aDecoder: NSCoder) {
            self.type = BlockListType(rawValue: aDecoder.decodeInteger(forKey: "type")) ?? .none
            self.customBlockListData = aDecoder.decodeObject(forKey: "customBlockListData") as? Data
            self.customBlockListName = aDecoder.decodeObject(forKey: "customBlockListName") as? String ?? ""
        }
        
        func encode(with aCoder: NSCoder) {
            aCoder.encode(self.type.rawValue, forKey: "type")
            aCoder.encode(self.customBlockListData, forKey: "customBlockListData")
            aCoder.encode(self.customBlockListName, forKey: "customBlockListName")
        }
    }
}


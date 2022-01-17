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
    
    var blockTypeButtons: [NSButton] = []
    @IBAction func chooseBlockType(_ sender: NSButton) {
        Preferences.shared.dmBlockType = blockTypeButtons.filter {
            $0.state == .on
        }.map { $0.title }
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        blockTypeButtons.append(scrollButton)
        blockTypeButtons.append(topButton)
        blockTypeButtons.append(bottomButton)
        blockTypeButtons.append(colorButton)
        blockTypeButtons.append(advancedButton)
        blockTypeButtons.filter {
            Preferences.shared.dmBlockType.contains($0.title)
            }.forEach {
                $0.state = .on
        }
        
        initBlockListMenu()
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
        if blockList.customBlockListFileURL != nil {
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
                    let _ = FileManager.default.contents(atPath: url.path) else {
                        self.initBlockListMenu()
                        return
                }
                
                var fileName = url.lastPathComponent
                fileName.deletePathExtension()
                Preferences.shared.dmBlockList.customBlockListName = fileName
                Preferences.shared.dmBlockList.customBlockListFileURL = url
                Preferences.shared.dmBlockList.type = .custom
                self.initBlockListMenu()
            }
        } else {
            let index = blockListPopUpButton.indexOfSelectedItem
            Preferences.shared.dmBlockList.type = BlockList.BlockListType(rawValue: index) ?? .none
        }
    }
}


struct BlockList {
    enum BlockListType: Int {
        case none, basic, plus, custom
    }
    var type: BlockListType = .none
    var customBlockListName = ""
    var customBlockListFileURL: URL?
    
    init() {
    }
    
    init?(data: Data) {
        if let coding = NSKeyedUnarchiver.unarchiveObject(with: data) as? Encoding {
            type = coding.type
            customBlockListName = coding.customBlockListName
            customBlockListFileURL = coding.customBlockListFileURL
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
        var customBlockListName = ""
        var customBlockListFileURL: URL?
        
        init(_ blockList: BlockList) {
            type = blockList.type
            customBlockListName = blockList.customBlockListName
            customBlockListFileURL = blockList.customBlockListFileURL
        }
        
        required init?(coder aDecoder: NSCoder) {
            self.type = BlockListType(rawValue: aDecoder.decodeInteger(forKey: "type")) ?? .none
            self.customBlockListName = aDecoder.decodeObject(forKey: "customBlockListName") as? String ?? ""
            self.customBlockListFileURL = aDecoder.decodeObject(forKey: "customBlockListFileURL") as? URL
        }
        
        func encode(with aCoder: NSCoder) {
            aCoder.encode(self.type.rawValue, forKey: "type")
            aCoder.encode(self.customBlockListName, forKey: "customBlockListName")
            aCoder.encode(self.customBlockListFileURL, forKey: "customBlockListFileURL")
        }
    }
}


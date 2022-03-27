//
//  Common.swift
//
//  Created by EddieHua.
//

import Foundation

class Common {
    static var developerMode = false
}
// 沒有抓到 多國語系的字串內容的話，就回傳 原本的 KEY
func LocalizedString(_ key: String) -> String {
    let text = NSLocalizedString(key, comment:"")
    if text == "" {
        return key
    }
    return text
}

// 在 release 時不會顯示的 Log
func dPrint(_ message: String,
            file: String = #file,
            line: Int = #line)
{
    #if DEBUG
        let fileName = ((file as NSString).lastPathComponent as NSString).deletingPathExtension
        //debugPrint(String(format:"[%@:%03d] %@", fileName, line, message))
        print("[\(fileName):\(line)],  \(message)")
    #endif
}


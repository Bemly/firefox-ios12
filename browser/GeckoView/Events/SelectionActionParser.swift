//
//  SelectionActionParser.swift
//  Reynard
//
//  Created by Minh Ton on 16/6/26.
//

import CoreGraphics
import Foundation

func parseSelectionActionRequest(_ message: [String: Any?]?) -> SelectionActionRequest? {
    guard let actionID = message?["actionId"] as? String,
          let actions = message?["actions"] as? [String],
          let selection = message?["selection"] as? String,
          let clientRect = parseClientRect(message?["clientRect"] ?? nil) else {
        return nil
    }
    
    return SelectionActionRequest(
        actionId: actionID,
        actions: actions,
        selection: selection,
        editable: message?["editable"] as? Bool ?? false,
        clientRect: clientRect
    )
}

private func parseClientRect(_ value: Any?) -> CGRect? {
    guard let rect = value as? [String: Any] else {
        return nil
    }
    guard let left = PayloadValue.cgFloat(rect["left"]),
          let top = PayloadValue.cgFloat(rect["top"]),
          let right = PayloadValue.cgFloat(rect["right"]),
          let bottom = PayloadValue.cgFloat(rect["bottom"]) else {
        return nil
    }
    
    let width = max(0, right - left)
    let height = max(0, bottom - top)
    guard width > 0, height > 0 else {
        return nil
    }
    
    return CGRect(x: left, y: top, width: width, height: height)
}

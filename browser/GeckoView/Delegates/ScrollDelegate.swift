//
//  ScrollDelegate.swift
//  Reynard
//

import Foundation

public protocol ScrollDelegate: AnyObject {
    func onScrollChanged(session: GeckoSession, scrollX: Int, scrollY: Int)
}

public extension ScrollDelegate {
    func onScrollChanged(session: GeckoSession, scrollX: Int, scrollY: Int) {}
}

private enum ScrollEvent: String, CaseIterable {
    case changed = "GeckoView:ScrollChanged"
}

func newScrollHandler(_ session: GeckoSession) -> GeckoSessionHandler {
    GeckoSessionHandler(
        moduleName: "GeckoViewScroll",
        events: ScrollEvent.allCases.map(\.rawValue),
        session: session
    ) { @MainActor session, delegate, type, message in
        guard ScrollEvent(rawValue: type) == .changed else {
            throw GeckoHandlerError("unknown message \(type)")
        }
        let delegate = delegate as? ScrollDelegate
        delegate?.onScrollChanged(
            session: session,
            scrollX: PayloadValue.int(message?["scrollX"] ?? nil) ?? 0,
            scrollY: PayloadValue.int(message?["scrollY"] ?? nil) ?? 0
        )
        return nil
    }
}

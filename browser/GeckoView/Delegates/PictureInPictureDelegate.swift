//
//  PictureInPictureDelegate.swift
//  Reynard
//
//  Created by Minh Ton on 17/7/26.
//

import AVFoundation

public protocol PictureInPictureDelegate: AnyObject {
    func onSourceChanged(session: GeckoSession)
}

public extension PictureInPictureDelegate {
    func onSourceChanged(session: GeckoSession) {}
}

final class PictureInPictureHandler: GeckoSessionHandlerCommon {
    let moduleName: String? = nil
    let events = ["GeckoView:PictureInPicture:SourceChanged"]
    let enabled = true
    
    private weak var session: GeckoSession?
    weak var delegate: PictureInPictureDelegate?
    
    var displayLayer: AVSampleBufferDisplayLayer? {
        return autoreleasepool {
            session?.window?.pictureInPictureDisplayLayer()
        }
    }
    
    init(session: GeckoSession) {
        self.session = session
    }
    
    func handleMessage(type: String, message: [String: Any?]?, callback: EventCallback?) {
        guard events.contains(type) else {
            callback?.sendError(GeckoHandlerError("unknown message \(type)").value)
            return
        }
        guard let session else {
            callback?.sendError(GeckoHandlerError("session has been destroyed").value)
            return
        }
        delegate?.onSourceChanged(session: session)
        callback?.sendSuccess(nil)
    }
}

func newPictureInPictureHandler(_ session: GeckoSession) -> PictureInPictureHandler {
    return PictureInPictureHandler(session: session)
}

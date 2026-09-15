//
//  ContentDelegate.swift
//  Reynard
//
//  Created by Minh Ton on 22/2/26.
//

import Foundation
import UIKit

// MARK: - Content Models

public struct ContextElement {
    public enum ElementType {
        case none
        case image
        case video
        case audio
    }
    
    public let baseUri: String?
    public let linkUri: String?
    public let title: String?
    public let altText: String?
    public let type: ElementType
    public let srcUri: String?
    public let textContent: String?
    public let isMouseInput: Bool
}

public enum SlowScriptResponse {
    case halt
    case resume
}

// MARK: - External Response Models

public struct ExternalResponseHeader {
    public let name: String
    public let value: String
}

private enum ExternalResponseCommand: String {
    case cancel = "GeckoView:ExternalResponseCancel"
    case pause = "GeckoView:ExternalResponsePause"
    case resume = "GeckoView:ExternalResponseResume"
}

public struct ExternalResponseInfo {
    public let url: String
    public let localFilePath: String
    public let filename: String?
    public let mimeType: String?
    public let contentLength: Int64?
    public let headers: [ExternalResponseHeader]
    public let statusCode: Int
    private let commandHandler: (ExternalResponseCommand) -> Void
    
    init?(session: GeckoSession, payload: [String: Any?]?) {
        guard let url = payload?["url"] as? String,
              let localFilePath = payload?["localFilePath"] as? String else {
            return nil
        }
        
        self.url = url
        self.localFilePath = localFilePath
        self.filename = payload?["filename"] as? String
        self.mimeType = payload?["mimeType"] as? String
        self.contentLength = PayloadValue.int64(payload?["contentLength"])
        self.headers = (payload?["headers"] as? [[String: Any]])?.compactMap { header in
            guard let name = PayloadValue.string(header["name"]),
                  let value = PayloadValue.string(header["value"]) else {
                return nil
            }
            return ExternalResponseHeader(name: name, value: value)
        } ?? []
        self.statusCode = PayloadValue.int(payload?["statusCode"]) ?? 0
        self.commandHandler = { [weak session] command in
            DispatchQueue.main.async { [weak session] in
                session?.dispatcher.dispatch(
                    type: command.rawValue,
                    message: ["localFilePath": localFilePath]
                )
            }
        }
    }
    
    public func pause() {
        commandHandler(.pause)
    }
    
    public func resume() {
        commandHandler(.resume)
    }
    
    public func cancel() {
        commandHandler(.cancel)
    }
}

// MARK: - PDF Models

public struct SavePdfInfo {
    public let url: String
    public let filename: String?
    public let originalUrl: String?
}

// MARK: - Content Delegate

public protocol ContentDelegate {
    func onTitleChange(session: GeckoSession, title: String)
    func onPreviewImage(session: GeckoSession, previewImageUrl: String)
    func onFocusRequest(session: GeckoSession)
    func onCloseRequest(session: GeckoSession)
    func onFullScreen(session: GeckoSession, fullScreen: Bool)
    func onMetaViewportFitChange(session: GeckoSession, viewportFit: String)
    func onProductUrl(session: GeckoSession)
    func onContextMenu(session: GeckoSession, screenX: Int, screenY: Int, element: ContextElement)
    func onCrash(session: GeckoSession)
    func onKill(session: GeckoSession)
    func onFirstComposite(session: GeckoSession)
    func onFirstContentfulPaint(session: GeckoSession)
    func onPaintStatusReset(session: GeckoSession)
    func onPageBackgroundColorChange(session: GeckoSession, color: UIColor)
    func onWebAppManifest(session: GeckoSession, manifest: Any)
    func onSlowScript(session: GeckoSession, scriptFileName: String, completion: @escaping (SlowScriptResponse) -> Void)
    func onShowDynamicToolbar(session: GeckoSession)
    func onCookieBannerDetected(session: GeckoSession)
    func onCookieBannerHandled(session: GeckoSession)
    func onExternalResponse(session: GeckoSession, response: ExternalResponseInfo, completion: @escaping (Bool) -> Void)
    func onExternalResponseProgress(session: GeckoSession, localFilePath: String, bytesReceived: Int64) -> Bool
    func onExternalResponseComplete(session: GeckoSession, localFilePath: String, succeeded: Bool)
    func onSavePdf(session: GeckoSession, request: SavePdfInfo)
}

extension ContentDelegate {
    public func onTitleChange(session: GeckoSession, title: String) {}
    public func onPreviewImage(session: GeckoSession, previewImageUrl: String) {}
    public func onFocusRequest(session: GeckoSession) {}
    public func onCloseRequest(session: GeckoSession) {}
    public func onFullScreen(session: GeckoSession, fullScreen: Bool) {}
    public func onMetaViewportFitChange(session: GeckoSession, viewportFit: String) {}
    public func onProductUrl(session: GeckoSession) {}
    public func onContextMenu(session: GeckoSession, screenX: Int, screenY: Int, element: ContextElement) {}
    public func onCrash(session: GeckoSession) {}
    public func onKill(session: GeckoSession) {}
    public func onFirstComposite(session: GeckoSession) {}
    public func onFirstContentfulPaint(session: GeckoSession) {}
    public func onPaintStatusReset(session: GeckoSession) {}
    public func onPageBackgroundColorChange(session: GeckoSession, color: UIColor) {}
    public func onWebAppManifest(session: GeckoSession, manifest: Any) {}
    public func onSlowScript(session: GeckoSession, scriptFileName: String, completion: @escaping (SlowScriptResponse) -> Void) { completion(.halt) }
    public func onShowDynamicToolbar(session: GeckoSession) {}
    public func onCookieBannerDetected(session: GeckoSession) {}
    public func onCookieBannerHandled(session: GeckoSession) {}
    public func onExternalResponse(session: GeckoSession, response: ExternalResponseInfo, completion: @escaping (Bool) -> Void) { completion(false) }
    public func onExternalResponseProgress(session: GeckoSession, localFilePath: String, bytesReceived: Int64) -> Bool { false }
    public func onExternalResponseComplete(session: GeckoSession, localFilePath: String, succeeded: Bool) {}
    public func onSavePdf(session: GeckoSession, request: SavePdfInfo) {}
}

// MARK: - Content Events

enum ContentEvents: String, CaseIterable {
    case contentCrash = "GeckoView:ContentCrash"
    case contentKill = "GeckoView:ContentKill"
    case contextMenu = "GeckoView:ContextMenu"
    case domMetaViewportFit = "GeckoView:DOMMetaViewportFit"
    case pageTitleChanged = "GeckoView:PageTitleChanged"
    case domWindowClose = "GeckoView:DOMWindowClose"
    case externalResponse = "GeckoView:ExternalResponse"
    case externalResponseProgress = "GeckoView:ExternalResponseProgress"
    case externalResponseComplete = "GeckoView:ExternalResponseComplete"
    case focusRequest = "GeckoView:FocusRequest"
    case fullscreenEnter = "GeckoView:FullScreenEnter"
    case fullscreenExit = "GeckoView:FullScreenExit"
    case webAppManifest = "GeckoView:WebAppManifest"
    case firstContentfulPaint = "GeckoView:FirstContentfulPaint"
    case paintStatusReset = "GeckoView:PaintStatusReset"
    case backgroundColor = "GeckoView:BackgroundColor"
    case previewImage = "GeckoView:PreviewImage"
    case cookieBannerEventDetected = "GeckoView:CookieBannerEvent:Detected"
    case cookieBannerEventHandled = "GeckoView:CookieBannerEvent:Handled"
    case savePdf = "GeckoView:SavePdf"
    case onProductUrl = "GeckoView:OnProductUrl"
}

// MARK: - Content Handler

func newContentHandler(_ session: GeckoSession) -> GeckoSessionHandler {
    GeckoSessionHandler(
        moduleName: "GeckoViewContent",
        events: ContentEvents.allCases.map(\.rawValue),
        session: session
    ) {  session, delegate, type, message, completion in
        func parseStringDictionary(_ value: Any?) -> [String: String] {
            guard let dictionary = value as? [String: Any] else {
                return [:]
            }
            
            return dictionary.reduce(into: [:]) { result, entry in
                if let value = entry.value as? String {
                    result[entry.key] = value
                } else if let number = entry.value as? NSNumber {
                    result[entry.key] = number.stringValue
                }
            }
        }
        
        guard let event = ContentEvents(rawValue: type) else {
            completion(.failure(GeckoHandlerError("unknown message \(type)")))
            return
        }

        let delegate = delegate as? ContentDelegate
        switch event {
        case .contentCrash:
            delegate?.onCrash(session: session)
            completion(.success(nil))
            return
            
        case .contentKill:
            delegate?.onKill(session: session)
            completion(.success(nil))
            return
            
        case .contextMenu:
            func parseElementType(_ value: String) -> ContextElement.ElementType {
                switch value {
                case "HTMLImageElement":
                    return .image
                case "HTMLVideoElement":
                    return .video
                case "HTMLAudioElement":
                    return .audio
                default:
                    return .none
                }
            }
            
            let contextElement = ContextElement(
                baseUri: message?["baseUri"] as? String,
                linkUri: (message?["linkUri"] as? String) ?? (message?["uri"] as? String),
                title: message?["title"] as? String,
                altText: message?["alt"] as? String,
                type: parseElementType(message?["elementType"] as? String ?? ""),
                srcUri: message?["elementSrc"] as? String,
                textContent: message?["textContent"] as? String,
                isMouseInput: message?["isMouseInput"] as? Bool ?? false
            )
            
            delegate?.onContextMenu(
                session: session,
                screenX: message?["screenX"] as? Int ?? 0,
                screenY: message?["screenY"] as? Int ?? 0,
                element: contextElement
            )
            completion(.success(nil))
            return
            
        case .domMetaViewportFit:
            delegate?.onMetaViewportFitChange(
                session: session,
                viewportFit: message?["viewportfit"] as? String ?? ""
            )
            completion(.success(nil))
            return
            
        case .pageTitleChanged:
            delegate?.onTitleChange(session: session, title: message?["title"] as? String ?? "")
            completion(.success(nil))
            return
            
        case .domWindowClose:
            delegate?.onCloseRequest(session: session)
            completion(.success(nil))
            return
            
        case .externalResponse:
            guard let response = ExternalResponseInfo(session: session, payload: message) else {
                completion(.success(false))
                return
            }
            delegate?.onExternalResponse(session: session, response: response) { allowed in
                completion(.success(allowed))
            }
            return
            
        case .externalResponseProgress:
            guard let localFilePath = message?["localFilePath"] as? String else {
                completion(.success(false))
                return
            }
            completion(.success(
                delegate?.onExternalResponseProgress(
                    session: session,
                    localFilePath: localFilePath,
                    bytesReceived: PayloadValue.int64(message?["bytesReceived"]) ?? 0
                ) ?? false
            ))
            return
            
        case .externalResponseComplete:
            guard let localFilePath = message?["localFilePath"] as? String else {
                completion(.success(nil))
                return
            }
            delegate?.onExternalResponseComplete(
                session: session,
                localFilePath: localFilePath,
                succeeded: message?["succeeded"] as? Bool ?? false
            )
            completion(.success(nil))
            return
            
        case .focusRequest:
            delegate?.onFocusRequest(session: session)
            completion(.success(nil))
            return
            
        case .fullscreenEnter:
            delegate?.onFullScreen(session: session, fullScreen: true)
            completion(.success(nil))
            return
            
        case .fullscreenExit:
            delegate?.onFullScreen(session: session, fullScreen: false)
            completion(.success(nil))
            return
            
        case .webAppManifest:
            if let manifest = message?["manifest"] {
                delegate?.onWebAppManifest(session: session, manifest: manifest as Any)
            }
            completion(.success(nil))
            return
            
        case .firstContentfulPaint:
            delegate?.onFirstContentfulPaint(session: session)
            completion(.success(nil))
            return
            
        case .paintStatusReset:
            delegate?.onPaintStatusReset(session: session)
            completion(.success(nil))
            return
            
        case .backgroundColor:
            guard let red = PayloadValue.int(message?["red"]),
                  let green = PayloadValue.int(message?["green"]),
                  let blue = PayloadValue.int(message?["blue"]),
                  let alpha = PayloadValue.int(message?["alpha"]),
                  (0...255).contains(red),
                  (0...255).contains(green),
                  (0...255).contains(blue),
                  (0...255).contains(alpha) else {
                completion(.success(nil))
                return
            }
            
            let color = UIColor(
                red: CGFloat(red) / 255,
                green: CGFloat(green) / 255,
                blue: CGFloat(blue) / 255,
                alpha: CGFloat(alpha) / 255
            )
            delegate?.onPageBackgroundColorChange(session: session, color: color)
            completion(.success(nil))
            return
            
        case .previewImage:
            delegate?.onPreviewImage(
                session: session,
                previewImageUrl: message?["previewImageUrl"] as? String ?? ""
            )
            completion(.success(nil))
            return
            
        case .cookieBannerEventDetected:
            delegate?.onCookieBannerDetected(session: session)
            completion(.success(nil))
            return
            
        case .cookieBannerEventHandled:
            delegate?.onCookieBannerHandled(session: session)
            completion(.success(nil))
            return
            
        case .savePdf:
            delegate?.onSavePdf(
                session: session,
                request: SavePdfInfo(
                    url: message?["url"] as? String ?? "",
                    filename: message?["filename"] as? String,
                    originalUrl: message?["originalUrl"] as? String
                )
            )
            completion(.success(nil))
            return
            
        case .onProductUrl:
            delegate?.onProductUrl(session: session)
            completion(.success(nil))
            return
        }
    }
}

// MARK: - Process Hang Handler

enum ProcessHangEvents: String, CaseIterable {
    case hangReport = "GeckoView:HangReport"
}

func newProcessHangHandler(_ session: GeckoSession) -> GeckoSessionHandler {
    GeckoSessionHandler(
        moduleName: "GeckoViewProcessHangMonitor",
        events: ProcessHangEvents.allCases.map(\.rawValue),
        session: session
    ) {  session, delegate, type, message, completion in
        guard let event = ProcessHangEvents(rawValue: type) else {
            completion(.failure(GeckoHandlerError("unknown message \(type)")))
            return
        }

        let delegate = delegate as? ContentDelegate
        switch event {
        case .hangReport:
            let reportID = PayloadValue.int(message?["hangId"]) ?? 0

            guard let delegate else {
                session.dispatcher.dispatch(
                    type: "GeckoView:HangReportStop",
                    message: ["hangId": reportID]
                )
                completion(.success(nil))
                return
            }

            delegate.onSlowScript(
                session: session,
                scriptFileName: message?["scriptFileName"] as? String ?? ""
            ) { response in
                switch response {
                case .resume:
                    session.dispatcher.dispatch(
                        type: "GeckoView:HangReportWait",
                        message: ["hangId": reportID]
                    )
                default:
                    session.dispatcher.dispatch(
                        type: "GeckoView:HangReportStop",
                        message: ["hangId": reportID]
                    )
                }
                completion(.success(nil))
            }
        }
    }
}

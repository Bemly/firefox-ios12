//
//  OverlayContentView.swift
//  Reynard
//
//  Created by Minh Ton on 10/6/26.
//

import UIKit

final class OverlayContentView: UIView {
    private enum UX {
        static let presentationAnimationDuration: TimeInterval = 0.12
    }
    
    enum Page: Hashable {
        case homepage
        case search
    }
    
    enum PresentationState: Equatable {
        case hidden
        case visible(Page)
    }
    
    private(set) var presentation: PresentationState = .hidden
    private var pageControllers: [Page: UIViewController] = [:]
    
    private let homepageView = UIView()
    private let searchSuggestionView = UIView()
    
    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureAppearance()
        configureHierarchy()
        applyPresentation()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Configuration
    
    private func configureAppearance() {
        backgroundColor = .appSystemBackground
    }
    
    private func configureHierarchy() {
        [homepageView, searchSuggestionView].forEach { contentView in
            contentView.translatesAutoresizingMaskIntoConstraints = false
            contentView.backgroundColor = .clear
            addSubview(contentView)
        }
    }
    
    func configureContentLayout(
        topAnchor: NSLayoutYAxisAnchor,
        bottomAnchor: NSLayoutYAxisAnchor
    ) {
        [homepageView, searchSuggestionView].forEach { contentView in
            NSLayoutConstraint.activate([
                contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
                contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
        }
        NSLayoutConstraint.activate([
            homepageView.topAnchor.constraint(equalTo: self.topAnchor),
            homepageView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            searchSuggestionView.topAnchor.constraint(equalTo: topAnchor),
            searchSuggestionView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
    
    // MARK: - State
    
    func setPresentation(
        _ presentation: PresentationState,
        animated: Bool,
        completion: (() -> Void)? = nil
    ) {
        guard self.presentation != presentation else {
            completion?()
            return
        }
        
        let previousPresentation = self.presentation
        self.presentation = presentation
        applyPresentation(
            previousPresentation: previousPresentation,
            animated: animated,
            completion: completion
        )
    }
    
    private func applyPresentation() {
        applyPresentation(previousPresentation: nil, animated: false, completion: nil)
    }
    
    private func applyPresentation(
        previousPresentation: PresentationState?,
        animated: Bool,
        completion: (() -> Void)?
    ) {
        layer.removeAllAnimations()
        homepageView.isHidden = presentation != .visible(.homepage)
        searchSuggestionView.isHidden = presentation != .visible(.search)
        
        if isChangingVisiblePage(from: previousPresentation) {
            isHidden = false
            alpha = 1
            completion?()
            return
        }
        
        switch presentation {
        case .hidden:
            let finish = { [weak self] in
                guard let self else { return }
                self.isHidden = true
                self.removeController(for: self.visiblePage(from: previousPresentation))
                completion?()
            }
            
            guard animated else {
                alpha = 0
                finish()
                return
            }
            
            UIView.animate(withDuration: UX.presentationAnimationDuration, animations: {
                self.alpha = 0
            }) { _ in
                finish()
            }
        case .visible:
            isHidden = false
            let animations = {
                self.alpha = 1
            }
            
            guard animated else {
                animations()
                completion?()
                return
            }
            
            alpha = 0
            UIView.animate(withDuration: UX.presentationAnimationDuration, animations: animations) { _ in
                completion?()
            }
        }
    }
    
    private func visiblePage(from presentation: PresentationState?) -> Page? {
        guard case let .visible(page) = presentation else {
            return nil
        }
        
        return page
    }
    
    private func isChangingVisiblePage(from previousPresentation: PresentationState?) -> Bool {
        guard let previousPage = visiblePage(from: previousPresentation),
              case let .visible(page) = presentation else {
            return false
        }
        
        return previousPage != page
    }
    
    // MARK: - Hosted Content
    
    func setController(_ viewController: UIViewController, for page: Page, in parentViewController: UIViewController) {
        let containerView = containerView(for: page)
        if pageControllers[page] === viewController,
           viewController.view.isDescendant(of: containerView) {
            return
        }
        
        removeController(for: page)
        detachIfNeeded(viewController)
        
        parentViewController.addChild(viewController)
        viewController.view.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(viewController.view)
        NSLayoutConstraint.activate([
            viewController.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            viewController.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            viewController.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            viewController.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])
        viewController.didMove(toParent: parentViewController)
        pageControllers[page] = viewController
    }
    
    func removeController(for page: Page) {
        removeController(for: Optional(page))
    }
    
    private func removeController(for page: Page?) {
        guard let page else {
            return
        }
        
        guard let viewController = pageControllers.removeValue(forKey: page) else {
            return
        }
        
        guard viewController.view.isDescendant(of: containerView(for: page)) else {
            return
        }
        
        viewController.willMove(toParent: nil)
        viewController.view.removeFromSuperview()
        viewController.removeFromParent()
    }
    
    private func detachIfNeeded(_ viewController: UIViewController) {
        guard viewController.parent != nil else {
            return
        }
        
        viewController.willMove(toParent: nil)
        viewController.view.removeFromSuperview()
        viewController.removeFromParent()
    }
    
    private func containerView(for page: Page) -> UIView {
        switch page {
        case .homepage:
            return homepageView
        case .search:
            return searchSuggestionView
        }
    }
}

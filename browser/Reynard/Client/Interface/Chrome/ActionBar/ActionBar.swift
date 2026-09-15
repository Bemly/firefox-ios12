//
//  ActionBar.swift
//  Reynard
//
//  Created by Minh Ton on 28/6/26.
//

import UIKit

enum ActionBarStyle {
    case compact
    case standard
    
    var height: CGFloat {
        switch self {
        case .compact:
            return 41
        case .standard:
            return 62
        }
    }
}

final class ActionBar: UIView {
    private enum UX {
        static let closeButtonSize: CGFloat = 28
        static let closeButtonCornerRadius: CGFloat = 14
        static let horizontalInset: CGFloat = 13
        static let closeSymbolPointSize: CGFloat = 10
        static let shadowOpacity: Float = 0.14
        static let shadowRadius: CGFloat = 8
        static let shadowOffset = CGSize(width: 0, height: 3)
        static let borderWidth: CGFloat = 0.5
    }
    
    enum Item: Equatable {
        case findInPage
        case pageZoom
        case keyboardDismissal
        
        var style: ActionBarStyle {
            return self == .keyboardDismissal ? .compact : .standard
        }
    }
    
    var onFindInPage: ((_ query: String?, _ backwards: Bool) async -> (current: Int, total: Int)?)? {
        get { return findInPageActionBar.onFind }
        set { findInPageActionBar.onFind = newValue }
    }
    
    var onClearFindInPage: (() -> Void)? {
        get { return findInPageActionBar.onClear }
        set { findInPageActionBar.onClear = newValue }
    }
    
    var onPageZoomOut: (() -> Void)? {
        get { return pageZoomActionBar.onZoomOut }
        set { pageZoomActionBar.onZoomOut = newValue }
    }
    
    var onPageZoomIn: (() -> Void)? {
        get { return pageZoomActionBar.onZoomIn }
        set { pageZoomActionBar.onZoomIn = newValue }
    }
    
    var onPageZoomReset: (() -> Void)? {
        get { return pageZoomActionBar.onReset }
        set { pageZoomActionBar.onReset = newValue }
    }
    
    var onClose: (() -> Void)?
    var onKeyboardDismissal: (() -> Void)?
    
    private(set) var item: Item?
    
    var isShowingFindInPage: Bool {
        return item == .findInPage && !isHidden
    }
    
    var isShowingKeyboardDismissal: Bool {
        return item == .keyboardDismissal && !isHidden && alpha > 0
    }
    
    private let findInPageActionBar = FindInPageActionBar()
    private let pageZoomActionBar = PageZoomActionBar()
    private let keyboardDismissalActionBar = KeyboardDismissalActionBar()
    private var hasPreparedFindInPageDismissal = false
    private var heightConstraint: NSLayoutConstraint!
    
    private let closeShadowView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.layer.cornerCurve = .continuous
        view.layer.cornerRadius = UX.closeButtonCornerRadius
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = UX.shadowOpacity
        view.layer.shadowRadius = UX.shadowRadius
        view.layer.shadowOffset = UX.shadowOffset
        return view
    }()
    
    private let closeBackground: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentView.backgroundColor = UIColor { traitCollection in
            let backgroundColor: UIColor = traitCollection.userInterfaceStyle == .dark
            ? .tertiarySystemBackground.withAlphaComponent(0.8)
            : .systemBackground.withAlphaComponent(0.8)
            return backgroundColor.resolvedColor(with: traitCollection)
        }
        view.layer.cornerCurve = .continuous
        view.layer.cornerRadius = UX.closeButtonCornerRadius
        view.layer.borderWidth = UX.borderWidth
        view.layer.borderColor = UIColor.separator.withAlphaComponent(0.2).cgColor
        view.clipsToBounds = true
        return view
    }()
    
    private let topBorderView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.separator.withAlphaComponent(0.2)
        return view
    }()
    
    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        let configuration = UIImage.SymbolConfiguration(pointSize: UX.closeSymbolPointSize, weight: .regular)
        button.setImage(UIImage(named: "reynard.xmark", in: .main, with: configuration), for: .normal)
        button.tintColor = .secondaryLabel
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureAppearance()
        configureHierarchy()
        configureConstraints()
        setItem(nil)
        
        findInPageActionBar.onDismiss = { [weak self] in
            self?.onClose?()
        }
        keyboardDismissalActionBar.onDone = { [weak self] in
            self?.onKeyboardDismissal?()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        closeShadowView.layer.shadowPath = UIBezierPath(
            roundedRect: closeShadowView.bounds,
            cornerRadius: UX.closeButtonCornerRadius
        ).cgPath
    }
    
    // MARK: - Presentation
    
    func setItem(_ item: Item?) {
        if item != .findInPage {
            prepareForDismissal()
        }
        if item == .findInPage, self.item != .findInPage {
            hasPreparedFindInPageDismissal = false
            findInPageActionBar.prepareForPresentation()
        }
        self.item = item
        heightConstraint.constant = item?.style.height ?? ActionBarStyle.standard.height
        isHidden = item == nil
        findInPageActionBar.isHidden = item != .findInPage
        pageZoomActionBar.isHidden = item != .pageZoom
        keyboardDismissalActionBar.isHidden = item != .keyboardDismissal
        closeShadowView.isHidden = item == .keyboardDismissal
    }
    
    func prepareForDismissal() {
        guard item == .findInPage, !hasPreparedFindInPageDismissal else {
            return
        }
        
        hasPreparedFindInPageDismissal = true
        findInPageActionBar.prepareForDismissal()
    }
    
    func setPageZoomLevel(_ level: Int) {
        pageZoomActionBar.setZoomLevel(level)
    }
    
    func nextPageZoomLevel() -> Int {
        return pageZoomActionBar.nextZoomLevel()
    }
    
    func previousPageZoomLevel() -> Int {
        return pageZoomActionBar.previousZoomLevel()
    }
    
    // MARK: - Actions
    
    @objc private func closeTapped() {
        onClose?()
    }
    
    // MARK: - View Setup
    
    private func configureAppearance() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
    }
    
    private func configureHierarchy() {
        addSubview(findInPageActionBar)
        addSubview(pageZoomActionBar)
        addSubview(keyboardDismissalActionBar)
        addSubview(closeShadowView)
        closeShadowView.addSubview(closeBackground)
        closeShadowView.addSubview(closeButton)
        addSubview(topBorderView)
    }
    
    private func configureConstraints() {
        heightConstraint = heightAnchor.constraint(equalToConstant: ActionBarStyle.standard.height)
        NSLayoutConstraint.activate([
            heightConstraint,
            
            pageZoomActionBar.topAnchor.constraint(equalTo: topAnchor),
            pageZoomActionBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            pageZoomActionBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            pageZoomActionBar.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            findInPageActionBar.topAnchor.constraint(equalTo: topAnchor),
            findInPageActionBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            findInPageActionBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            findInPageActionBar.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            keyboardDismissalActionBar.topAnchor.constraint(equalTo: topAnchor),
            keyboardDismissalActionBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            keyboardDismissalActionBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            keyboardDismissalActionBar.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            closeShadowView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -UX.horizontalInset),
            closeShadowView.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeShadowView.widthAnchor.constraint(equalToConstant: UX.closeButtonSize),
            closeShadowView.heightAnchor.constraint(equalToConstant: UX.closeButtonSize),
            
            closeBackground.topAnchor.constraint(equalTo: closeShadowView.topAnchor),
            closeBackground.leadingAnchor.constraint(equalTo: closeShadowView.leadingAnchor),
            closeBackground.trailingAnchor.constraint(equalTo: closeShadowView.trailingAnchor),
            closeBackground.bottomAnchor.constraint(equalTo: closeShadowView.bottomAnchor),
            
            closeButton.topAnchor.constraint(equalTo: closeShadowView.topAnchor),
            closeButton.leadingAnchor.constraint(equalTo: closeShadowView.leadingAnchor),
            closeButton.trailingAnchor.constraint(equalTo: closeShadowView.trailingAnchor),
            closeButton.bottomAnchor.constraint(equalTo: closeShadowView.bottomAnchor),
            
            topBorderView.topAnchor.constraint(equalTo: topAnchor),
            topBorderView.leadingAnchor.constraint(equalTo: leadingAnchor),
            topBorderView.trailingAnchor.constraint(equalTo: trailingAnchor),
            topBorderView.heightAnchor.constraint(equalToConstant: UX.borderWidth),
        ])
    }
}

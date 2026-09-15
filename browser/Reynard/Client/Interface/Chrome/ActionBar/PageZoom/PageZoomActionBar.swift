//
//  PageZoomActionBar.swift
//  Reynard
//
//  Created by Minh Ton on 28/6/26.
//

import UIKit

final class PageZoomActionBar: UIView {
    private enum UX {
        static let controlsHeight: CGFloat = 38
        static let controlsWidth: CGFloat = 184
        static let controlButtonWidth: CGFloat = 55
        static let separatorWidth: CGFloat = 1
        static let controlsCornerRadius: CGFloat = 19
        static let percentFontSize: CGFloat = 16
        static let controlSymbolPointSize: CGFloat = 14
        static let animationDuration: TimeInterval = 0.12
        static let backgroundAlpha: CGFloat = 0.34
        static let disabledAlpha: CGFloat = 0.32
        static let shadowOpacity: Float = 0.14
        static let shadowRadius: CGFloat = 8
        static let shadowOffset = CGSize(width: 0, height: 3)
        static let borderWidth: CGFloat = 0.5
    }
    
    static let zoomLevels = PageZoomLevels.all
    
    var onZoomOut: (() -> Void)?
    var onZoomIn: (() -> Void)?
    var onReset: (() -> Void)?
    
    private(set) var zoomLevel = Prefs.BrowsingSettings.defaultPageZoomLevel
    
    private let backgroundView: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .appChromeMaterial))
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentView.backgroundColor = UIColor.appSystemBackground.withAlphaComponent(UX.backgroundAlpha)
        return view
    }()
    
    private let controlsShadowView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.layer.applyContinuousCornerCurve()
        view.layer.cornerRadius = UX.controlsCornerRadius
        view.layer.shadowOpacity = UX.shadowOpacity
        view.layer.shadowRadius = UX.shadowRadius
        view.layer.shadowOffset = UX.shadowOffset
        view.layer.shadowColor = UIColor.black.cgColor
        return view
    }()
    
    private let controlsBackground: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .appMaterial))
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentView.backgroundColor = UIColor { traitCollection in
            let backgroundColor: UIColor = traitCollection.userInterfaceStyle == .dark
            ? .appTertiarySystemBackground.withAlphaComponent(0.8)
            : .appSystemBackground.withAlphaComponent(0.8)
            return backgroundColor.resolvedColor(with: traitCollection)
        }
        view.layer.applyContinuousCornerCurve()
        view.layer.cornerRadius = UX.controlsCornerRadius
        view.layer.borderWidth = UX.borderWidth
        view.layer.borderColor = UIColor.appSeparator.withAlphaComponent(0.2).cgColor
        view.clipsToBounds = true
        return view
    }()
    
    private lazy var zoomOutButton = makeControlButton(named: "reynard.minus", action: #selector(zoomOutTapped))
    private lazy var zoomInButton = makeControlButton(named: "reynard.plus", action: #selector(zoomInTapped))
    
    private lazy var resetButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.titleLabel?.font = UIFont.systemFont(ofSize: UX.percentFontSize, weight: .regular)
        button.setTitleColor(.appSecondaryLabel, for: .normal)
        button.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)
        return button
    }()
    
    private let leadingSeparator = PageZoomActionBar.makeSeparator()
    private let trailingSeparator = PageZoomActionBar.makeSeparator()
    
    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureAppearance()
        configureHierarchy()
        configureConstraints()
        setZoomLevel(zoomLevel)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        controlsShadowView.layer.shadowPath = UIBezierPath(
            roundedRect: controlsShadowView.bounds,
            cornerRadius: UX.controlsCornerRadius
        ).cgPath
    }
    
    // MARK: - Updates
    
    func setZoomLevel(_ level: Int) {
        zoomLevel = PageZoomActionBar.zoomLevels.contains(level) ? level : Prefs.BrowsingSettings.defaultPageZoomLevel
        resetButton.setTitle(PageZoomLevels.displayText(for: zoomLevel), for: .normal)
        zoomOutButton.isEnabled = zoomLevel > PageZoomActionBar.zoomLevels.first!
        zoomInButton.isEnabled = zoomLevel < PageZoomActionBar.zoomLevels.last!
        zoomOutButton.alpha = zoomOutButton.isEnabled ? 1 : UX.disabledAlpha
        zoomInButton.alpha = zoomInButton.isEnabled ? 1 : UX.disabledAlpha
    }
    
    func nextZoomLevel() -> Int {
        guard let index = PageZoomActionBar.zoomLevels.firstIndex(of: zoomLevel) else {
            return Prefs.BrowsingSettings.defaultPageZoomLevel
        }
        return PageZoomActionBar.zoomLevels[min(index + 1, PageZoomActionBar.zoomLevels.count - 1)]
    }
    
    func previousZoomLevel() -> Int {
        guard let index = PageZoomActionBar.zoomLevels.firstIndex(of: zoomLevel) else {
            return Prefs.BrowsingSettings.defaultPageZoomLevel
        }
        return PageZoomActionBar.zoomLevels[max(index - 1, 0)]
    }
    
    // MARK: - Actions
    
    @objc private func zoomOutTapped() {
        onZoomOut?()
    }
    
    @objc private func zoomInTapped() {
        onZoomIn?()
    }
    
    @objc private func resetTapped() {
        onReset?()
    }
    
    // MARK: - View Setup
    
    private func configureAppearance() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
    }
    
    private func configureHierarchy() {
        addSubview(backgroundView)
        addSubview(controlsShadowView)
        controlsShadowView.addSubview(controlsBackground)
        [zoomOutButton, leadingSeparator, resetButton, trailingSeparator, zoomInButton].forEach {
            controlsBackground.contentView.addSubview($0)
        }
    }
    
    private func configureConstraints() {
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            controlsShadowView.centerXAnchor.constraint(equalTo: centerXAnchor),
            controlsShadowView.centerYAnchor.constraint(equalTo: centerYAnchor),
            controlsShadowView.widthAnchor.constraint(equalToConstant: UX.controlsWidth),
            controlsShadowView.heightAnchor.constraint(equalToConstant: UX.controlsHeight),
            
            controlsBackground.topAnchor.constraint(equalTo: controlsShadowView.topAnchor),
            controlsBackground.leadingAnchor.constraint(equalTo: controlsShadowView.leadingAnchor),
            controlsBackground.trailingAnchor.constraint(equalTo: controlsShadowView.trailingAnchor),
            controlsBackground.bottomAnchor.constraint(equalTo: controlsShadowView.bottomAnchor),
            
            zoomOutButton.leadingAnchor.constraint(equalTo: controlsBackground.contentView.leadingAnchor),
            zoomOutButton.topAnchor.constraint(equalTo: controlsBackground.contentView.topAnchor),
            zoomOutButton.bottomAnchor.constraint(equalTo: controlsBackground.contentView.bottomAnchor),
            zoomOutButton.widthAnchor.constraint(equalToConstant: UX.controlButtonWidth),
            
            leadingSeparator.leadingAnchor.constraint(equalTo: zoomOutButton.trailingAnchor),
            leadingSeparator.centerYAnchor.constraint(equalTo: controlsBackground.contentView.centerYAnchor),
            leadingSeparator.widthAnchor.constraint(equalToConstant: UX.separatorWidth),
            leadingSeparator.heightAnchor.constraint(equalTo: controlsBackground.contentView.heightAnchor, multiplier: 0.42),
            
            resetButton.leadingAnchor.constraint(equalTo: leadingSeparator.trailingAnchor),
            resetButton.topAnchor.constraint(equalTo: controlsBackground.contentView.topAnchor),
            resetButton.bottomAnchor.constraint(equalTo: controlsBackground.contentView.bottomAnchor),
            
            trailingSeparator.leadingAnchor.constraint(equalTo: resetButton.trailingAnchor),
            trailingSeparator.centerYAnchor.constraint(equalTo: controlsBackground.contentView.centerYAnchor),
            trailingSeparator.widthAnchor.constraint(equalToConstant: UX.separatorWidth),
            trailingSeparator.heightAnchor.constraint(equalTo: controlsBackground.contentView.heightAnchor, multiplier: 0.42),
            
            zoomInButton.leadingAnchor.constraint(equalTo: trailingSeparator.trailingAnchor),
            zoomInButton.trailingAnchor.constraint(equalTo: controlsBackground.contentView.trailingAnchor),
            zoomInButton.topAnchor.constraint(equalTo: controlsBackground.contentView.topAnchor),
            zoomInButton.bottomAnchor.constraint(equalTo: controlsBackground.contentView.bottomAnchor),
            zoomInButton.widthAnchor.constraint(equalToConstant: UX.controlButtonWidth),
            
        ])
    }
    
    private func makeControlButton(named: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 13.0, *) {
            let configuration = UIImage.SymbolConfiguration(pointSize: UX.controlSymbolPointSize, weight: .regular)
            button.setImage(UIImage(named: named, in: .main, with: configuration), for: .normal)
        } else {
            button.setImage(UIImage(named: named, in: .main, compatibleWith: nil), for: .normal)
        }
        button.tintColor = .appLabel
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
    
    private static func makeSeparator() -> UIView {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .appSeparator
        return view
    }
}

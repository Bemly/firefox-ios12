//
//  FindInPageActionBar.swift
//  Reynard
//
//  Created by Minh Ton on 12/8/26.
//

import UIKit

final class FindInPageActionBar: UIView, UITextFieldDelegate {
    private enum UX {
        static let contentLeadingInset: CGFloat = 12
        static let contentMaximumWidth: CGFloat = 650
        static let searchBarToControlsSpacing: CGFloat = 12
        static let controlsHeight: CGFloat = 38
        static let searchContentInset: CGFloat = 12
        static let resultLabelWidth: CGFloat = 52
        static let resultLabelSpacing: CGFloat = 10
        static let controlsWidth: CGFloat = controlButtonWidth * 2 + separatorWidth
        static let controlButtonWidth: CGFloat = 55
        static let separatorWidth: CGFloat = 1
        static let controlsCornerRadius: CGFloat = 19
        static let controlSymbolPointSize: CGFloat = 14
        static let contentTrailingInset: CGFloat = 53
        static let backgroundAlpha: CGFloat = 0.34
        static let disabledAlpha: CGFloat = 0.32
        static let shadowOpacity: Float = 0.14
        static let shadowRadius: CGFloat = 8
        static let shadowOffset = CGSize(width: 0, height: 3)
        static let borderWidth: CGFloat = 0.5
    }
    
    var onFind: ((_ query: String?, _ backwards: Bool) async -> (current: Int, total: Int)?)?
    var onClear: (() -> Void)?
    var onDismiss: (() -> Void)?
    
    private let backgroundView: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentView.backgroundColor = UIColor.systemBackground.withAlphaComponent(UX.backgroundAlpha)
        return view
    }()
    
    private let searchContentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let searchField: FindInPageTextField = {
        let field = FindInPageTextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.borderStyle = .none
        field.placeholder = NSLocalizedString("Find", comment: "Find in page search placeholder")
        field.textColor = .label
        field.font = UIFont.systemFont(ofSize: 17)
        field.clearButtonMode = .never
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.returnKeyType = .search
        return field
    }()
    
    private let resultLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .right
        label.lineBreakMode = .byClipping
        label.isHidden = true
        return label
    }()
    
    private let searchBarShadowView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.layer.cornerCurve = .continuous
        view.layer.cornerRadius = UX.controlsCornerRadius
        view.layer.shadowOpacity = UX.shadowOpacity
        view.layer.shadowRadius = UX.shadowRadius
        view.layer.shadowOffset = UX.shadowOffset
        view.layer.shadowColor = UIColor.black.cgColor
        return view
    }()
    
    private let searchBarBackground: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentView.backgroundColor = UIColor { traitCollection in
            let backgroundColor: UIColor = traitCollection.userInterfaceStyle == .dark
            ? .tertiarySystemBackground.withAlphaComponent(0.8)
            : .systemBackground.withAlphaComponent(0.8)
            return backgroundColor.resolvedColor(with: traitCollection)
        }
        view.layer.cornerCurve = .continuous
        view.layer.cornerRadius = UX.controlsCornerRadius
        view.layer.borderWidth = UX.borderWidth
        view.layer.borderColor = UIColor.separator.withAlphaComponent(0.2).cgColor
        view.clipsToBounds = true
        return view
    }()
    
    private let controlsShadowView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.layer.cornerCurve = .continuous
        view.layer.cornerRadius = UX.controlsCornerRadius
        view.layer.shadowOpacity = UX.shadowOpacity
        view.layer.shadowRadius = UX.shadowRadius
        view.layer.shadowOffset = UX.shadowOffset
        view.layer.shadowColor = UIColor.black.cgColor
        return view
    }()
    
    private let controlsBackground: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentView.backgroundColor = UIColor { traitCollection in
            let backgroundColor: UIColor = traitCollection.userInterfaceStyle == .dark
            ? .tertiarySystemBackground.withAlphaComponent(0.8)
            : .systemBackground.withAlphaComponent(0.8)
            return backgroundColor.resolvedColor(with: traitCollection)
        }
        view.layer.cornerCurve = .continuous
        view.layer.cornerRadius = UX.controlsCornerRadius
        view.layer.borderWidth = UX.borderWidth
        view.layer.borderColor = UIColor.separator.withAlphaComponent(0.2).cgColor
        view.clipsToBounds = true
        return view
    }()
    
    private lazy var previousMatchButton = makeControlButton(
        imageName: "reynard.chevron.up",
        action: #selector(previousMatchTapped)
    )
    
    private lazy var nextMatchButton = makeControlButton(
        imageName: "reynard.chevron.down",
        action: #selector(nextMatchTapped)
    )
    
    private let separator: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .separator
        return view
    }()
    
    private var requestID = 0
    private var searchContentViewCenterConstraint: NSLayoutConstraint!
    private var searchContentViewLeadingConstraint: NSLayoutConstraint!
    private var searchContentViewTrailingConstraint: NSLayoutConstraint!
    
    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureAppearance()
        configureHierarchy()
        configureConstraints()
        searchField.delegate = self
        searchField.onDismiss = { [weak self] in
            self?.onDismiss?()
        }
        searchField.addTarget(self, action: #selector(searchTextChanged), for: .editingChanged)
        updateNavigationButtons()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateSearchContentLayout()
        [searchBarShadowView, controlsShadowView].forEach { view in
            view.layer.shadowPath = UIBezierPath(
                roundedRect: view.bounds,
                cornerRadius: UX.controlsCornerRadius
            ).cgPath
        }
    }
    
    // MARK: - Presentation
    
    func prepareForPresentation() {
        requestID += 1
        onClear?()
        searchField.text = nil
        setResultText(nil)
        updateNavigationButtons()
        DispatchQueue.main.async { [weak self] in
            self?.searchField.becomeFirstResponder()
        }
    }
    
    func prepareForDismissal() {
        requestID += 1
        onClear?()
        searchField.resignFirstResponder()
        searchField.text = nil
        setResultText(nil)
        updateNavigationButtons()
    }
    
    private func setResult(current: Int, total: Int) {
        guard !(searchField.text ?? "").isEmpty else {
            setResultText(nil)
            return
        }
        
        let currentText = max(current, 0)
        let totalText = total >= 0 ? String(total) : "?"
        setResultText("\(currentText)/\(totalText)")
    }
    
    // MARK: - UITextFieldDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        nextMatchTapped()
        return false
    }
    
    // MARK: - Actions
    
    @objc private func searchTextChanged() {
        let query = searchField.text ?? ""
        setResultText(query.isEmpty ? nil : "0/0")
        updateNavigationButtons()
        guard !query.isEmpty else {
            requestID += 1
            onClear?()
            return
        }
        
        find(query: query, backwards: false)
    }
    
    @objc private func previousMatchTapped() {
        find(query: nil, backwards: true)
    }
    
    @objc private func nextMatchTapped() {
        find(query: nil, backwards: false)
    }
    
    private func find(query: String?, backwards: Bool) {
        guard let onFind else {
            return
        }
        
        requestID += 1
        let currentRequestID = requestID
        Task { @MainActor [weak self] in
            let result = await onFind(query, backwards)
            guard let self, self.requestID == currentRequestID else {
                return
            }
            
            self.setResult(
                current: result?.current ?? 0,
                total: result?.total ?? 0
            )
        }
    }
    
    // MARK: - View Setup
    
    private func configureAppearance() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
    }
    
    private func configureHierarchy() {
        addSubview(backgroundView)
        addSubview(searchContentView)
        searchContentView.addSubview(searchBarShadowView)
        searchBarShadowView.addSubview(searchBarBackground)
        searchBarBackground.contentView.addSubview(searchField)
        searchBarBackground.contentView.addSubview(resultLabel)
        searchContentView.addSubview(controlsShadowView)
        controlsShadowView.addSubview(controlsBackground)
        [previousMatchButton, separator, nextMatchButton].forEach {
            controlsBackground.contentView.addSubview($0)
        }
    }
    
    private func configureConstraints() {
        let preferredContentWidth = searchContentView.widthAnchor.constraint(
            equalToConstant: UX.contentMaximumWidth
        )
        preferredContentWidth.priority = .defaultHigh
        searchContentViewCenterConstraint = searchContentView.centerXAnchor.constraint(equalTo: centerXAnchor)
        searchContentViewLeadingConstraint = searchContentView.leadingAnchor.constraint(
            equalTo: leadingAnchor,
            constant: UX.contentLeadingInset
        )
        searchContentViewTrailingConstraint = searchContentView.trailingAnchor.constraint(
            equalTo: trailingAnchor,
            constant: -UX.contentTrailingInset
        )
        
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            searchContentViewCenterConstraint,
            searchContentView.centerYAnchor.constraint(equalTo: centerYAnchor),
            searchContentView.leadingAnchor.constraint(
                greaterThanOrEqualTo: leadingAnchor,
                constant: UX.contentLeadingInset
            ),
            searchContentView.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor,
                constant: -UX.contentTrailingInset
            ),
            searchContentView.widthAnchor.constraint(lessThanOrEqualToConstant: UX.contentMaximumWidth),
            preferredContentWidth,
            searchContentView.heightAnchor.constraint(equalToConstant: UX.controlsHeight),
            
            searchBarShadowView.leadingAnchor.constraint(equalTo: searchContentView.leadingAnchor),
            searchBarShadowView.centerYAnchor.constraint(equalTo: searchContentView.centerYAnchor),
            searchBarShadowView.heightAnchor.constraint(equalToConstant: UX.controlsHeight),
            searchBarShadowView.trailingAnchor.constraint(
                equalTo: controlsShadowView.leadingAnchor,
                constant: -UX.searchBarToControlsSpacing
            ),
            
            searchBarBackground.topAnchor.constraint(equalTo: searchBarShadowView.topAnchor),
            searchBarBackground.leadingAnchor.constraint(equalTo: searchBarShadowView.leadingAnchor),
            searchBarBackground.trailingAnchor.constraint(equalTo: searchBarShadowView.trailingAnchor),
            searchBarBackground.bottomAnchor.constraint(equalTo: searchBarShadowView.bottomAnchor),
            
            searchField.topAnchor.constraint(equalTo: searchBarBackground.contentView.topAnchor),
            searchField.leadingAnchor.constraint(
                equalTo: searchBarBackground.contentView.leadingAnchor,
                constant: UX.searchContentInset
            ),
            searchField.trailingAnchor.constraint(equalTo: resultLabel.leadingAnchor, constant: -UX.resultLabelSpacing),
            searchField.bottomAnchor.constraint(equalTo: searchBarBackground.contentView.bottomAnchor),
            
            resultLabel.trailingAnchor.constraint(
                equalTo: searchBarBackground.contentView.trailingAnchor,
                constant: -UX.searchContentInset
            ),
            resultLabel.centerYAnchor.constraint(equalTo: searchBarBackground.contentView.centerYAnchor),
            resultLabel.widthAnchor.constraint(equalToConstant: UX.resultLabelWidth),
            
            controlsShadowView.trailingAnchor.constraint(equalTo: searchContentView.trailingAnchor),
            controlsShadowView.centerYAnchor.constraint(equalTo: searchContentView.centerYAnchor),
            controlsShadowView.widthAnchor.constraint(equalToConstant: UX.controlsWidth),
            controlsShadowView.heightAnchor.constraint(equalToConstant: UX.controlsHeight),
            
            controlsBackground.topAnchor.constraint(equalTo: controlsShadowView.topAnchor),
            controlsBackground.leadingAnchor.constraint(equalTo: controlsShadowView.leadingAnchor),
            controlsBackground.trailingAnchor.constraint(equalTo: controlsShadowView.trailingAnchor),
            controlsBackground.bottomAnchor.constraint(equalTo: controlsShadowView.bottomAnchor),
            
            previousMatchButton.leadingAnchor.constraint(equalTo: controlsBackground.contentView.leadingAnchor),
            previousMatchButton.topAnchor.constraint(equalTo: controlsBackground.contentView.topAnchor),
            previousMatchButton.bottomAnchor.constraint(equalTo: controlsBackground.contentView.bottomAnchor),
            previousMatchButton.widthAnchor.constraint(equalToConstant: UX.controlButtonWidth),
            
            separator.leadingAnchor.constraint(equalTo: previousMatchButton.trailingAnchor),
            separator.centerYAnchor.constraint(equalTo: controlsBackground.contentView.centerYAnchor),
            separator.widthAnchor.constraint(equalToConstant: UX.separatorWidth),
            separator.heightAnchor.constraint(equalTo: controlsBackground.contentView.heightAnchor, multiplier: 0.42),
            
            nextMatchButton.leadingAnchor.constraint(equalTo: separator.trailingAnchor),
            nextMatchButton.trailingAnchor.constraint(equalTo: controlsBackground.contentView.trailingAnchor),
            nextMatchButton.topAnchor.constraint(equalTo: controlsBackground.contentView.topAnchor),
            nextMatchButton.bottomAnchor.constraint(equalTo: controlsBackground.contentView.bottomAnchor),
            nextMatchButton.widthAnchor.constraint(equalToConstant: UX.controlButtonWidth),
        ])
    }
    
    private func updateSearchContentLayout() {
        let availableWidth = bounds.width - UX.contentLeadingInset - UX.contentTrailingInset
        let shouldCenter = availableWidth >= UX.contentMaximumWidth
        guard searchContentViewCenterConstraint.isActive != shouldCenter else {
            return
        }
        
        searchContentViewCenterConstraint.isActive = shouldCenter
        searchContentViewLeadingConstraint.isActive = !shouldCenter
        searchContentViewTrailingConstraint.isActive = !shouldCenter
    }
    
    private func setResultText(_ text: String?) {
        resultLabel.text = text
        resultLabel.isHidden = text == nil
    }
    
    private func updateNavigationButtons() {
        let enabled = !(searchField.text ?? "").isEmpty
        previousMatchButton.isEnabled = enabled
        nextMatchButton.isEnabled = enabled
        previousMatchButton.alpha = enabled ? 1 : UX.disabledAlpha
        nextMatchButton.alpha = enabled ? 1 : UX.disabledAlpha
    }
    
    private func makeControlButton(
        imageName: String,
        action: Selector
    ) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        let configuration = UIImage.SymbolConfiguration(
            pointSize: UX.controlSymbolPointSize,
            weight: .regular
        )
        button.setImage(UIImage(named: imageName, in: .main, with: configuration), for: .normal)
        button.tintColor = .label
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
}

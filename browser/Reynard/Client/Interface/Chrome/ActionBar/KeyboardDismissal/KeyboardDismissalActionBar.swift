//
//  KeyboardDismissalActionBar.swift
//  Reynard
//

import UIKit

final class KeyboardDismissalActionBar: UIView {
    private enum UX {
        static let modernHeight: CGFloat = 48
        static let modernInset: CGFloat = 16
        static let modernSymbolSize: CGFloat = 20
        static let horizontalInset: CGFloat = 20
        static let fontSize: CGFloat = 17
        static let backgroundAlpha: CGFloat = 0.34
    }
    
    var onDone: (() -> Void)?
    
    private let backgroundView: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentView.backgroundColor = UIColor.systemBackground.withAlphaComponent(UX.backgroundAlpha)
        return view
    }()
    
    private lazy var doneButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(NSLocalizedString("Done", comment: "Dismiss keyboard button"), for: .normal)
        button.setTitleColor(.systemBlue, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: UX.fontSize, weight: .semibold)
        button.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureAppearance()
        configureHierarchy()
        configureConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Actions
    
    @objc private func doneTapped() {
        onDone?()
    }
    
    // MARK: - View Setup
    
    private func configureAppearance() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        if #available(iOS 26.0, *) {
            backgroundView.effect = UIGlassEffect.nonAdaptive(style: .regular)
            backgroundView.contentView.backgroundColor = .clear
            backgroundView.layer.cornerRadius = UX.modernHeight / 2
            backgroundView.clipsToBounds = true
            doneButton.setTitle(nil, for: .normal)
            doneButton.setImage(UIImage(systemName: "checkmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: UX.modernSymbolSize)), for: .normal)
            doneButton.tintColor = .label
            doneButton.accessibilityLabel = NSLocalizedString("Done", comment: "Dismiss keyboard button")
        }
    }
    
    private func configureHierarchy() {
        addSubview(backgroundView)
        addSubview(doneButton)
    }
    
    private func configureConstraints() {
        if #available(iOS 26.0, *) {
            NSLayoutConstraint.activate([
                backgroundView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: UX.modernInset),
                backgroundView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -UX.modernInset),
                backgroundView.centerYAnchor.constraint(equalTo: centerYAnchor),
                backgroundView.heightAnchor.constraint(equalToConstant: UX.modernHeight),
                doneButton.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor),
                doneButton.topAnchor.constraint(equalTo: backgroundView.topAnchor),
                doneButton.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor),
                doneButton.widthAnchor.constraint(equalToConstant: UX.modernHeight + UX.modernInset),
            ])
            return
        }
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            doneButton.topAnchor.constraint(equalTo: topAnchor),
            doneButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -UX.horizontalInset),
            doneButton.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}

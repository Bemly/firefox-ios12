//
//  AddWebsiteLanguageCell.swift
//  Reynard
//
//  Created by Minh Ton on 11/7/26.
//

import UIKit

final class AddWebsiteLanguageCell: UITableViewCell {
    static let reuseIdentifier = "AddWebsiteLanguageCell"
    
    var onAdd: (() -> Void)?
    
    private let addButton = UIButton(type: .contactAdd)
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        configureButton()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        onAdd = nil
    }
    
    func display(language: WebsiteLanguage) {
        textLabel?.text = language.title
        detailTextLabel?.text = language.code
        detailTextLabel?.textColor = .secondaryLabel
        accessoryView = addButton
    }
    
    private func configureButton() {
        addButton.tintColor = .systemGreen
        addButton.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
    }
    
    @objc private func addButtonTapped() {
        onAdd?()
    }
}

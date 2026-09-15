//
//  SidebarNavigationContainerViewController.swift
//  Reynard
//
//  Created by Minh Ton on 10/9/26.
//

import UIKit

final class SidebarNavigationContainerViewController: UIViewController {
    private let contentNavigationController: UINavigationController
    
    // MARK: - Lifecycle
    
    init(navigationController: UINavigationController) {
        contentNavigationController = navigationController
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGray6
        configureNavigationController()
    }
    
    // MARK: - View Setup
    
    private func configureNavigationController() {
        addChild(contentNavigationController)
        let contentView = contentNavigationController.view!
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentView)
        
        // The split view extends its primary column offscreen. Keep navigation
        // transitions inside the visible width while preserving vertical safe areas.
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: view.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        contentNavigationController.didMove(toParent: self)
    }
}

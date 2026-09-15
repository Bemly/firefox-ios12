//
//  SidebarMenuViewController.swift
//  Reynard
//
//  Created by Minh Ton on 11/6/26.
//

final class SidebarMenuViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UINavigationControllerDelegate {
    private enum UX {
        static let topContentInset: CGFloat = 32
        static let legacyItemHeight: CGFloat = 48
        static let sidebarButtonSize: CGFloat = 30
    }
    
    private let mainSection = "main"
    private let cellReuseIdentifier = "SidebarActionCell"
    private let childSidebarButtonTag = 9101
    private(set) var shownSection: LibrarySection?
    // Diffable data source is iOS 13+. Stored type-erased so this class stays
    // available on iOS 12, which uses a classic UICollectionViewDataSource
    // instead (see the iOS 12 data source methods below). See IOS12_GATES.md.
    private var dataSourceStorage: AnyObject?
    @available(iOS 13.0, *)
    private var dataSource: UICollectionViewDiffableDataSource<String, LibrarySection>? {
        get { dataSourceStorage as? UICollectionViewDiffableDataSource<String, LibrarySection> }
        set { dataSourceStorage = newValue }
    }
    
    private lazy var sidebarButton: UIButton = {
        let button = ToolbarButton(buttonType: .sidebar, target: self, action: #selector(collapseFromRoot))
        button.widthAnchor.constraint(equalToConstant: UX.sidebarButtonSize).isActive = true
        button.heightAnchor.constraint(equalToConstant: UX.sidebarButtonSize).isActive = true
        return button
    }()
    
    private lazy var collectionView: UICollectionView = {
        let layout: UICollectionViewLayout
        if #available(iOS 14.0, *) {
            var configuration = UICollectionLayoutListConfiguration(appearance: .sidebar)
            configuration.backgroundColor = .appSystemGray6
            layout = UICollectionViewCompositionalLayout.list(using: configuration)
        } else {
            let flowLayout = UICollectionViewFlowLayout()
            flowLayout.minimumLineSpacing = 0
            flowLayout.sectionInset = .zero
            layout = flowLayout
        }
        
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .appSystemGray6
        view.delegate = self
        if #available(iOS 14.0, *) {
            view.selectionFollowsFocus = false
        }
        return view
    }()
    
    // MARK: - Lifecycle
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // On iOS 12 the sidebar is an old UISplitViewController embedded as a
        // child VC, where the nav-bar safe-area inset doesn't propagate; keep the
        // content from sliding under the title bar. iOS 13+ uses the column split
        // view, which lays this out correctly on its own.
        if #unavailable(iOS 13.0) {
            edgesForExtendedLayout = []
        }
        configureAppearance()
        configureCollectionView()
        if #available(iOS 13.0, *) {
            configureDataSource()
            applySnapshot()
        } else {
            // Diffable data source is iOS 13+; use a classic data source on iOS 12.
            collectionView.dataSource = self
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.delegate = self
        navigationController?.setNavigationBarHidden(false, animated: animated)
        refreshSidebarButton()
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        refreshSidebarButton()
    }
    
    // MARK: - UINavigationControllerDelegate
    
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        // Apply the iOS 12 nav-bar inset fix to every pushed VC (submenus like
        // Addons/Compatibility), not just the top-level menu/detail, so their
        // content doesn't slide under the title bar either.
        if #unavailable(iOS 13.0) {
            viewController.edgesForExtendedLayout = []
        }
        refreshSidebarButton(for: viewController)
    }
    
    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        if viewController === self {
            shownSection = nil
        }
        refreshSidebarButton(for: viewController)
    }
    
    // MARK: - UICollectionViewDelegate
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let section: LibrarySection
        if #available(iOS 13.0, *), let identifier = dataSource?.itemIdentifier(for: indexPath) {
            section = identifier
        } else if indexPath.item < LibrarySection.allCases.count {
            section = LibrarySection.allCases[indexPath.item]
        } else {
            return
        }

        showSection(section, animated: true)
    }

    // MARK: - UICollectionViewDataSource (iOS 12)

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return LibrarySection.allCases.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseIdentifier, for: indexPath)
        if let sidebarCell = cell as? SidebarActionCell, indexPath.item < LibrarySection.allCases.count {
            let section = LibrarySection.allCases[indexPath.item]
            sidebarCell.configure(title: section.title, symbolName: section.symbolName)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        // Applies to the iOS <14 flow-layout fallback (full-width rows).
        return CGSize(width: collectionView.bounds.width, height: UX.legacyItemHeight)
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        return CGSize(width: collectionView.bounds.width, height: UX.legacyItemHeight)
    }
    
    // MARK: - Sections
    
    func showSection(
        _ section: LibrarySection,
        animated: Bool,
        startsEditingBookmarks: Bool = false
    ) {
        loadViewIfNeeded()
        shownSection = section

        var indexPath: IndexPath?
        if #available(iOS 13.0, *) {
            indexPath = dataSource?.indexPath(for: section)
        } else if let index = LibrarySection.allCases.firstIndex(of: section) {
            indexPath = IndexPath(item: index, section: 0)
        }
        if let indexPath {
            collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
        }

        let viewController = makeSectionViewController(
            for: section,
            startsEditingBookmarks: startsEditingBookmarks
        )
        navigationController?.setViewControllers([self, viewController], animated: animated)
        if let indexPath {
            collectionView.deselectItem(at: indexPath, animated: animated)
        }
    }
    
    private func makeSectionViewController(
        for section: LibrarySection,
        startsEditingBookmarks: Bool
    ) -> UIViewController {
        let contentViewController: UIViewController
        
        switch section {
        case .bookmarks:
            contentViewController = BookmarksViewController(startsEditing: startsEditingBookmarks)
        case .history:
            contentViewController = HistoryViewController()
        case .downloads:
            contentViewController = DownloadsViewController()
        case .settings:
            contentViewController = SettingsViewController()
        }
        
        return SidebarDetailViewController(
            title: section.title,
            contentViewController: contentViewController
        )
    }
    
    // MARK: - Navigation Items
    
    func refreshSidebarButton() {
        guard let viewController = navigationController?.topViewController else {
            return
        }
        
        refreshSidebarButton(for: viewController)
    }
    
    private func refreshSidebarButton(for viewController: UIViewController) {
        let showChromeSidebarButton = (splitViewController as? SidebarViewController)?.showChromeSidebarButton == true
        if viewController === self {
            if showChromeSidebarButton {
                navigationItem.leftBarButtonItem = nil
                navigationItem.leftBarButtonItems = nil
            } else {
                configureSidebarButton(sidebarButton)
                navigationItem.leftBarButtonItem = nil
                navigationItem.leftBarButtonItems = standaloneSidebarButtonItems(for: sidebarButton)
            }
            navigationItem.rightBarButtonItem = nil
            return
        }
        
        guard !showChromeSidebarButton else {
            removeSidebarButton(from: viewController.navigationItem)
            return
        }
        
        let button = makeSidebarButton(action: #selector(collapseFromChild(_:)))
        configureSidebarButton(button)
        let item = UIBarButtonItem(customView: button)
        item.tag = childSidebarButtonTag
        viewController.navigationItem.rightBarButtonItems = rightBarButtonItemsExcludingSidebarButton(
            from: viewController.navigationItem
        ) + [item]
    }
    
    private func makeSidebarButton(action: Selector) -> UIButton {
        let button = ToolbarButton(buttonType: .sidebar, target: self, action: action)
        button.widthAnchor.constraint(equalToConstant: UX.sidebarButtonSize).isActive = true
        button.heightAnchor.constraint(equalToConstant: UX.sidebarButtonSize).isActive = true
        return button
    }
    
    private func standaloneSidebarButtonItems(for button: UIButton) -> [UIBarButtonItem] {
        let item = UIBarButtonItem(customView: button)
        let leadingSpace = standaloneSidebarButtonLeadingSpace
        guard leadingSpace > 0 else {
            return [item]
        }
        
        let spacer = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        spacer.width = leadingSpace
        return [spacer, item]
    }
    
    private func configureSidebarButton(_ button: UIButton) {
        button.setImage(splitViewController?.displayModeButtonItem.image ?? UIImage(named: "reynard.sidebar.left"), for: .normal)
        button.accessibilityLabel = splitViewController?.displayModeButtonItem.accessibilityLabel
    }
    
    private var standaloneSidebarButtonLeadingSpace: CGFloat {
        if #available(iOS 26.0, *) {
            let layoutInsets = view.directionalEdgeInsets(for: .safeArea(cornerAdaptation: .horizontal))
            let safeAreaLeadingInset = view.effectiveUserInterfaceLayoutDirection == .rightToLeft
            ? view.safeAreaInsets.right
            : view.safeAreaInsets.left
            return max(0, layoutInsets.leading - safeAreaLeadingInset)
        }
        
        return 0
    }
    
    private func rightBarButtonItemsExcludingSidebarButton(from navigationItem: UINavigationItem) -> [UIBarButtonItem] {
        return navigationItem.rightBarButtonItems?.filter { $0.tag != childSidebarButtonTag } ?? []
    }
    
    private func removeSidebarButton(from navigationItem: UINavigationItem) {
        let remainingItems = rightBarButtonItemsExcludingSidebarButton(from: navigationItem)
        navigationItem.rightBarButtonItems = remainingItems.isEmpty ? nil : remainingItems
    }
    
    // MARK: - Actions
    
    @objc private func collapseFromRoot() {
        (splitViewController as? SidebarViewController)?.setVisible(false)
    }
    
    @objc private func collapseFromChild(_ sender: UIButton) {
        (splitViewController as? SidebarViewController)?.collapse(from: sender)
    }
    
    // MARK: - View Setup
    
    private func configureAppearance() {
        view.backgroundColor = .appSystemGray6
    }
    
    private func configureCollectionView() {
        collectionView.contentInset.top = UX.topContentInset
        collectionView.verticalScrollIndicatorInsets.top = UX.topContentInset
        collectionView.register(SidebarActionCell.self, forCellWithReuseIdentifier: cellReuseIdentifier)
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
    
    @available(iOS 13.0, *)
    private func configureDataSource() {
        if #available(iOS 14.0, *) {
            let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, LibrarySection> { cell, _, section in
                var content = cell.defaultContentConfiguration()
                content.text = section.title
                content.image = UIImage(named: section.symbolName)
                content.imageProperties.tintColor = .appLabel
                cell.contentConfiguration = content
                cell.accessories = []
            }
            
            dataSource = UICollectionViewDiffableDataSource<String, LibrarySection>(collectionView: collectionView) { collectionView, indexPath, item in
                collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
            }
            return
        }
        
        dataSource = UICollectionViewDiffableDataSource<String, LibrarySection>(collectionView: collectionView) { collectionView, indexPath, item in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: self.cellReuseIdentifier, for: indexPath)
            if let sidebarCell = cell as? SidebarActionCell {
                sidebarCell.configure(title: item.title, symbolName: item.symbolName)
            }
            return cell
        }
    }
    
    @available(iOS 13.0, *)
    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<String, LibrarySection>()
        snapshot.appendSections([mainSection])
        snapshot.appendItems(LibrarySection.allCases, toSection: mainSection)
        dataSource?.apply(snapshot, animatingDifferences: false)
    }
}

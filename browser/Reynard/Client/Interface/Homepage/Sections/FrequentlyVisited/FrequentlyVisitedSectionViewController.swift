//
//  FrequentlyVisitedSectionViewController.swift
//  Reynard
//
//  Created by Minh Ton on 24/6/26.
//

import UIKit

final class FrequentlyVisitedSectionViewController: UIViewController {
    private enum UX {
        static let horizontalInset: CGFloat = 2
        static let titleTopSpacing: CGFloat = 16
        static let titleBottomSpacing: CGFloat = 14
        static let titleFontSize: CGFloat = 22
        static let cardWidth: CGFloat = 150
        static let cardHeight: CGFloat = 120
        static let cardSpacing: CGFloat = 16
        static let shadowMargin: CGFloat = 20
    }
    
    private enum MetadataState {
        case loading(UUID)
        case loaded(SiteMetadataSnapshot)
    }
    
    private static let titleFont = UIFontMetrics(forTextStyle: .title2).scaledFont(
        for: .systemFont(ofSize: UX.titleFontSize, weight: .bold)
    )
    
    weak var delegate: HomepageSectionDelegate?
    
    private let historyStore: HistoryStore
    private let metadataStore: SiteMetadataStore
    private var contentMode: HomepageContentMode = .embeddedNarrow
    private var sites: [HistorySiteSnapshot] = []
    private var metadataStatesByURL: [URL: MetadataState] = [:]
    private var cardViews: [FrequentlyVisitedSiteCardView] = []
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = FrequentlyVisitedSectionViewController.titleFont
        label.textColor = .label
        label.text = NSLocalizedString("Frequently Visited", comment: "")
        label.adjustsFontForContentSizeCategory = true
        return label
    }()
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .clear
        scrollView.showsHorizontalScrollIndicator = false
        return scrollView
    }()
    
    private let cardStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.spacing = UX.cardSpacing
        return stackView
    }()
    
    // MARK: - Lifecycle
    
    init(historyStore: HistoryStore = .shared, metadataStore: SiteMetadataStore = .shared) {
        self.historyStore = historyStore
        self.metadataStore = metadataStore
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        cancelMetadataLoads()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureAppearance()
        configureHierarchy()
        configureConstraints()
        observeChanges()
        reloadSites()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    func setContentMode(_ contentMode: HomepageContentMode) {
        guard self.contentMode != contentMode else {
            return
        }
        
        self.contentMode = contentMode
        titleLabel.textColor = HomepageWallpaper.foregroundColor(for: contentMode)
    }
    
    // MARK: - Configuration
    
    private func configureAppearance() {
        view.backgroundColor = .clear
        titleLabel.textColor = HomepageWallpaper.foregroundColor(for: contentMode)
    }
    
    private func configureHierarchy() {
        view.addSubview(titleLabel)
        view.addSubview(scrollView)
        scrollView.addSubview(cardStackView)
    }
    
    private func configureConstraints() {
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: UX.titleTopSpacing),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: UX.horizontalInset),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -UX.horizontalInset),
            
            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: UX.titleBottomSpacing - UX.shadowMargin),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -UX.shadowMargin),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: UX.shadowMargin),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: UX.cardHeight + (UX.shadowMargin * 2)),
            
            cardStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: UX.shadowMargin),
            cardStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -UX.shadowMargin),
            cardStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: UX.shadowMargin),
            cardStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -UX.shadowMargin),
            cardStackView.heightAnchor.constraint(equalToConstant: UX.cardHeight),
        ])
    }
    
    private func observeChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(historyDidChange),
            name: .historyStoreDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(homepageSettingsDidChange),
            name: .homepageSettingsDidChange,
            object: nil
        )
    }
    
    // MARK: - History
    
    func site(for cardView: FrequentlyVisitedSiteCardView) -> HistorySiteSnapshot? {
        guard sites.indices.contains(cardView.tag) else {
            return nil
        }
        
        return sites[cardView.tag]
    }
    
    private func reloadSites() {
        sites = historyStore.frequentSites(
            limit: Prefs.HomepageSettings.frequentlyVisitedSiteCount,
            minVisitCount: 3
        ).items
        let retainedURLs = Set(sites.map(\.url))
        metadataStatesByURL = metadataStatesByURL.filter { url, _ in
            retainedURLs.contains(url)
        }
        
        metadataStore.prune(keeping: sites.map(\.url))
        reloadCardViews()
        view.isHidden = sites.isEmpty
    }
    
    @objc private func historyDidChange() {
        reloadSites()
    }
    
    @objc private func homepageSettingsDidChange() {
        reloadSites()
    }
    
    // MARK: - Metadata
    
    private func metadata(for site: HistorySiteSnapshot) -> SiteMetadataSnapshot? {
        if case let .loaded(metadata) = metadataStatesByURL[site.url] {
            return metadata
        }
        
        if let cachedMetadata = metadataStore.cachedMetadata(for: site.url) {
            metadataStatesByURL[site.url] = .loaded(cachedMetadata)
            return cachedMetadata
        }
        
        loadMetadata(for: site.url)
        return nil
    }
    
    private func loadMetadata(for url: URL) {
        guard metadataStatesByURL[url] == nil else {
            return
        }

        let token = UUID()
        metadataStatesByURL[url] = .loading(token)

        metadataStore.metadata(for: url) { [weak self] metadata in
            guard let self else {
                return
            }

            guard case let .loading(currentToken)? = self.metadataStatesByURL[url],
                  currentToken == token else {
                return
            }

            guard let metadata,
                  self.sites.contains(where: { $0.url == url }) else {
                self.metadataStatesByURL[url] = nil
                return
            }

            self.metadataStatesByURL[url] = .loaded(metadata)
            if let index = self.sites.firstIndex(where: { $0.url == url }) {
                self.cardViews[index].configure(site: self.sites[index], metadata: metadata)
            }
        }
    }

    private func cancelMetadataLoads() {
        metadataStatesByURL = metadataStatesByURL.filter { _, state in
            if case .loading = state {
                return false
            }
            return true
        }
    }
    
    // MARK: - Layout
    
    private func reloadCardViews() {
        for cardView in cardViews {
            cardView.removeFromSuperview()
        }
        
        cardViews = sites.enumerated().map { index, site in
            let cardView = FrequentlyVisitedSiteCardView()
            cardView.translatesAutoresizingMaskIntoConstraints = false
            cardView.tag = index
            cardView.configure(site: site, metadata: metadata(for: site))
            cardView.addTarget(self, action: #selector(handleCardTap(_:)), for: .touchUpInside)
            if #available(iOS 13.0, *) {
                cardView.addInteraction(UIContextMenuInteraction(delegate: self))
            }
            cardStackView.addArrangedSubview(cardView)
            
            NSLayoutConstraint.activate([
                cardView.widthAnchor.constraint(equalToConstant: UX.cardWidth),
                cardView.heightAnchor.constraint(equalToConstant: UX.cardHeight),
            ])
            
            return cardView
        }
    }
    
    // MARK: - Actions
    
    @objc private func handleCardTap(_ sender: FrequentlyVisitedSiteCardView) {
        guard sites.indices.contains(sender.tag) else {
            return
        }
        
        delegate?.homepageSection(self, didRequestOpenURL: sites[sender.tag].url, disposition: .currentTab)
    }
}

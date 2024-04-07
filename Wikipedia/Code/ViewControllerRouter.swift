import UIKit
import AVKit
import Components
import WKData

// Wrapper class for access in Objective-C
@objc class WMFRoutingUserInfoKeys: NSObject {
    @objc static var source: String {
        return RoutingUserInfoKeys.source
    }
}

// Wrapper class for access in Objective-C
@objc class WMFRoutingUserInfoSourceValue: NSObject {
    @objc static var deepLinkRawValue: String {
        return RoutingUserInfoSourceValue.deepLink.rawValue
    }
}

struct RoutingUserInfoKeys {
    static let talkPageReplyText = "talk-page-reply-text"
    static let source = "source"
    static let campaignArticleURL = "campaign-article-url"
    static let campaignBannerID = "campaign-banner-id"
}

enum RoutingUserInfoSourceValue: String {
    case talkPage
    case talkPageArchives
    case article
    case notificationsCenter
    case deepLink
    case account
    case search
    case inAppWebView
    case watchlist
    case unknown
}

@objc(WMFViewControllerRouter)
class ViewControllerRouter: NSObject {

    @objc let router: Router
    unowned let appViewController: WMFAppViewController
    @objc(initWithAppViewController:router:)
    required init(appViewController: WMFAppViewController, router: Router) {
        self.appViewController = appViewController
        self.router = router
    }
    
    private func presentLoginViewController(with completion: @escaping () -> Void) -> Bool {
        
        appViewController.wmf_showLoginViewController(theme: appViewController.theme)
        return true
    }

    private func presentOrPush(_ viewController: UIViewController, with completion: @escaping () -> Void) -> Bool {
        guard let navigationController = appViewController.currentNavigationController else {
            completion()
            return false
        }

        let showNewVC = {
            if viewController is AVPlayerViewController {
                navigationController.present(viewController, animated: true, completion: completion)
            } else if let createReadingListVC = viewController as? CreateReadingListViewController,
                      createReadingListVC.isInImportingMode {

                let createReadingListNavVC = WMFThemeableNavigationController(rootViewController: createReadingListVC, theme: self.appViewController.theme)
                navigationController.present(createReadingListNavVC, animated: true, completion: completion)
            } else {
                navigationController.pushViewController(viewController, animated: true)
                completion()
            }
        }

        // For Article as a Living Doc modal - fix the nav bar in place
        if navigationController.children.contains(where: { $0 is ArticleAsLivingDocViewController }) {
            if let vc = viewController as? SinglePageWebViewController, navigationController.modalPresentationStyle == .pageSheet {
                vc.doesUseSimpleNavigationBar = true
                vc.navigationBar.isBarHidingEnabled = false
            }
        }
        
        // pass along doesUseSimpleNavigationBar SinglePageWebViewController settings to the next one if needed
        if let lastWebVC = navigationController.children.last as? SinglePageWebViewController,
           let nextWebVC = viewController as? SinglePageWebViewController {
            nextWebVC.doesUseSimpleNavigationBar = lastWebVC.doesUseSimpleNavigationBar
        }

        if let presentedVC = navigationController.presentedViewController {
            presentedVC.dismiss(animated: false, completion: showNewVC)
        } else {
            showNewVC()
        }
        
        return true
    }
    
    @objc(routeURL:userInfo:completion:)
    public func route(_ url: URL, userInfo: [AnyHashable: Any]? = nil, completion: @escaping () -> Void) -> Bool {
        let theme = appViewController.theme
        let loggedInUsername = MWKDataStore.shared().authenticationManager.loggedInUsername
        let destination = router.destination(for: url, loggedInUsername: loggedInUsername)
        switch destination {
        case .article(let articleURL):
            appViewController.swiftCompatibleShowArticle(with: articleURL, animated: true, completion: completion)
            return true
        case .externalLink(let linkURL):
            appViewController.navigate(to: linkURL, useSafari: true)
            completion()
            return true
        case .articleHistory(let linkURL, let articleTitle):
            let pageHistoryVC = PageHistoryViewController(pageTitle: articleTitle, pageURL: linkURL, articleSummaryController: appViewController.dataStore.articleSummaryController, authenticationManager: appViewController.dataStore.authenticationManager)
            return presentOrPush(pageHistoryVC, with: completion)
        case .articleDiff(let linkURL, let fromRevID, let toRevID):
            guard let siteURL = linkURL.wmf_site,
                  fromRevID != nil || toRevID != nil else {
                completion()
                return false
            }
            
            let diffContainerVC = DiffContainerViewController(siteURL: siteURL, theme: theme, fromRevisionID: fromRevID, toRevisionID: toRevID, articleTitle: nil, articleSummaryController: appViewController.dataStore.articleSummaryController, authenticationManager: appViewController.dataStore.authenticationManager)
            return presentOrPush(diffContainerVC, with: completion)
        case .inAppLink(let linkURL):
            let campaignArticleURL = userInfo?[RoutingUserInfoKeys.campaignArticleURL] as? URL
            let campaignBannerID = userInfo?[RoutingUserInfoKeys.campaignBannerID] as? String
            let singlePageVC = SinglePageWebViewController(url: linkURL, theme: theme, campaignArticleURL: campaignArticleURL, campaignBannerID: campaignBannerID)
            return presentOrPush(singlePageVC, with: completion)
        case .audio(let audioURL):
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            let vc = AVPlayerViewController()
            let player = AVPlayer(url: audioURL)
            vc.player = player
            return presentOrPush(vc, with: completion)
        case .talk(let linkURL):
            let source = source(from: userInfo)
            guard let viewModel = TalkPageViewModel(pageType: .article, pageURL: linkURL, source: source, articleSummaryController: appViewController.dataStore.articleSummaryController, authenticationManager: appViewController.dataStore.authenticationManager, languageLinkController: appViewController.dataStore.languageLinkController) else {
                completion()
                return false
            }
            
            if let deepLinkData = talkPageDeepLinkData(linkURL: linkURL, userInfo: userInfo) {
                viewModel.deepLinkData = deepLinkData
            }
            
            let newTalkPage = TalkPageViewController(theme: theme, viewModel: viewModel)
            return presentOrPush(newTalkPage, with: completion)
        case .userTalk(let linkURL):
            let source = source(from: userInfo)
            guard let viewModel = TalkPageViewModel(pageType: .user, pageURL: linkURL, source: source, articleSummaryController: appViewController.dataStore.articleSummaryController, authenticationManager: appViewController.dataStore.authenticationManager, languageLinkController: appViewController.dataStore.languageLinkController) else {
                completion()
                return false
            }

            if let deepLinkData = talkPageDeepLinkData(linkURL: linkURL, userInfo: userInfo) {
                viewModel.deepLinkData = deepLinkData
            }

            let newTalkPage = TalkPageViewController(theme: theme, viewModel: viewModel)
            return presentOrPush(newTalkPage, with: completion)

        case .onThisDay(let indexOfSelectedEvent):
            let dataStore = appViewController.dataStore
            guard let contentGroup = dataStore.viewContext.newestVisibleGroup(of: .onThisDay, forSiteURL: dataStore.primarySiteURL), let onThisDayVC = contentGroup.detailViewControllerWithDataStore(dataStore, theme: theme) as? OnThisDayViewController else {
                completion()
                return false
            }
            onThisDayVC.shouldShowNavigationBar = true
            if let index = indexOfSelectedEvent, let selectedEvent = onThisDayVC.events.first(where: { $0.index == NSNumber(value: index) }) {
                onThisDayVC.initialEvent = selectedEvent
            }
            return presentOrPush(onThisDayVC, with: completion)
            
        case .readingListsImport(let encodedPayload):
            guard appViewController.editingFlowViewControllerInHierarchy == nil else {
                // Do not show reading list import if user is in the middle of editing
                completion()
                return false
            }

            let createReadingListVC = CreateReadingListViewController(theme: theme, articles: [], encodedPageIds: encodedPayload, dataStore: appViewController.dataStore)
            createReadingListVC.delegate = appViewController
            return presentOrPush(createReadingListVC, with: completion)
        case .login:
            return presentLoginViewController(with: completion)
        case .watchlist:
            let userDefaults = UserDefaults.standard

            let targetNavigationController = watchlistTargetNavigationController()
            if !userDefaults.wmf_userHasOnboardedToWatchlists {
                showWatchlistOnboarding(targetNavigationController: targetNavigationController)
            } else {
                goToWatchlist(targetNavigationController: targetNavigationController)
            }

            return true
        default:
            completion()
            return false
        }
    }
    
    private func talkPageDeepLinkData(linkURL: URL, userInfo: [AnyHashable: Any]?) -> TalkPageViewModel.DeepLinkData? {
        
        guard let topicTitle = linkURL.fragment else {
            return nil
        }
        
        let replyText = userInfo?[RoutingUserInfoKeys.talkPageReplyText] as? String

        let deepLinkData = TalkPageViewModel.DeepLinkData(topicTitle: topicTitle, replyText: replyText)
        return deepLinkData
    }
    
    private func source(from userInfo: [AnyHashable: Any]?) -> RoutingUserInfoSourceValue {
        guard let sourceString = userInfo?[RoutingUserInfoKeys.source] as? String,
              let source = RoutingUserInfoSourceValue(rawValue: sourceString) else {
            return .unknown
        }

        return source
    }
    
    private func watchlistTargetNavigationController() -> UINavigationController? {
        var targetNavigationController = appViewController.navigationController
        if let presentedNavigationController = appViewController.presentedViewController as? UINavigationController,
           presentedNavigationController.viewControllers[0] is WMFSettingsViewController {
            targetNavigationController = presentedNavigationController
        }
        return targetNavigationController
    }
    
    private var watchlistFilterViewModel: WKWatchlistFilterViewModel {
        
        let dataStore = appViewController.dataStore
        let appLanguages = dataStore.languageLinkController.preferredLanguages
        var localizedProjectNames = appLanguages.reduce(into: [WKProject: String]()) { result, language in
            
            guard let wikimediaProject = WikimediaProject(siteURL: language.siteURL, languageLinkController: dataStore.languageLinkController),
                  let wkProject = wikimediaProject.wkProject else {
                return
            }
            
            result[wkProject] = wikimediaProject.projectName(shouldReturnCodedFormat: false)
        }
        localizedProjectNames[.wikidata] = WikimediaProject.wikidata.projectName(shouldReturnCodedFormat: false)
        localizedProjectNames[.commons] = WikimediaProject.commons.projectName(shouldReturnCodedFormat: false)
        
        let localizedStrings = WKWatchlistFilterViewModel.LocalizedStrings(
            title: CommonStrings.watchlistFilter,
            doneTitle: CommonStrings.doneTitle,
            localizedProjectNames: localizedProjectNames,
            wikimediaProjectsHeader: CommonStrings.wikimediaProjectsHeader,
            wikipediasHeader: CommonStrings.wikipediasHeader,
            commonAll: CommonStrings.filterOptionsAll,
            latestRevisionsHeader: CommonStrings.watchlistFilterLatestRevisionsHeader,
            latestRevisionsLatestRevision: CommonStrings.watchlistFilterLatestRevisionsOptionLatestRevision,
            latestRevisionsNotLatestRevision: CommonStrings.watchlistFilterLatestRevisionsOptionNotTheLatestRevision,
            watchlistActivityHeader: CommonStrings.watchlistFilterActivityHeader,
            watchlistActivityUnseenChanges: CommonStrings.watchlistFilterActivityOptionUnseenChanges,
            watchlistActivitySeenChanges: CommonStrings.watchlistFilterActivityOptionSeenChanges,
            automatedContributionsHeader: CommonStrings.watchlistFilterAutomatedContributionsHeader,
            automatedContributionsBot: CommonStrings.watchlistFilterAutomatedContributionsOptionBot,
            automatedContributionsHuman: CommonStrings.watchlistFilterAutomatedContributionsOptionHuman,
            significanceHeader: CommonStrings.watchlistFilterSignificanceHeader,
            significanceMinorEdits: CommonStrings.watchlistFilterSignificanceOptionMinorEdits,
            significanceNonMinorEdits: CommonStrings.watchlistFilterSignificanceOptionNonMinorEdits,
            userRegistrationHeader: CommonStrings.watchlistFilterUserRegistrationHeader,
            userRegistrationUnregistered: CommonStrings.watchlistFilterUserRegistrationOptionUnregistered,
            userRegistrationRegistered: CommonStrings.watchlistFilterUserRegistrationOptionRegistered,
            typeOfChangeHeader: CommonStrings.watchlistFilterTypeOfChangeHeader,
            typeOfChangePageEdits: CommonStrings.watchlistFilterTypeOfChangeOptionPageEdits,
            typeOfChangePageCreations: CommonStrings.watchlistFilterTypeOfChangeOptionPageCreations,
            typeOfChangeCategoryChanges: CommonStrings.watchlistFilterTypeOfChangeOptionCategoryChanges,
            typeOfChangeWikidataEdits: CommonStrings.watchlistFilterTypeOfChangeOptionWikidataEdits,
            typeOfChangeLoggedActions: CommonStrings.watchlistFilterTypeOfChangeOptionLoggedActions,
            addLanguage: CommonStrings.watchlistFilterAddLanguageButtonTitle
        )

        var overrideUserInterfaceStyle: UIUserInterfaceStyle = .unspecified
        let themeName = UserDefaults.standard.themeName
        if !Theme.isDefaultThemeName(themeName) {
            overrideUserInterfaceStyle = WKAppEnvironment.current.theme.userInterfaceStyle
        }

        return WKWatchlistFilterViewModel(localizedStrings: localizedStrings, overrideUserInterfaceStyle: overrideUserInterfaceStyle, loggingDelegate: appViewController)
    }
    
    func showWatchlistOnboarding(targetNavigationController: UINavigationController?) {
        let trackChanges = WKOnboardingViewModel.WKOnboardingCellViewModel(icon: UIImage(named: "track-changes"), title: CommonStrings.watchlistTrackChangesTitle, subtitle: CommonStrings.watchlistTrackChangesSubtitle)
        let watchArticles = WKOnboardingViewModel.WKOnboardingCellViewModel(icon: UIImage(named: "watch-articles"), title: CommonStrings.watchlistWatchChangesTitle, subtitle: CommonStrings.watchlistWatchChangesSubitle)
        let setExpiration = WKOnboardingViewModel.WKOnboardingCellViewModel(icon: UIImage(named: "set-expiration"), title: CommonStrings.watchlistSetExpirationTitle, subtitle: CommonStrings.watchlistSetExpirationSubtitle)
        let viewUpdates = WKOnboardingViewModel.WKOnboardingCellViewModel(icon: UIImage(named: "view-updates"), title: CommonStrings.watchlistViewUpdatesTitle, subtitle: CommonStrings.watchlistViewUpdatesSubitle)

        let viewModel = WKOnboardingViewModel(title: CommonStrings.watchlistOnboardingTitle, cells: [trackChanges, watchArticles, setExpiration, viewUpdates], primaryButtonTitle: CommonStrings.continueButton, secondaryButtonTitle: CommonStrings.watchlistOnboardingLearnMore)

        let viewController = WKOnboardingViewController(viewModel: viewModel)
        viewController.hostingController.delegate = self
        
        WatchlistFunnel.shared.logWatchlistOnboardingAppearance()

        targetNavigationController?.present(viewController, animated: true) {
            UserDefaults.standard.wmf_userHasOnboardedToWatchlists = true
        }
    }
    
    func goToWatchlist(targetNavigationController: UINavigationController?) {
        let localizedByteChange: (Int) -> String = { bytes in
            String.localizedStringWithFormat(
                WMFLocalizedString("watchlist-byte-change", value:"{{PLURAL:%1$d|%1$d byte|%1$d bytes}}", comment: "Amount of bytes changed for a revision displayed in watchlist - %1$@ is replaced with the number of bytes."),
                bytes
            )
        }

        let htmlStripped: (String) -> String = { inputString in
            return inputString.removingHTML
        }

        let attributedFilterString: (Int) -> AttributedString = { filters in
            let localizedString = String.localizedStringWithFormat(
                WMFLocalizedString("watchlist-number-filters", value:"Modify [{{PLURAL:%1$d|%1$d filter|%1$d filters}}](wikipedia://watchlist/filter) to see more Watchlist items", comment: "Amount of filters active in watchlist - %1$@ is replaced with the number of filters."),
                filters
            )
            
            let attributedString = (try? AttributedString(markdown: localizedString)) ?? AttributedString(localizedString)
            return attributedString
        }

        let localizedStrings = WKWatchlistViewModel.LocalizedStrings(title: CommonStrings.watchlist, filter: CommonStrings.watchlistFilter, userButtonUserPage: CommonStrings.userButtonPage, userButtonTalkPage: CommonStrings.userButtonTalkPage, userButtonContributions: CommonStrings.userButtonContributions, userButtonThank: CommonStrings.userButtonThank, emptyEditSummary: CommonStrings.emptyEditSummary, userAccessibility: CommonStrings.userTitle, summaryAccessibility: CommonStrings.editSummaryTitle, userAccessibilityButtonDiff: CommonStrings.watchlistGoToDiff, localizedProjectNames: watchlistFilterViewModel.localizedStrings.localizedProjectNames, byteChange: localizedByteChange,  htmlStripped: htmlStripped)

        let presentationConfiguration = WKWatchlistViewModel.PresentationConfiguration(showNavBarUponAppearance: true, hideNavBarUponDisappearance: true)

        let viewModel = WKWatchlistViewModel(localizedStrings: localizedStrings, presentationConfiguration: presentationConfiguration)

        let localizedStringsEmptyView = WKEmptyViewModel.LocalizedStrings(title: CommonStrings.watchlistEmptyViewTitle, subtitle: CommonStrings.watchlistEmptyViewSubtitle, titleFilter: CommonStrings.watchlistEmptyViewFilterTitle, buttonTitle: CommonStrings.watchlistEmptyViewButtonTitle, attributedFilterString: attributedFilterString)

        let reachabilityNotifier = ReachabilityNotifier(Configuration.current.defaultSiteDomain) { (reachable, _) in
            if reachable {
                WMFAlertManager.sharedInstance.dismissAllAlerts()
            } else {
                WMFAlertManager.sharedInstance.showErrorAlertWithMessage(CommonStrings.noInternetConnection, sticky: true, dismissPreviousAlerts: true)
            }
        }

        let reachabilityHandler: WKWatchlistViewController.ReachabilityHandler = { state in
            switch state {
            case .appearing:
                reachabilityNotifier.start()
            case .disappearing:
                reachabilityNotifier.stop()
            }
        }
        
        let emptyViewModel = WKEmptyViewModel(localizedStrings: localizedStringsEmptyView, image: UIImage(named: "watchlist-empty-state"), imageColor: nil, numberOfFilters: viewModel.activeFilterCount)

        let watchlistViewController = WKWatchlistViewController(viewModel: viewModel, filterViewModel: watchlistFilterViewModel, emptyViewModel: emptyViewModel, delegate: appViewController, loggingDelegate: appViewController, reachabilityHandler: reachabilityHandler)

        targetNavigationController?.pushViewController(watchlistViewController, animated: true)
    }
}

extension ViewControllerRouter: WKOnboardingViewDelegate {
    
    func onboardingViewDidClickPrimaryButton() {
        
        let targetNavigationController = watchlistTargetNavigationController()
        
        WatchlistFunnel.shared.logWatchlistOnboardingTapContinue()
        
        if let presentedViewController = targetNavigationController?.presentedViewController {
            presentedViewController.dismiss(animated: true) { [weak self] in
                self?.goToWatchlist(targetNavigationController: targetNavigationController)
            }
        }
    }

    func onboardingViewDidClickSecondaryButton() {
        
        let targetNavigationController = watchlistTargetNavigationController()
        
        WatchlistFunnel.shared.logWatchlistOnboardingTapLearnMore()

        if let presentedViewController = targetNavigationController?.presentedViewController {
            presentedViewController.dismiss(animated: true) { [weak self] in
                guard let url = URL(string: "https://www.mediawiki.org/wiki/Wikimedia_Apps/iOS_FAQ#Watchlist") else {
                    return
                }
                self?.appViewController.navigate(to: url)
            }
        }
    }
    
    func onboardingViewWillSwipeToDismiss() {
        
    }
}

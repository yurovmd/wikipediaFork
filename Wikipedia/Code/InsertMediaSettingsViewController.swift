import UIKit
import WKData

typealias InsertMediaSettings = InsertMediaSettingsViewController.Settings

final class InsertMediaSettingsViewController: ViewController {
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let image: UIImage
    private let fromImageRecommendations: Bool

    private let wikitext: String?
    private let articleURL: URL?
    private let sectionNumber: Int?

    let searchResult: InsertMediaSearchResult
    private var nextButton: UIBarButtonItem?

    private var textViewHeightDelta: (value: CGFloat, row: Int)?
    private var textViewsGroupedByType = [TextViewType: UITextView]()

    struct Settings {
        let caption: String?
        let alternativeText: String?
        let advanced: Advanced

        struct Advanced {
            let wrapTextAroundImage: Bool
            let imagePosition: ImagePosition
            let imageType: ImageType
            let imageSize: ImageSize

            enum ImagePosition: String {
                case right
                case left
                case center
                case none

                var displayTitle: String {
                    switch self {
                    case .right:
                        return WMFLocalizedString("insert-media-image-position-setting-right", value: "Right", comment: "Title for image position setting that positions image on the right")
                    case .left:
                        return WMFLocalizedString("insert-media-image-position-setting-left", value: "Left", comment: "Title for image position setting that positions image on the left")
                    case .center:
                        return WMFLocalizedString("insert-media-image-position-setting-center", value: "Center", comment: "Title for image position setting that positions image in the center")
                    case .none:
                        return WMFLocalizedString("insert-media-image-position-setting-none", value: "None", comment: "Title for image position setting that doesn't set image's position")
                    }
                }

                static var displayTitle: String {
                    return WMFLocalizedString("insert-media-image-position-settings-title", value: "Image position", comment: "Display ritle for image position setting")
                }
            }

            enum ImageType: String {
                case thumbnail = "thumb"
                case frameless
                case frame
                case basic

                var displayTitle: String {
                    switch self {
                    case .thumbnail:
                        return WMFLocalizedString("insert-media-image-type-setting-thumbnail", value: "Thumbnail", comment: "Title for image type setting that formats image as thumbnail")
                    case .frameless:
                        return WMFLocalizedString("insert-media-image-type-setting-frameless", value: "Frameless", comment: "Title for image type setting that formats image as frameless")
                    case .frame:
                        return WMFLocalizedString("insert-media-image-type-setting-frame", value: "Frame", comment: "Title for image type setting that formats image as framed")
                    case .basic:
                        return WMFLocalizedString("insert-media-image-type-setting-basic", value: "Basic", comment: "Title for image type setting that formats image as basic")
                    }
                }

                static var displayTitle: String {
                    return WMFLocalizedString("insert-media-image-type-settings-title", value: "Image type", comment: "Display ritle for image type setting")
                }
            }

            enum ImageSize {
                case `default`
                case custom(width: Int, height: Int)

                var displayTitle: String {
                    switch self {
                    case .default:
                        return WMFLocalizedString("insert-media-image-size-setting-default", value: "Default", comment: "Title for image size setting that sizes image using default size")
                    case .custom:
                        return WMFLocalizedString("insert-media-image-size-setting-custom", value: "Custom", comment: "Title for image size setting that sizes image using custom size")
                    }
                }

                static var displayTitle: String {
                    return WMFLocalizedString("insert-media-image-size-settings-title", value: "Image size", comment: "Display ritle for image size setting")
                }

                var rawValue: String {
                    switch self {
                    case .default:
                        return "\(ImageSize.defaultWidth)x\(ImageSize.defaultHeight)px"
                    case .custom(let width, let height):
                        return "\(width)x\(height)px"
                    }
                }

                static var unitName = WMFLocalizedString("insert-media-image-size-settings-px-unit-name", value: "px", comment: "Image size unit name, abbreviation for 'pixels'")

                static var defaultWidth = 220
                static var defaultHeight = 124
            }

            init(wrapTextAroundImage: Bool = false, imagePosition: ImagePosition = .right, imageType: ImageType = .thumbnail, imageSize: ImageSize = .default) {
                self.wrapTextAroundImage = wrapTextAroundImage
                self.imagePosition = imagePosition
                self.imageType = imageType
                self.imageSize = imageSize
            }
        }

        init(caption: String?, alternativeText: String?, advanced: Advanced = Advanced()) {
            self.caption = caption
            self.alternativeText = alternativeText
            self.advanced = advanced
        }
    }

    var settings: Settings? {
        let captionTextView = textViewsGroupedByType[.caption]
        let alternativeTextTextView = textViewsGroupedByType[.alternativeText]
        let caption = captionTextView?.text.wmf_hasNonWhitespaceText ?? false ? captionTextView?.text : nil
        let alternativeText = alternativeTextTextView?.text.wmf_hasNonWhitespaceText ?? false ? alternativeTextTextView?.text : nil
        return Settings(caption: caption, alternativeText: alternativeText, advanced: insertMediaAdvancedSettingsViewController.advancedSettings)
    }

    var imageTitle: URL? {
        return searchResult.filePageURL ?? searchResult.imageInfo?.filePageURL
    }

    private lazy var imageView: InsertMediaSettingsImageView = {
        let imageView = InsertMediaSettingsImageView.wmf_viewFromClassNib()!
        imageView.image = image
        imageView.imageDescription = searchResult.imageDescription
        imageView.title = searchResult.displayTitle
        imageView.titleURL = imageTitle
        imageView.titleAction = { [weak self] url in
            self?.navigate(to: url, useSafari: false)
        }
        imageView.autoresizingMask = []
        return imageView
    }()

    private lazy var insertMediaAdvancedSettingsViewController = InsertMediaAdvancedSettingsViewController()

    private lazy var buttonView: InsertMediaSettingsButtonView = {
        let buttonView = InsertMediaSettingsButtonView.wmf_viewFromClassNib()!
        let isRTL = UIApplication.shared.wmf_isRTL
        buttonView.buttonTitle = InsertMediaAdvancedSettingsViewController.title
        buttonView.buttonAction = { [weak self] _ in
            guard let self = self else {
                return
            }
            self.insertMediaAdvancedSettingsViewController.apply(theme: self.theme)
            self.navigationController?.pushViewController(self.insertMediaAdvancedSettingsViewController, animated: true)
        }
        buttonView.autoresizingMask = []
        return buttonView
    }()

    private struct TextViewModel {
        let type: TextViewType
        let headerText: String
        let placeholder: String
        let footerText: String
        let learnMoreUrl: String

        init(type: TextViewType) {
            self.type = type
            switch type {
            case .caption:
                headerText = WMFLocalizedString("insert-media-caption-title", value: "Caption", comment: "Title for setting that allows users to add image captions")
                placeholder = WMFLocalizedString("insert-media-caption-caption-placeholder", value: "How does this image relate to the article?", comment: "Placeholder text for setting that allows users to add image captions")
                footerText = WMFLocalizedString("insert-media-caption-description", value: "Label that shows next to the item for all readers", comment: "Description for setting that allows users to add image captions")
                learnMoreUrl = "https://www.mediawiki.org/wiki/Wikimedia_Apps/iOS_Suggested_edits#Image_captions"
            case .alternativeText:
                headerText = WMFLocalizedString("insert-media-alternative-text-title", value: "Alternative text", comment: "Title for setting that allows users to add image alternative text")
                placeholder = WMFLocalizedString("insert-media-alternative-text-placeholder", value: "Describe this image", comment: "Placeholder text for setting that allows users to add image alternative text")
                footerText = WMFLocalizedString("insert-media-alternative-text-description", value: "Text description for readers who cannot see the image", comment: "Description for setting that allows users to add image alternative text")
                learnMoreUrl = "https://www.mediawiki.org/wiki/Wikimedia_Apps/iOS_Suggested_edits#Tips_for_creating_alt-text"
            }
        }
    }

    private enum TextViewType: Int, Hashable {
        case caption
        case alternativeText
    }

    private lazy var viewModels: [TextViewModel] = {
        let captionViewModel = TextViewModel(type: .caption)
        let alternativeTextViewModel = TextViewModel(type: .alternativeText)
        return [captionViewModel, alternativeTextViewModel]
    }()

    init(image: UIImage, searchResult: InsertMediaSearchResult, fromImageRecommendations: Bool = false, wikitext: String? = nil, articleURL: URL? = nil, sectionNumber: Int? = nil) {
        self.image = image
        self.searchResult = searchResult
        self.fromImageRecommendations = fromImageRecommendations
        self.wikitext = wikitext
        self.articleURL = articleURL
        self.sectionNumber = sectionNumber
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        scrollView = tableView
        super.viewDidLoad()
        navigationBar.isBarHidingEnabled = false
        tableView.dataSource = self
        view.wmf_addSubviewWithConstraintsToEdges(tableView)
        tableView.register(InsertMediaSettingsTextTableViewCell.wmf_classNib(), forCellReuseIdentifier: InsertMediaSettingsTextTableViewCell.identifier)
        tableView.separatorStyle = .none
        tableView.tableHeaderView = imageView
        tableView.tableFooterView = buttonView

        if fromImageRecommendations {
            title = WMFLocalizedString("insert-media-add-image-details-title", value: "Add image details", comment: "Title for add image details view")
            nextButton = UIBarButtonItem(title: WMFLocalizedString("next-action-title", value: "Next", comment: "Title for insert action indicating the user can go to the next step"), style: .done, target: self, action: #selector(insertMedia))
            nextButton?.tintColor = theme.colors.secondaryText
            navigationItem.rightBarButtonItem = nextButton
            navigationController?.navigationBar.topItem?.title = String()
            self.apply(theme: theme)
        }
    }

    @objc private func insertMedia(_ sender: UIBarButtonItem) {
        assert(fromImageRecommendations, "Should only be called from Image Recommendations")
        let searchResult = searchResult
        let wikitext: String
        switch settings {
        case nil:
            wikitext = "[[\(searchResult.fileTitle)]]"
        case let mediaSettings?:
            switch (mediaSettings.caption, mediaSettings.alternativeText) {
            case (let caption?, let alternativeText?):
                wikitext = """
                [[\(searchResult.fileTitle) | \(mediaSettings.advanced.imageType.rawValue) | \(mediaSettings.advanced.imageSize.rawValue) | \(mediaSettings.advanced.imagePosition.rawValue) | alt= \(alternativeText) | \(caption)]]
                """
            case (let caption?, nil):
                wikitext = """
                [[\(searchResult.fileTitle) | \(mediaSettings.advanced.imageType.rawValue) | \(mediaSettings.advanced.imageSize.rawValue) | \(mediaSettings.advanced.imagePosition.rawValue) | \(caption)]]
                """
            case (nil, let alternativeText?):
                wikitext = """
                [[\(searchResult.fileTitle) | \(mediaSettings.advanced.imageType.rawValue) | \(mediaSettings.advanced.imageSize.rawValue) | \(mediaSettings.advanced.imagePosition.rawValue) | alt= \(alternativeText)]]
                """
            default:
                wikitext = """
                [[\(searchResult.fileTitle) | \(mediaSettings.advanced.imageType.rawValue) | \(mediaSettings.advanced.imageSize.rawValue) | \(mediaSettings.advanced.imagePosition.rawValue)]]
                """
            }
        }
         didTapInsertMedia(with: wikitext)
    }

    func didTapInsertMedia(with imageWikitext: String) {
        guard let wikitext else {
            return
        }
        do {
            let wikitextWithImage = try WKWikitextUtils.insertImageWikitextIntoArticleWikitextAfterTemplates(imageWikitext: imageWikitext, into: wikitext)
            goToEditPreview(with: wikitextWithImage)
        } catch let error {
            print("Error preparing wikitext\(error)")
        }

    }

    func goToEditPreview(with wikitext: String) {
        guard let articleURL else {
            print("Error")
            return
        }

        let editPreviewViewController = EditPreviewViewController(pageURL: articleURL)
        editPreviewViewController.theme = theme
        editPreviewViewController.sectionID = sectionNumber
        editPreviewViewController.languageCode = articleURL.wmf_languageCode
        editPreviewViewController.wikitext = wikitext
        editPreviewViewController.delegate = self

        navigationController?.pushViewController(editPreviewViewController, animated: true)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        UIAccessibility.post(notification: .screenChanged, argument: nil)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let headerView = tableView.tableHeaderView else {
            return
        }
        let height = headerView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
        guard headerView.frame.size.height != height else {
            return
        }
        headerView.frame.size.height = height
        tableView.tableHeaderView = headerView
    }

    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        super.willTransition(to: newCollection, with: coordinator)
        guard textViewHeightDelta != nil else {
            return
        }
        UIView.performWithoutAnimation {
            self.textViewHeightDelta = nil
            self.tableView.beginUpdates()
            self.tableView.endUpdates()
        }
    }

    // MARK: - Themeable

    override func apply(theme: Theme) {
        super.apply(theme: theme)
        guard viewIfLoaded != nil else {
            return
        }
        view.backgroundColor = theme.colors.paperBackground
        tableView.backgroundColor = view.backgroundColor
        imageView.apply(theme: theme)
        buttonView.apply(theme: theme)
        tableView.reloadData()
    }
}

// MARK: - Table view data source

extension InsertMediaSettingsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: InsertMediaSettingsTextTableViewCell.identifier, for: indexPath) as? InsertMediaSettingsTextTableViewCell else {
            return UITableViewCell()
        }
        let viewModel = viewModels[indexPath.row]
        cell.headerText = viewModel.headerText
        textViewsGroupedByType[viewModel.type] = cell.textViewConfigured(with: self, placeholder: viewModel.placeholder, placeholderDelegate: self, clearDelegate: self, tag: indexPath.row)
        cell.footerText = viewModel.footerText
        cell.selectionStyle = .none
        cell.apply(theme: theme)
        cell.learnMoreURL = URL(string: viewModel.learnMoreUrl)
        cell.learnMoreAction = { [weak self] url in
            guard let self = self else {
                return
            }
            self.navigate(to: url, useSafari: false)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard
            let cell = tableView.visibleCells[safeIndex: indexPath.row] as? InsertMediaSettingsTextTableViewCell,
            let textViewHeightDelta = textViewHeightDelta,
            textViewHeightDelta.row == indexPath.row
        else {
            return UITableView.automaticDimension
        }
        return cell.frame.size.height + textViewHeightDelta.value
    }
    
}

extension InsertMediaSettingsViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updateTextViewHeight(textView)

        let point = textView.convert(CGPoint.zero, to: tableView)
        if let indexPath = tableView.indexPathForRow(at: point), indexPath.row == 0 {

            let isTextViewEmpty = textView.text.isEmpty
            nextButton?.tintColor = isTextViewEmpty ? theme.colors.secondaryText : theme.colors.link
        }
    }

    private func updateTextViewHeight(_ textView: UITextView) {
        let oldHeight = textView.frame.size.height
        let newHeight = textView.systemLayoutSizeFitting(textView.frame.size).height
        guard oldHeight != newHeight else {
            return
        }
        textViewHeightDelta = (newHeight - oldHeight, textView.tag)
        UIView.performWithoutAnimation {
            textView.frame.size.height = newHeight
            tableView.beginUpdates()
            tableView.endUpdates()
        }
    }
}

extension InsertMediaSettingsViewController: ThemeableTextViewPlaceholderDelegate {
    func themeableTextViewPlaceholderDidHide(_ themeableTextView: UITextView, isPlaceholderHidden: Bool) {
        updateTextViewHeight(themeableTextView)
    }
}

extension InsertMediaSettingsViewController: ThemeableTextViewClearDelegate {
    func themeableTextViewDidClear(_ themeableTextView: UITextView) {
        updateTextViewHeight(themeableTextView)
    }
}

extension InsertMediaSettingsViewController: EditPreviewViewControllerDelegate {
    func editPreviewViewControllerDidTapNext(_ editPreviewViewController: EditPreviewViewController) {
        print("Go to Edit Save View Controller")
    }

}

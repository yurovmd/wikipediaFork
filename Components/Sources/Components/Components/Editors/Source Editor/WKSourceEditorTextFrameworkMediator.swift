import Foundation
import UIKit
import ComponentsObjC

/// This class facilitates communication between WKSourceEditorViewController and the underlying TextKit (1 and 2) frameworks, so that WKSourceEditorViewController is unaware of which framework is used.
/// When we need to drop TextKit 1, the goal is for all the adjustments to be in this one class

fileprivate var needsTextKit2: Bool {
    if #available(iOS 17, *) {
        return true
    } else {
        return false
    }
}

class WKSourceEditorTextView: UITextView {
    override func accessibilityActivate() -> Bool {

        UIAccessibility.post(notification: .announcement, argument: WKSourceEditorLocalizedStrings.current.wikitextEditorLoadingAccessibility)
        
        return super.accessibilityActivate()
    }
}

@objc final class WKSourceEditorSelectionState: NSObject {
    let isBold: Bool
    let isItalics: Bool
    let isHorizontalTemplate: Bool
    let isHorizontalReference: Bool
    let isBulletSingleList: Bool
    let isBulletMultipleList: Bool
    let isNumberSingleList: Bool
    let isNumberMultipleList: Bool
    let isHeading: Bool
    let isSubheading1: Bool
    let isSubheading2: Bool
    let isSubheading3: Bool
    let isSubheading4: Bool
    let isStrikethrough: Bool
    let isUnderline: Bool
    let isSubscript: Bool
    let isSuperscript: Bool
    let isSimpleLink: Bool
    let isLinkWithNestedLink: Bool
    let isComment: Bool

    init(isBold: Bool, isItalics: Bool, isHorizontalTemplate: Bool, isHorizontalReference: Bool, isBulletSingleList: Bool, isBulletMultipleList: Bool, isNumberSingleList: Bool, isNumberMultipleList: Bool, isHeading: Bool, isSubheading1: Bool, isSubheading2: Bool, isSubheading3: Bool, isSubheading4: Bool, isStrikethrough: Bool, isUnderline: Bool, isSubscript: Bool, isSuperscript: Bool, isSimpleLink: Bool, isLinkWithNestedLink: Bool, isComment: Bool) {
        self.isBold = isBold
        self.isItalics = isItalics
        self.isHorizontalTemplate = isHorizontalTemplate
        self.isHorizontalReference = isHorizontalReference
        self.isBulletSingleList = isBulletSingleList
        self.isBulletMultipleList = isBulletMultipleList
        self.isNumberSingleList = isNumberSingleList
        self.isNumberMultipleList = isNumberMultipleList
        self.isHeading = isHeading
        self.isSubheading1 = isSubheading1
        self.isSubheading2 = isSubheading2
        self.isSubheading3 = isSubheading3
        self.isSubheading4 = isSubheading4
        self.isStrikethrough = isStrikethrough
        self.isUnderline = isUnderline
        self.isSubscript = isSubscript
        self.isSuperscript = isSuperscript
        self.isSimpleLink = isSimpleLink
        self.isLinkWithNestedLink = isLinkWithNestedLink
        self.isComment = isComment
    }

}

protocol WKSourceEditorFindAndReplaceScrollDelegate: NSObject {
    func scrollToCurrentMatch()
}

final class WKSourceEditorTextFrameworkMediator: NSObject {
    
    private let viewModel: WKSourceEditorViewModel
    weak var delegate: WKSourceEditorFindAndReplaceScrollDelegate?
    
    private let textKit1Storage: WKSourceEditorTextStorage?
    private let textKit2Storage: NSTextContentStorage?
    
    let textView: UITextView
    private(set) var formatters: [WKSourceEditorFormatter] = []
    private(set) var boldItalicsFormatter: WKSourceEditorFormatterBoldItalics?
    private(set) var templateFormatter: WKSourceEditorFormatterTemplate?
    private(set) var referenceFormatter: WKSourceEditorFormatterReference?
    private(set) var listFormatter: WKSourceEditorFormatterList?
    private(set) var headingFormatter: WKSourceEditorFormatterHeading?
    private(set) var strikethroughFormatter: WKSourceEditorFormatterStrikethrough?
    private(set) var underlineFormatter: WKSourceEditorFormatterUnderline?
    private(set) var subscriptFormatter: WKSourceEditorFormatterSubscript?
    private(set) var superscriptFormatter: WKSourceEditorFormatterSuperscript?
    private(set) var linkFormatter: WKSourceEditorFormatterLink?
    private(set) var commentFormatter: WKSourceEditorFormatterComment?
    private(set) var findAndReplaceFormatter: WKSourceEditorFormatterFindAndReplace?

    var isSyntaxHighlightingEnabled: Bool = true {
        didSet {
            updateColorsAndFonts()
        }
    }
    
    
    init(viewModel: WKSourceEditorViewModel) {

        self.viewModel = viewModel
        
        let textView: UITextView
        if needsTextKit2 {
            if #available(iOS 16, *) {
                textView = WKSourceEditorTextView(usingTextLayoutManager: true)
                textKit2Storage = textView.textLayoutManager?.textContentManager as? NSTextContentStorage
            } else {
                fatalError("iOS 15 cannot handle TextKit2")
            }
            textKit1Storage = nil
        } else {
            textKit1Storage = WKSourceEditorTextStorage()
            
            let layoutManager = NSLayoutManager()
            let container = NSTextContainer()

            container.widthTracksTextView = true

            layoutManager.addTextContainer(container)
            textKit1Storage?.addLayoutManager(layoutManager)

            textView = WKSourceEditorTextView(frame: .zero, textContainer: container)
            textKit2Storage = nil
        }
        
        self.textView = textView
        
        textView.textContainerInset = .init(top: 16, left: 8, bottom: 16, right: 8)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.keyboardDismissMode = .interactive
        textView.accessibilityIdentifier = WKSourceEditorAccessibilityIdentifiers.current?.textView
        
        // Note: There is improved selection performance / fixed console constraint errors with these next two lines. Leaving them commented out for now.
        
        // textView.autocorrectionType = .no
        // textView.spellCheckingType = .no
        
        super.init()
        
        if needsTextKit2 {
            textKit2Storage?.delegate = self
        } else {
            textKit1Storage?.storageDelegate = self
        }
    }

    // MARK: Internal
    
    func updateColorsAndFonts() {
        
        let colors = self.colors
        let fonts = self.fonts
        
        let templateFormatter = WKSourceEditorFormatterTemplate(colors: colors, fonts: fonts)
        let referenceFormatter = WKSourceEditorFormatterReference(colors: colors, fonts: fonts)
        let boldItalicsFormatter = WKSourceEditorFormatterBoldItalics(colors: colors, fonts: fonts)
        let listFormatter = WKSourceEditorFormatterList(colors: colors, fonts: fonts)
        let headingFormatter = WKSourceEditorFormatterHeading(colors: colors, fonts: fonts)
        let strikethroughFormatter = WKSourceEditorFormatterStrikethrough(colors: colors, fonts: fonts)
        let underlineFormatter = WKSourceEditorFormatterUnderline(colors: colors, fonts: fonts)
        let subscriptFormatter = WKSourceEditorFormatterSubscript(colors: colors, fonts: fonts)
        let superscriptFormatter = WKSourceEditorFormatterSuperscript(colors: colors, fonts: fonts)
        let linkFormatter = WKSourceEditorFormatterLink(colors: colors, fonts: fonts)
        let commentFormatter = WKSourceEditorFormatterComment(colors: colors, fonts: fonts)
        let findAndReplaceFormatter = WKSourceEditorFormatterFindAndReplace(colors: colors, fonts: fonts)
        
        self.formatters = [WKSourceEditorFormatterBase(colors: colors, fonts: fonts, textAlignment: viewModel.textAlignment),
            templateFormatter,
            boldItalicsFormatter,
            referenceFormatter,
            listFormatter,
            headingFormatter,
            strikethroughFormatter,
            superscriptFormatter,
            subscriptFormatter,
            underlineFormatter,
            linkFormatter,
            commentFormatter,
            findAndReplaceFormatter]

        self.boldItalicsFormatter = boldItalicsFormatter
        self.templateFormatter = templateFormatter
        self.referenceFormatter = referenceFormatter
        self.listFormatter = listFormatter
        self.headingFormatter = headingFormatter
        self.strikethroughFormatter = strikethroughFormatter
        self.subscriptFormatter = subscriptFormatter
        self.superscriptFormatter = superscriptFormatter
        self.underlineFormatter = underlineFormatter
        self.linkFormatter = linkFormatter
        self.commentFormatter = commentFormatter
        self.findAndReplaceFormatter = findAndReplaceFormatter

        if needsTextKit2 {
            if #available(iOS 16.0, *) {
                let textContentManager = textView.textLayoutManager?.textContentManager
                textContentManager?.performEditingTransaction({
                    
                    guard let attributedString = (textContentManager as? NSTextContentStorage)?.textStorage else {
                        return
                    }
                    
                    let colors = self.colors
                    let fonts = self.fonts
                    let range = NSRange(location: 0, length: attributedString.length)
                    for formatter in formatters {
                        formatter.update(colors, in: attributedString, in: range)
                        formatter.update(fonts, in: attributedString, in: range)
                    }
                })
            }
        } else {
            textKit1Storage?.syntaxHighlightProcessingEnabled = false
            textKit1Storage?.updateColorsAndFonts()
            textKit1Storage?.syntaxHighlightProcessingEnabled = true
            
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(debouncedEnsureLayoutTextkit1), object: nil)
            perform(#selector(debouncedEnsureLayoutTextkit1), with: nil, afterDelay: 0.1)
        }
    }
    
    func selectionState(selectedDocumentRange: NSRange) -> WKSourceEditorSelectionState {
        
        if needsTextKit2 {
            guard let textKit2Data = textkit2SelectionData(selectedDocumentRange: selectedDocumentRange) else {

                return WKSourceEditorSelectionState(isBold: false, isItalics: false, isHorizontalTemplate: false, isHorizontalReference: false, isBulletSingleList: false, isBulletMultipleList: false, isNumberSingleList: false, isNumberMultipleList: false, isHeading: false, isSubheading1: false, isSubheading2: false, isSubheading3: false, isSubheading4: false, isStrikethrough: false, isUnderline: false, isSubscript: false, isSuperscript: false, isSimpleLink: false, isLinkWithNestedLink: false, isComment: false)

            }
            
            let isBold = boldItalicsFormatter?.attributedString(textKit2Data.paragraphAttributedString, isBoldIn: textKit2Data.paragraphSelectedRange) ?? false
            let isItalics = boldItalicsFormatter?.attributedString(textKit2Data.paragraphAttributedString, isItalicsIn: textKit2Data.paragraphSelectedRange) ?? false
            let isHorizontalTemplate = templateFormatter?.attributedString(textKit2Data.paragraphAttributedString, isHorizontalTemplateIn: textKit2Data.paragraphSelectedRange) ?? false
            let isHorizontalReference = referenceFormatter?.attributedString(textKit2Data.paragraphAttributedString, isHorizontalReferenceIn: textKit2Data.paragraphSelectedRange) ?? false
            let isBulletSingleList = listFormatter?.attributedString(textKit2Data.paragraphAttributedString, isBulletSingleIn: textKit2Data.paragraphSelectedRange) ?? false
            let isBulletMultipleList = listFormatter?.attributedString(textKit2Data.paragraphAttributedString, isBulletMultipleIn: textKit2Data.paragraphSelectedRange) ?? false
            let isNumberSingleList = listFormatter?.attributedString(textKit2Data.paragraphAttributedString, isNumberSingleIn: textKit2Data.paragraphSelectedRange) ?? false
            let isNumberMultipleList = listFormatter?.attributedString(textKit2Data.paragraphAttributedString, isNumberMultipleIn: textKit2Data.paragraphSelectedRange) ?? false
            let isHeading = headingFormatter?.attributedString(textKit2Data.paragraphAttributedString, isHeadingIn: textKit2Data.paragraphSelectedRange) ?? false
            let isSubheading1 = headingFormatter?.attributedString(textKit2Data.paragraphAttributedString, isSubheading1In: textKit2Data.paragraphSelectedRange) ?? false
            let isSubheading2 = headingFormatter?.attributedString(textKit2Data.paragraphAttributedString, isSubheading2In: textKit2Data.paragraphSelectedRange) ?? false
            let isSubheading3 = headingFormatter?.attributedString(textKit2Data.paragraphAttributedString, isSubheading3In: textKit2Data.paragraphSelectedRange) ?? false
            let isSubheading4 = headingFormatter?.attributedString(textKit2Data.paragraphAttributedString, isSubheading4In: textKit2Data.paragraphSelectedRange) ?? false
            let isStrikethrough = strikethroughFormatter?.attributedString(textKit2Data.paragraphAttributedString, isStrikethroughIn: textKit2Data.paragraphSelectedRange) ?? false
            let isSubscript = subscriptFormatter?.attributedString(textKit2Data.paragraphAttributedString, isSubscriptIn: textKit2Data.paragraphSelectedRange) ?? false
            let isSuperscript = superscriptFormatter?.attributedString(textKit2Data.paragraphAttributedString, isSuperscriptIn: textKit2Data.paragraphSelectedRange) ?? false
            let isUnderline = underlineFormatter?.attributedString(textKit2Data.paragraphAttributedString, isUnderlineIn: textKit2Data.paragraphSelectedRange) ?? false
            let isSimpleLink = linkFormatter?.attributedString(textKit2Data.paragraphAttributedString, isSimpleLinkIn: textKit2Data.paragraphSelectedRange) ?? false
            let isLinkWithNestedLink = linkFormatter?.attributedString(textKit2Data.paragraphAttributedString, isLinkWithNestedLinkIn: textKit2Data.paragraphSelectedRange) ?? false
            let isComment = commentFormatter?.attributedString(textKit2Data.paragraphAttributedString, isCommentIn: textKit2Data.paragraphSelectedRange) ?? false

            return WKSourceEditorSelectionState(isBold: isBold, isItalics: isItalics, isHorizontalTemplate: isHorizontalTemplate, isHorizontalReference: isHorizontalReference, isBulletSingleList: isBulletSingleList, isBulletMultipleList: isBulletMultipleList, isNumberSingleList: isNumberSingleList, isNumberMultipleList: isNumberMultipleList, isHeading: isHeading, isSubheading1: isSubheading1, isSubheading2: isSubheading2, isSubheading3: isSubheading3, isSubheading4: isSubheading4, isStrikethrough: isStrikethrough, isUnderline: isUnderline, isSubscript: isSubscript, isSuperscript: isSuperscript, isSimpleLink: isSimpleLink, isLinkWithNestedLink: isLinkWithNestedLink, isComment: isComment)
        } else {
            guard let textKit1Storage else {
                return WKSourceEditorSelectionState(isBold: false, isItalics: false, isHorizontalTemplate: false, isHorizontalReference: false, isBulletSingleList: false, isBulletMultipleList: false, isNumberSingleList: false, isNumberMultipleList: false, isHeading: false, isSubheading1: false, isSubheading2: false, isSubheading3: false, isSubheading4: false, isStrikethrough: false, isUnderline: false, isSubscript: false, isSuperscript: false, isSimpleLink: false, isLinkWithNestedLink: false, isComment: false)
        }

            let isBold = boldItalicsFormatter?.attributedString(textKit1Storage, isBoldIn: selectedDocumentRange) ?? false
            let isItalics = boldItalicsFormatter?.attributedString(textKit1Storage, isItalicsIn: selectedDocumentRange) ?? false
            let isHorizontalTemplate = templateFormatter?.attributedString(textKit1Storage, isHorizontalTemplateIn: selectedDocumentRange) ?? false
            let isHorizontalReference = referenceFormatter?.attributedString(textKit1Storage, isHorizontalReferenceIn: selectedDocumentRange) ?? false
            let isBulletSingleList = listFormatter?.attributedString(textKit1Storage, isBulletSingleIn: selectedDocumentRange) ?? false
            let isBulletMultipleList = listFormatter?.attributedString(textKit1Storage, isBulletMultipleIn: selectedDocumentRange) ?? false
            let isNumberSingleList = listFormatter?.attributedString(textKit1Storage, isNumberSingleIn: selectedDocumentRange) ?? false
            let isNumberMultipleList = listFormatter?.attributedString(textKit1Storage, isNumberMultipleIn: selectedDocumentRange) ?? false
            let isHeading = headingFormatter?.attributedString(textKit1Storage, isHeadingIn: selectedDocumentRange) ?? false
            let isSubheading1 = headingFormatter?.attributedString(textKit1Storage, isSubheading1In: selectedDocumentRange) ?? false
            let isSubheading2 = headingFormatter?.attributedString(textKit1Storage, isSubheading2In: selectedDocumentRange) ?? false
            let isSubheading3 = headingFormatter?.attributedString(textKit1Storage, isSubheading3In: selectedDocumentRange) ?? false
            let isSubheading4 = headingFormatter?.attributedString(textKit1Storage, isSubheading4In: selectedDocumentRange) ?? false
            let isStrikethrough = strikethroughFormatter?.attributedString(textKit1Storage, isStrikethroughIn: selectedDocumentRange) ?? false
            let isSubscript = subscriptFormatter?.attributedString(textKit1Storage, isSubscriptIn: selectedDocumentRange) ?? false
            let isSuperscript = superscriptFormatter?.attributedString(textKit1Storage, isSuperscriptIn: selectedDocumentRange) ?? false
            let isUnderline = underlineFormatter?.attributedString(textKit1Storage, isUnderlineIn: selectedDocumentRange) ?? false
            let isSimpleLink = linkFormatter?.attributedString(textKit1Storage, isSimpleLinkIn: selectedDocumentRange) ?? false
            let isLinkWithNestedLink = linkFormatter?.attributedString(textKit1Storage, isLinkWithNestedLinkIn: selectedDocumentRange) ?? false
            let isComment = commentFormatter?.attributedString(textKit1Storage, isCommentIn: selectedDocumentRange) ?? false

            return WKSourceEditorSelectionState(isBold: isBold, isItalics: isItalics, isHorizontalTemplate: isHorizontalTemplate, isHorizontalReference: isHorizontalReference, isBulletSingleList: isBulletSingleList, isBulletMultipleList: isBulletMultipleList, isNumberSingleList: isNumberSingleList, isNumberMultipleList: isNumberMultipleList,  isHeading: isHeading, isSubheading1: isSubheading1, isSubheading2: isSubheading2, isSubheading3: isSubheading3, isSubheading4: isSubheading4, isStrikethrough: isStrikethrough, isUnderline: isUnderline, isSubscript: isSubscript, isSuperscript: isSuperscript, isSimpleLink: isSimpleLink, isLinkWithNestedLink: isLinkWithNestedLink, isComment: isComment)
        }
    }
    
    func findStart(text: String) {
        
        guard !text.isEmpty else {
            return
        }
        
        guard let fullAttributedString else {
            return
        }

        if needsTextKit2 {
            if #available(iOS 16.0, *) {
                textView.textLayoutManager?.textContentManager?.performEditingTransaction {
                    self.findAndReplaceFormatter?.startMatchSession(withFullAttributedString: fullAttributedString, searchText: text)
                }
            }
        } else {

            textKit1Storage?.syntaxHighlightProcessingEnabled = false
            findAndReplaceFormatter?.startMatchSession(withFullAttributedString: fullAttributedString, searchText: text)
            textKit1Storage?.syntaxHighlightProcessingEnabled = true
        }
        
        findNext(afterRange: textView.selectedRange)

        self.delegate?.scrollToCurrentMatch()
    }
    
    func findNext(afterRange: NSRange?) {
        guard let fullAttributedString else {
            return
        }
        
        let afterRangeValue: NSValue?
        if let afterRange {
            afterRangeValue = NSValue(range: afterRange)
        } else {
            afterRangeValue = nil
        }
        if needsTextKit2 {
            if #available(iOS 16.0, *) {
                
                textView.textLayoutManager?.textContentManager?.performEditingTransaction {
                    self.findAndReplaceFormatter?.highlightNextMatch(inFullAttributedString: fullAttributedString, afterRangeValue: afterRangeValue)

                }
            }
        } else {
            textKit1Storage?.syntaxHighlightProcessingEnabled = false
            findAndReplaceFormatter?.highlightNextMatch(inFullAttributedString: fullAttributedString, afterRangeValue: afterRangeValue)
            textKit1Storage?.syntaxHighlightProcessingEnabled = true
        }
        
        self.delegate?.scrollToCurrentMatch()
    }
    
    func findPrevious() {
        guard let fullAttributedString else {
            return
        }
        
        if needsTextKit2 {
            if #available(iOS 16.0, *) {
                textView.textLayoutManager?.textContentManager?.performEditingTransaction {
                    self.findAndReplaceFormatter?.highlightPreviousMatch(inFullAttributedString: fullAttributedString)

                }
            }
        } else {
            textKit1Storage?.syntaxHighlightProcessingEnabled = false
            findAndReplaceFormatter?.highlightPreviousMatch(inFullAttributedString: fullAttributedString)
            textKit1Storage?.syntaxHighlightProcessingEnabled = true
        }
        
        self.delegate?.scrollToCurrentMatch()
    }
    
    func replaceSingle(replaceText: String) {
        guard let fullAttributedString else {
            return
        }
        
        if needsTextKit2 {
            if #available(iOS 16.0, *) {
                textView.textLayoutManager?.textContentManager?.performEditingTransaction {
                    self.findAndReplaceFormatter?.replaceSingleMatch(inFullAttributedString: fullAttributedString, withReplaceText: replaceText, textView: textView)

                }
            }
        } else {
            textKit1Storage?.syntaxHighlightProcessingEnabled = false
            self.findAndReplaceFormatter?.replaceSingleMatch(inFullAttributedString: fullAttributedString, withReplaceText: replaceText, textView: textView)
            textKit1Storage?.syntaxHighlightProcessingEnabled = true
        }
        
        self.delegate?.scrollToCurrentMatch()
    }
    
    func replaceAll(replaceText: String) {
        guard let fullAttributedString else {
            return
        }
        
        if needsTextKit2 {
            if #available(iOS 16.0, *) {
                textView.textLayoutManager?.textContentManager?.performEditingTransaction {
                    self.findAndReplaceFormatter?.replaceAllMatches(inFullAttributedString: fullAttributedString, withReplaceText: replaceText, textView: textView)

                }
            }
        } else {
            textKit1Storage?.syntaxHighlightProcessingEnabled = false
            self.findAndReplaceFormatter?.replaceAllMatches(inFullAttributedString: fullAttributedString, withReplaceText: replaceText, textView: textView)
            textKit1Storage?.syntaxHighlightProcessingEnabled = true
        }
        
        self.delegate?.scrollToCurrentMatch()
    }
    
    func findReset() {
        guard let fullAttributedString else {
            return
        }
        
        if needsTextKit2 {
            
            if #available(iOS 16.0, *) {
                textView.textLayoutManager?.textContentManager?.performEditingTransaction {
                    self.findAndReplaceFormatter?.endMatchSession(withFullAttributedString: fullAttributedString)
                }
            }
            
        } else {
            self.findAndReplaceFormatter?.endMatchSession(withFullAttributedString: fullAttributedString)
        }
        
    }
    
    // MARK: Private
    
    @objc private func debouncedEnsureLayoutTextkit1() {
        
        guard !needsTextKit2 else {
            return
        }
        
       textView.layoutManager.ensureLayout(forCharacterRange: NSRange(location: 0, length: textView.attributedText.length))
    }
    
    private func textkit2SelectionData(selectedDocumentRange: NSRange) -> (paragraphAttributedString: NSMutableAttributedString, paragraphSelectedRange: NSRange)? {
        guard needsTextKit2 else {
            return nil
        }
        
        // Pulling the paragraph element that contains the selection will have an attributed string with the populated attributes
        if #available(iOS 16.0, *) {
            guard let textKit2Storage,
                  let layoutManager = textView.textLayoutManager,
                  let selectedDocumentTextRange = textKit2Storage.textRangeForDocumentNSRange(selectedDocumentRange),
                  let paragraphElement = layoutManager.textLayoutFragment(for: selectedDocumentTextRange.location)?.textElement as? NSTextParagraph,
                  let paragraphRange = paragraphElement.elementRange else {
                return nil
            }
            
            guard let selectedParagraphRange = textKit2Storage.offsetDocumentNSRangeWithParagraphRange(documentNSRange: selectedDocumentRange, paragraphRange: paragraphRange) else {
                return nil
            }
            
            return (NSMutableAttributedString(attributedString: paragraphElement.attributedString), selectedParagraphRange)
        }
        
        return nil
    }
    
    private var fullAttributedString: NSMutableAttributedString? {
        if needsTextKit2 {
            if #available(iOS 16.0, *) {
                let textContentManager = textView.textLayoutManager?.textContentManager
                guard let attributedString = (textContentManager as? NSTextContentStorage)?.textStorage else {
                    return nil
                }

                return attributedString
            }
        }
        
        return textKit1Storage
    }
}

// MARK: WKSourceEditorStorageDelegate

extension WKSourceEditorTextFrameworkMediator: WKSourceEditorStorageDelegate {
    
    var colors: WKSourceEditorColors {
        let colors = WKSourceEditorColors()
        colors.baseForegroundColor = WKAppEnvironment.current.theme.text
        colors.orangeForegroundColor = isSyntaxHighlightingEnabled ? WKAppEnvironment.current.theme.editorOrange : WKAppEnvironment.current.theme.text
        colors.purpleForegroundColor = isSyntaxHighlightingEnabled ?  WKAppEnvironment.current.theme.editorPurple : WKAppEnvironment.current.theme.text
        colors.greenForegroundColor = isSyntaxHighlightingEnabled ?  WKAppEnvironment.current.theme.editorGreen : WKAppEnvironment.current.theme.text
        colors.blueForegroundColor = isSyntaxHighlightingEnabled ? WKAppEnvironment.current.theme.editorBlue : WKAppEnvironment.current.theme.text
        colors.grayForegroundColor = isSyntaxHighlightingEnabled ?  WKAppEnvironment.current.theme.editorGray : WKAppEnvironment.current.theme.text
        colors.matchForegroundColor = WKAppEnvironment.current.theme.editorMatchForeground
        colors.matchBackgroundColor = WKAppEnvironment.current.theme.editorMatchBackground
        colors.selectedMatchBackgroundColor = WKAppEnvironment.current.theme.editorSelectedMatchBackground
        colors.replacedMatchBackgroundColor = WKAppEnvironment.current.theme.editorReplacedMatchBackground
        return colors
    }
    
    var fonts: WKSourceEditorFonts {
        let fonts = WKSourceEditorFonts()
        let traitCollection = UITraitCollection(preferredContentSizeCategory: WKAppEnvironment.current.articleAndEditorTextSize)
        let baseFont = WKFont.for(.body, compatibleWith: traitCollection)
        fonts.baseFont = baseFont
        
        fonts.boldFont = isSyntaxHighlightingEnabled ? WKFont.for(.boldBody, compatibleWith: traitCollection) : baseFont
        fonts.italicsFont = isSyntaxHighlightingEnabled ? WKFont.for(.italicsBody, compatibleWith: traitCollection) : baseFont
        fonts.boldItalicsFont = isSyntaxHighlightingEnabled ? WKFont.for(.boldItalicsBody, compatibleWith: traitCollection) : baseFont
        fonts.headingFont = isSyntaxHighlightingEnabled ? WKFont.for(.editorHeading, compatibleWith: traitCollection) : baseFont
        fonts.subheading1Font = isSyntaxHighlightingEnabled ? WKFont.for(.editorSubheading1, compatibleWith: traitCollection) : baseFont
        fonts.subheading2Font = isSyntaxHighlightingEnabled ? WKFont.for(.editorSubheading2, compatibleWith: traitCollection) : baseFont
        fonts.subheading3Font = isSyntaxHighlightingEnabled ? WKFont.for(.editorSubheading3, compatibleWith: traitCollection) : baseFont
        fonts.subheading4Font = isSyntaxHighlightingEnabled ? WKFont.for(.editorSubheading4, compatibleWith: traitCollection) : baseFont
        return fonts
    }
}

// MARK: NSTextContentStorageDelegate

 extension WKSourceEditorTextFrameworkMediator: NSTextContentStorageDelegate {

    func textContentStorage(_ textContentStorage: NSTextContentStorage, textParagraphWith range: NSRange) -> NSTextParagraph? {
        
        guard needsTextKit2 else {
            return nil
        }
        
        guard let originalText = textContentStorage.textStorage?.attributedSubstring(from: range),
              originalText.length > 0 else {
            return nil
        }
        let attributedString = NSMutableAttributedString(attributedString: originalText)
        let paragraphRange = NSRange(location: 0, length: originalText.length)
        
        for formatter in formatters {
            formatter.addSyntaxHighlighting(to: attributedString, in: paragraphRange)
        }
        
        return NSTextParagraph(attributedString: attributedString)
    }
}

// MARK: NSTextContentStorage Extensions

fileprivate extension NSTextContentStorage {
    func textRangeForDocumentNSRange(_ documentNSRange: NSRange) -> NSTextRange? {
        guard let start = location(documentRange.location, offsetBy: documentNSRange.location),
                let end = location(start, offsetBy: documentNSRange.length) else {
            return nil
        }
        
        return NSTextRange(location: start, end: end)
    }
    
    func offsetDocumentNSRangeWithParagraphRange(documentNSRange: NSRange, paragraphRange: NSTextRange) -> NSRange? {
        let startOffset = offset(from: documentRange.location, to: paragraphRange.location)
        let newNSRange = NSRange(location: documentNSRange.location - startOffset, length: documentNSRange.length)
        
        guard newNSRange.location >= 0 else {
            return nil
        }
        
        return newNSRange
    }
}

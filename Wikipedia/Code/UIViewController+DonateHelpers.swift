import Foundation
import WMF
import Components
import WKData
import PassKit

@objc enum DonateSource: Int {
    case articleCampaignModal
    case settings
}

@objc extension UIViewController {
    
    func canOfferNativeDonateForm(countryCode: String, currencyCode: String, languageCode: String, bannerID: String?, appVersion: String?) -> Bool {
        
        // Hide native Apple Pay path for users with a CN region setting
        // https://phabricator.wikimedia.org/T352180
        guard countryCode != "CN" else {
            return false
        }
        
        return nativeDonateFormViewModel(countryCode: countryCode, currencyCode: currencyCode, languageCode: languageCode, bannerID: bannerID, appVersion: appVersion, loggingDelegate: nil) != nil
    }
    
    private func nativeDonateFormViewModel(countryCode: String, currencyCode: String, languageCode: String, bannerID: String?, appVersion: String?, loggingDelegate: WKDonateLoggingDelegate?) -> WKDonateViewModel? {
        
        let donateDataController = WKDonateDataController()
        let donateData = donateDataController.loadConfigs()
        
        guard let donateConfig = donateData.donateConfig,
              let paymentMethods = donateData.paymentMethods else {
            return nil
        }
        
        guard PKPaymentAuthorizationController.canMakePayments(),
              PKPaymentAuthorizationController.canMakePayments(usingNetworks: paymentMethods.applePayPaymentNetworks, capabilities: .capability3DS) else {
            return nil
        }
        
        let formatter = NumberFormatter.wkCurrencyFormatter
        formatter.currencyCode = currencyCode
        
        guard let merchantID = Bundle.main.wmf_merchantID() else {
            return nil
        }
        
        guard let transactionFee = donateConfig.transactionFee(for: currencyCode),
              let transactionFeeString = formatter.string(from: transactionFee as NSNumber),
            let minimumValue = donateConfig.currencyMinimumDonation[currencyCode],
              let minimumString = formatter.string(from: minimumValue as NSNumber) else {
            return nil
        }
        
        var maximumString: String?
        if let maximumValue = donateConfig.currencyMaximumDonation[currencyCode] {
            maximumString = formatter.string(from: maximumValue as NSNumber)
        }
        
        let donate = WMFLocalizedString("donate-title", value: "Select an amount", comment: "Title for donate form.")
        let done = CommonStrings.doneTitle
        
        let transactionFeeFormat = WMFLocalizedString("donate-transaction-fee-opt-in-text", value: "I’ll generously add %1$@ to cover the transaction fees so you can keep 100%% of my donation.", comment: "Transaction fee checkbox on donate form. Checking it adds transaction fee to donation amount. Parameters: * %1$@ - transaction fee amount. Please leave %% unchanged for proper formatting.")
        let transactionFeeOptIn = String.localizedStringWithFormat(transactionFeeFormat, transactionFeeString)
        
        let minimumFormat = WMFLocalizedString("donate-minimum-error-text", value: "Please select an amount (minimum %1$@ %2$@).", comment: "Error text displayed when user enters donation amount below the allowed minimum. Parameters: * %1$@ - the minimum amount allowed, %2$@ - the currency code. (For example, '$1 USD')")
        let minimum = String.localizedStringWithFormat(minimumFormat, minimumString, currencyCode)
        
        var maximum: String?
        if let maximumString {
            let maximumFormat = WMFLocalizedString("donate-maximum-error-text", value: "We cannot accept donations greater than %1$@ %2$@ through our website. Please contact our major gifts staff at benefactors@wikimedia.org.", comment: "Error text displayed when user enters donation amount above the maximum. Parameters: * %1$@ - the currency code, %2$@ - the maximum donation amount allowed. (For example, 'USD $25,000')")
            maximum = String.localizedStringWithFormat(maximumFormat, maximumString, currencyCode)
        }
        
        let genericErrorFormat = "\(CommonStrings.genericErrorDescription)\n\n%1$@"
        
        let monthlyRecurring = WMFLocalizedString("donate-monthly-recurring-text", value: "Make this a monthly recurring donation.", comment: "Text next to monthly recurring checkbox on donate form.")
        
        let emailOptIn = WMFLocalizedString("donate-email-opt-in-text", value: "Yes, the Wikimedia Foundation can send me an occasional email.", comment: "Text next to email opt-in checkbox on donate form.")
        
        let helpProblemsDonating = WMFLocalizedString("donate-help-problems-donating", value: "Problems donating?", comment: "Help link at the bottom of the donate form, that takes user to a web view link with more info.")
        let helpOtherWaysToGive = WMFLocalizedString("donate-help-other-ways-to-give", value: "Other ways to give", comment: "Help link at the bottom of the donate form, that takes user to a web view link with more info.")
        let helpFrequentlyAskedQuestions = WMFLocalizedString("donate-help-frequently-asked-questions", value: "Frequently asked questions", comment: "Help link at the bottom of the donate form, that takes user to a web view link with more info.")
        let helpTaxDeductibilityInformation = WMFLocalizedString("donate-help-tax-deductibility-information", value: "Tax deductibility information", comment: "Help link at the bottom of the donate form, that takes user to a web view link with more info.")
        
        let appleFinePrint = WMFLocalizedString("donate-apple-fine-print", value: "Apple is not in charge of raising money for this purpose.", comment: "Fine print displayed on donation form for Apple Pay, indicating that Apple is not in charge of raising money.")
        
        let accessibilityAmountButtonHint = WMFLocalizedString("donate-accessibility-amount-button-hint", value: "Double tap to select donation amount.", comment: "Accessibility hint on donate form amount option button for screen readers.")
        
        let accessibilityTextfieldHint = WMFLocalizedString("donate-accessibility-textfield-hint", value: "Enter custom amount to donate.", comment: "Accessibility hint on donate form custom amount textfield for screen readers.")
        
        let accessibilityTransactionFeeHint = WMFLocalizedString("donate-accessibility-transaction-fee-hint", value: "Double tap to add transaction fee to donation amount.", comment: "Accessibility hint on donate form transaction fee checkbox for screen readers.")
        
        let accessibilityMonthlyRecurringHint = WMFLocalizedString("donate-accessibility-monthly-recurring-hint", value: "Double tap to enable automatic monthly donations of this amount.", comment: "Accessibility hint on donate form monthly recurring checkbox for screen readers.")
        
        let accessibilityEmailOptInHint = WMFLocalizedString("donate-accessibility-email-opt-in-hint", value: "Double tap to give the Wikimedia Foundation permission to email you.", comment: "Accessibility hint on donate form email opt in checkbox for screen readers.")
        
        let accessibilityKeyboardDoneButtonHint = WMFLocalizedString("donate-accessibility-keyboard-done-hint", value: "Double tap to dismiss amount input keyboard view.", comment: "Accessibility hint on donate form keyboard done button for screen readers.")
        
        let accessibilityDonateHintButtonFormat = WMFLocalizedString("donate-accessibility-donate-hint-format", value: "Double tap to donate %1$@ to the Wikimedia Foundation.", comment: "Accessibility hint on donate form Apple Pay button for screen readers. Parameters: * %1$@ - the donation amount entered by the user.")
        
        let localizedStrings = WKDonateViewModel.LocalizedStrings(title: donate, doneTitle: done, transactionFeeOptInText: transactionFeeOptIn, monthlyRecurringText: monthlyRecurring, emailOptInText: emailOptIn, maximumErrorText: maximum, minimumErrorText: minimum, genericErrorTextFormat: genericErrorFormat, helpLinkProblemsDonating: helpProblemsDonating, helpLinkOtherWaysToGive: helpOtherWaysToGive, helpLinkFrequentlyAskedQuestions: helpFrequentlyAskedQuestions, helpLinkTaxDeductibilityInformation: helpTaxDeductibilityInformation, appleFinePrint: appleFinePrint, accessibilityAmountButtonHint: accessibilityAmountButtonHint, accessibilityTextfieldHint: accessibilityTextfieldHint, accessibilityTransactionFeeHint: accessibilityTransactionFeeHint, accessibilityMonthlyRecurringHint: accessibilityMonthlyRecurringHint, accessibilityEmailOptInHint: accessibilityEmailOptInHint, accessibilityKeyboardDoneButtonHint: accessibilityKeyboardDoneButtonHint, accessibilityDonateButtonHintFormat: accessibilityDonateHintButtonFormat)
        
        guard let delegate = self as? WKDonateDelegate else {
            return nil
        }
        
        guard let viewModel = WKDonateViewModel(localizedStrings: localizedStrings, donateConfig: donateConfig, paymentMethods: paymentMethods, countryCode: countryCode, currencyCode: currencyCode, languageCode: languageCode, merchantID: merchantID, bannerID: bannerID, appVersion: appVersion, delegate: delegate, loggingDelegate: loggingDelegate) else {
            return nil
        }
        
        return viewModel
    }
    
    func pushToNativeDonateForm(countryCode: String, currencyCode: String, languageCode: String, bannerID: String?, appVersion: String?, loggingDelegate: WKDonateLoggingDelegate?) {
        
        guard let viewModel = nativeDonateFormViewModel(countryCode: countryCode, currencyCode: currencyCode, languageCode: languageCode, bannerID: bannerID, appVersion: appVersion, loggingDelegate: loggingDelegate) else {
            return
        }
        
        guard let delegate = self as? WKDonateDelegate else {
            return
        }
        
        let donateViewController = WKDonateViewController(viewModel: viewModel, delegate: delegate, loggingDelegate: loggingDelegate)
        navigationController?.pushViewController(donateViewController, animated: true)
    }
    
    @objc func presentNewDonorExperiencePaymentMethodActionSheet(donateSource: DonateSource, countryCode: String, currencyCode: String, languageCode: String, donateURL: URL, bannerID: String?, appVersion: String?, articleURL: URL?, sourceView: UIView?, loggingDelegate: WKDonateLoggingDelegate?) {
        
        let wikimediaProject: WikimediaProject?
        if let articleURL {
            wikimediaProject = WikimediaProject(siteURL: articleURL)
        } else {
            wikimediaProject = nil
        }
        
        let title = WMFLocalizedString("donate-payment-method-prompt-title", value: "Donate with Apple Pay?", comment: "Title of prompt to user asking which payment method they want to donate with.")
        let message = WMFLocalizedString("donate-payment-method-prompt-message", value: "Donate with Apple Pay or choose other payment method.", comment: "Message of prompt to user asking which payment method they want to donate with.")
        
        let applePayButtonTitle = WMFLocalizedString("donate-payment-method-prompt-apple-pay-button-title", value: "Donate with Apple Pay", comment: "Title of Apple Pay button choice in donate payment method prompt.")
        let otherButtonTitle = WMFLocalizedString("donate-payment-method-prompt-other-button-title", value: "Other payment method", comment: "Title of Other payment method button choice in donate payment method prompt.")
        
        let cancelButtonTitle = CommonStrings.cancelActionTitle
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: cancelButtonTitle, style: .cancel, handler: { action in
            if donateSource == .articleCampaignModal,
               let wikimediaProject {
                AppInteractionFunnel.shared.logArticleDidTapCancel(project: wikimediaProject)
            } else if donateSource == .settings {
                AppInteractionFunnel.shared.logSettingDidTapCancel()
            }
        }))
        
        let applePayAction = UIAlertAction(title: applePayButtonTitle, style: .default, handler: { action in
            
            if donateSource == .articleCampaignModal,
               let wikimediaProject {
                AppInteractionFunnel.shared.logArticleDidTapDonateWithApplePay(project: wikimediaProject)
            } else if donateSource == .settings {
                AppInteractionFunnel.shared.logSettingDidTapApplePay()
            }
            
            if donateSource == .articleCampaignModal {
                self.dismiss(animated: true) {
                    self.pushToNativeDonateForm(countryCode: countryCode, currencyCode: currencyCode, languageCode: languageCode, bannerID: bannerID, appVersion: appVersion, loggingDelegate: loggingDelegate)
                }
            } else {
                self.pushToNativeDonateForm(countryCode: countryCode, currencyCode: currencyCode, languageCode: languageCode, bannerID: bannerID, appVersion: appVersion, loggingDelegate: loggingDelegate)
            }
        })
        alert.addAction(applePayAction)
        
        alert.addAction(UIAlertAction(title: otherButtonTitle, style: .default, handler: { action in
            
            if donateSource == .articleCampaignModal,
               let wikimediaProject {
                AppInteractionFunnel.shared.logArticleDidTapOtherPaymentMethod(project: wikimediaProject)
            } else if donateSource == .settings {
                AppInteractionFunnel.shared.logSettingDidTapOtherPaymentMethod()
            }
            
            if donateSource == .articleCampaignModal,
            let articleURL = articleURL,
            let bannerID {
                self.dismiss(animated: true) {
                    self.navigate(to: donateURL, userInfo: [
                        RoutingUserInfoKeys.campaignArticleURL: articleURL as Any,
                        RoutingUserInfoKeys.campaignBannerID:
                            bannerID as Any
                    ], useSafari: false)
                }
            } else {
                self.navigate(to: donateURL, useSafari: false)
            }
            
        }))
        
        alert.preferredAction = applePayAction
        
        if let popoverPresentationController = alert.popoverPresentationController {
            popoverPresentationController.sourceView = sourceView
        }
        
        let presentationVC = donateSource == .articleCampaignModal ? presentedViewController : self
        presentationVC?.present(alert, animated: true)
    }
}

extension UIViewController {
    func sharedDonateDidTapProblemsDonatingLink() {
        
        guard let countryCode = Locale.current.regionCode,
        let languageCode = Locale.current.languageCode else {
            return
        }
        
        guard let url = URL(string: "https://donate.wikimedia.org/wiki/Special:LandingCheck?basic=true&landing_page=Problems_donating&country=\(countryCode)&language=\(languageCode)&uselang=\(languageCode)&utm_medium=sitenotice&utm_campaign=test&utm_source=B2324_0705_en6C_dsk_p1_lg_template") else {
            return
        }
        
        navigate(to: url, useSafari: true)
    }
    
    func sharedDonateDidTapOtherWaysToGive() {
        
        guard let countryCode = Locale.current.regionCode,
        let languageCode = Locale.current.languageCode else {
            return
        }
        
        guard let url = URL(string: "https://donate.wikimedia.org/wiki/Special:LandingCheck?basic=true&landing_page=Ways_to_Give&country=\(countryCode)&language=\(languageCode)&uselang=\(languageCode)&utm_medium=sitenotice&utm_campaign=test&utm_source=B2324_0705_en6C_dsk_p1_lg_template") else {
            return
        }
        
        navigate(to: url, useSafari: true)
    }
    
    func sharedDonateDidTapFrequentlyAskedQuestions() {
        
        guard let countryCode = Locale.current.regionCode,
        let languageCode = Locale.current.languageCode else {
            return
        }
        
        guard let url = URL(string: "https://donate.wikimedia.org/wiki/Special:LandingCheck?basic=true&landing_page=FAQ&country=\(countryCode)&language=\(languageCode)&uselang=\(languageCode)&utm_medium=sitenotice&utm_campaign=test&utm_source=B2324_0705_en6C_dsk_p1_lg_template") else {
            return
        }
        
        navigate(to: url, useSafari: true)
    }
    
    func sharedDonateDidTapTaxDeductibilityInformation() {

        guard let url = URL(string: "https://donate.wikimedia.org/wiki/Tax_deductibility") else {
            return
        }
        
        navigate(to: url, useSafari: true)
    }
    
    func sharedDonateDidSuccessfullSubmitPayment(source: DonateSource, articleURL: URL?) {
        self.navigationController?.popViewController(animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            WMFAlertManager.sharedInstance.showBottomAlertWithMessage(CommonStrings.donateThankTitle, subtitle: CommonStrings.donateThankSubtitle, image: UIImage.init(systemName: "heart.fill"), type: .custom, customTypeName: "donate-success", duration: -1, dismissPreviousAlerts: true)
            
            switch source {
            case .settings:
                AppInteractionFunnel.shared.logSettingDidSeeApplePayDonateSuccessToast()
            case .articleCampaignModal:
                if let articleURL,
                   let wikimediaProject = WikimediaProject(siteURL: articleURL) {
                    AppInteractionFunnel.shared.logArticleDidSeeApplePayDonateSuccessToast(project: wikimediaProject)
                }
                
            }
        }
    }
    
    func sharedLogDonateFormDidAppear(project: WikimediaProject? = nil) {
        AppInteractionFunnel.shared.logDonateFormNativeApplePayImpression(project: project)
    }
    
    func sharedLogDonateFormUserDidTriggerError(error: Error, project: WikimediaProject? = nil) {

        let errorReason = (error as NSError).description
        let errorCode = String((error as NSError).code)
        
        if let viewModelError = error as? WKDonateViewModel.Error {
            switch viewModelError {
            case .invalidToken:
                AppInteractionFunnel.shared.logDonateFormNativeApplePaySubmissionError(errorReason: errorReason, errorCode: errorCode, orderID: nil, project: project)
            case .missingDonorInfo:
                AppInteractionFunnel.shared.logDonateFormNativeApplePaySubmissionError(errorReason: errorReason, errorCode: errorCode, orderID: nil, project: project)
            case .validationAmountMinimum:
                AppInteractionFunnel.shared.logDonateFormNativeApplePayEntryError(project: project)
            case .validationAmountMaximum:
                AppInteractionFunnel.shared.logDonateFormNativeApplePayEntryError(project: project)
            }
            return
        }
        
        if let donateDataControllerError = error as? WKDonateDataControllerError {
            switch donateDataControllerError {
            case .paymentsWikiResponseError(let reason, let orderID):
                AppInteractionFunnel.shared.logDonateFormNativeApplePaySubmissionError(errorReason: reason, errorCode: errorCode, orderID: orderID, project: project)
            }
            return
        }
        
        AppInteractionFunnel.shared.logDonateFormNativeApplePaySubmissionError(errorReason: errorReason, errorCode: errorCode, orderID: nil, project: project)
    }
    
    func sharedLogDonateFormUserDidTapAmountPresetButton(project: WikimediaProject? = nil) {
        AppInteractionFunnel.shared.logDonateFormNativeApplePayDidTapAmountPresetButton(project: project)
    }
    
    func sharedLogDonateFormUserDidEnterAmountInTextfield(project: WikimediaProject? = nil) {
        AppInteractionFunnel.shared.logDonateFormNativeApplePayDidEnterAmountInTextfield(project: project)
    }
    
    func sharedLogDonateFormUserDidTapApplePayButton(transactionFeeIsSelected: Bool, recurringMonthlyIsSelected: Bool, emailOptInIsSelected: Bool?, project: WikimediaProject? = nil) {
        AppInteractionFunnel.shared.logDonateFormNativeApplePayDidTapApplePayButton(transactionFeeIsSelected: transactionFeeIsSelected, recurringMonthlyIsSelected: recurringMonthlyIsSelected, emailOptInIsSelected: emailOptInIsSelected, project: project)
    }
    
    func sharedLogDonateFormUserDidAuthorizeApplePayPaymentSheet(amount: Decimal, presetIsSelected: Bool, recurringMonthlyIsSelected: Bool, donorEmail: String?, project: WikimediaProject? = nil, bannerID: String? = nil) {
        AppInteractionFunnel.shared.logDonateFormNativeApplePayDidAuthorizeApplePay(amount: amount, presetIsSelected: presetIsSelected, recurringMonthlyIsSelected: recurringMonthlyIsSelected, campaignID: bannerID, donorEmail: donorEmail, project: project)
    }
    
    func sharedLogDonateFormUserDidTapProblemsDonatingLink(project: WikimediaProject? = nil) {
        AppInteractionFunnel.shared.logDonateFormNativeApplePayDidTapProblemsDonatingLink(project: project)
    }
    
    func sharedLogDonateFormUserDidTapOtherWaysToGiveLink(project: WikimediaProject? = nil) {
        AppInteractionFunnel.shared.logDonateFormNativeApplePayDidTapOtherWaysToGiveLink(project: project)
    }
    
    func sharedLogDonateFormUserDidTapFAQLink(project: WikimediaProject? = nil) {
        AppInteractionFunnel.shared.logDonateFormNativeApplePayDidTapFAQLink(project: project)
    }
    
    func sharedLogDonateFormUserDidTapTaxInfoLink(project: WikimediaProject? = nil) {
        AppInteractionFunnel.shared.logDonateFormNativeApplePayDidTapTaxInfoLink(project: project)
    }
}

import Foundation

extension NSUserActivity {
    static func wikipediaActivity(with url: URL, userInfo: [AnyHashable: Any]? = nil) throws -> NSUserActivity {
        let activity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        activity.webpageURL = url
        activity.userInfo = userInfo
        return activity
    }
}

@objc extension UIViewController {
    @objc(wmf_navigateToURL:userInfo:useSafari:)
    public func navigate(to url: URL?, userInfo: [AnyHashable: Any]? = nil, useSafari: Bool) {
        guard let url = url else {
            return
        }
        guard
            !useSafari,
            url.scheme == "https" || url.scheme == "http"
        else {
            UIApplication.shared.open(url)
            return
        }
        do {
            let activity = try NSUserActivity.wikipediaActivity(with: url, userInfo: userInfo)
            NotificationCenter.default.post(name: .WMFNavigateToActivity, object: activity)
        } catch let error {
            WMFAlertManager.sharedInstance.showErrorAlert(error as NSError, sticky: false, dismissPreviousAlerts: false)
        }
    }
    
    @objc(wmf_navigateToURL:userInfo:)
    public func navigate(to url: URL?, userInfo: [AnyHashable: Any]? = nil) {
        return navigate(to: url, userInfo: userInfo, useSafari: false)
    }

    @objc(wmf_navigateToURL:useSafari:)
    public func navigate(to url: URL?, useSafari: Bool) {
        return navigate(to: url, userInfo: nil, useSafari: useSafari)
    }
    
    @objc(wmf_navigateToURL:)
    public func navigate(to url: URL?) {
        return navigate(to: url, userInfo: nil, useSafari: false)
    }

}


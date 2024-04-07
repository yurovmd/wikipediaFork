import Foundation
import WKData
import UIKit

public final class WKWatchlistFilterViewModel: ObservableObject {

    // MARK: - Nested Types

    public struct LocalizedStrings {
        let title: String
        let doneTitle: String
        public var localizedProjectNames: [WKProject: String]
        let wikimediaProjectsHeader: String
        let wikipediasHeader: String
        let commonAll: String
        let latestRevisionsHeader: String
        let latestRevisionsLatestRevision: String
        let latestRevisionsNotLatestRevision: String
        let watchlistActivityHeader: String
        let watchlistActivityUnseenChanges: String
        let watchlistActivitySeenChanges: String
        let automatedContributionsHeader: String
        let automatedContributionsBot: String
        let automatedContributionsHuman: String
        let significanceHeader: String
        let significanceMinorEdits: String
        let significanceNonMinorEdits: String
        let userRegistrationHeader: String
        let userRegistrationUnregistered: String
        let userRegistrationRegistered: String
        let typeOfChangeHeader: String
        let typeOfChangePageEdits: String
        let typeOfChangePageCreations: String
        let typeOfChangeCategoryChanges: String
        let typeOfChangeWikidataEdits: String
        let typeOfChangeLoggedActions: String
		let addLanguage: String

        public init(title: String, doneTitle: String, localizedProjectNames: [WKProject : String], wikimediaProjectsHeader: String, wikipediasHeader: String, commonAll: String, latestRevisionsHeader: String, latestRevisionsLatestRevision: String, latestRevisionsNotLatestRevision: String, watchlistActivityHeader: String, watchlistActivityUnseenChanges: String, watchlistActivitySeenChanges: String, automatedContributionsHeader: String, automatedContributionsBot: String, automatedContributionsHuman: String, significanceHeader: String, significanceMinorEdits: String, significanceNonMinorEdits: String, userRegistrationHeader: String, userRegistrationUnregistered: String, userRegistrationRegistered: String, typeOfChangeHeader: String, typeOfChangePageEdits: String, typeOfChangePageCreations: String, typeOfChangeCategoryChanges: String, typeOfChangeWikidataEdits: String, typeOfChangeLoggedActions: String, addLanguage: String) {
            self.title = title
            self.doneTitle = doneTitle
            self.localizedProjectNames = localizedProjectNames
            self.wikimediaProjectsHeader = wikimediaProjectsHeader
            self.wikipediasHeader = wikipediasHeader
            self.commonAll = commonAll
            self.latestRevisionsHeader = latestRevisionsHeader
            self.latestRevisionsLatestRevision = latestRevisionsLatestRevision
            self.latestRevisionsNotLatestRevision = latestRevisionsNotLatestRevision
            self.watchlistActivityHeader = watchlistActivityHeader
            self.watchlistActivityUnseenChanges = watchlistActivityUnseenChanges
            self.watchlistActivitySeenChanges = watchlistActivitySeenChanges
            self.automatedContributionsHeader = automatedContributionsHeader
            self.automatedContributionsBot = automatedContributionsBot
            self.automatedContributionsHuman = automatedContributionsHuman
            self.significanceHeader = significanceHeader
            self.significanceMinorEdits = significanceMinorEdits
            self.significanceNonMinorEdits = significanceNonMinorEdits
            self.userRegistrationHeader = userRegistrationHeader
            self.userRegistrationUnregistered = userRegistrationUnregistered
            self.userRegistrationRegistered = userRegistrationRegistered
            self.typeOfChangeHeader = typeOfChangeHeader
            self.typeOfChangePageEdits = typeOfChangePageEdits
            self.typeOfChangePageCreations = typeOfChangePageCreations
            self.typeOfChangeCategoryChanges = typeOfChangeCategoryChanges
            self.typeOfChangeWikidataEdits = typeOfChangeWikidataEdits
            self.typeOfChangeLoggedActions = typeOfChangeLoggedActions
            self.addLanguage = addLanguage
        }
    }
    
    private struct WKProjectViewModel {
        let project: WKProject
        let projectName: String?
        let icon: UIImage?
        let isSelected: Bool
    }
    
    // MARK: - Properties
    
    public var localizedStrings: LocalizedStrings
    private var projectViewModels: [WKProjectViewModel]
    @Published var formViewModel: WKFormViewModel
    weak var loggingDelegate: WKWatchlistLoggingDelegate?
    private let dataController = WKWatchlistDataController()
    let overrideUserInterfaceStyle: UIUserInterfaceStyle
	var addLanguageAction: (() -> Void)? {
		didSet {
			reloadSectionData()
		}
	}

    // MARK: - Public

    public init(localizedStrings: LocalizedStrings, overrideUserInterfaceStyle: UIUserInterfaceStyle, loggingDelegate: WKWatchlistLoggingDelegate?) {
        self.localizedStrings = localizedStrings
        self.overrideUserInterfaceStyle = overrideUserInterfaceStyle
        self.loggingDelegate = loggingDelegate
        
        let filterSettings = dataController.loadFilterSettings()
        let allProjects = dataController.allWatchlistProjects()
        let offProjects = dataController.offWatchlistProjects()
        self.projectViewModels = Self.projectViewModels(allProjects: allProjects, offProjects: offProjects, strings: localizedStrings)
        
        let allChangeTypes = dataController.allChangeTypes()
        let offChangeTypes = dataController.offChangeTypes()
        
        self.formViewModel = WKFormViewModel(sections: [
            Self.section1(projectViewModels: Array(projectViewModels.prefix(2)), strings: localizedStrings),
            Self.section2(projectViewModels: Array(projectViewModels.suffix(from: 2)), strings: localizedStrings, addLanguageAction: addLanguageAction),
            Self.section3(strings: localizedStrings, filterSettings: filterSettings),
            Self.section4(strings: localizedStrings, filterSettings: filterSettings),
            Self.section5(strings: localizedStrings, filterSettings: filterSettings),
            Self.section6(strings: localizedStrings, filterSettings: filterSettings),
            Self.section7(strings: localizedStrings, filterSettings: filterSettings),
            Self.section8(allChangeTypes: allChangeTypes, offChangeTypes: offChangeTypes, strings: localizedStrings, filterSettings: filterSettings)
        ])
    }

	public func reloadWikipedias(localizedProjectNames: [WKProject: String]?) {
		guard let localizedProjectNames = localizedProjectNames else {
			return
		}

		self.localizedStrings.localizedProjectNames = localizedProjectNames
		let allProjects = dataController.allWatchlistProjects()
		let offProjects = self.projectViewModels.filter { !$0.isSelected }.map { $0.project }

		self.projectViewModels = Self.projectViewModels(allProjects: allProjects, offProjects: offProjects, strings: localizedStrings)
		self.formViewModel.sections[1] = Self.section2(projectViewModels: Array(projectViewModels.suffix(from: 2)), strings: localizedStrings, addLanguageAction: addLanguageAction)
	}

    func saveNewFilterSettings() {
        let data = generateDataForNewFilterSettings()
        
        let newFilterSettings = data.filterSettings
        dataController.saveFilterSettings(newFilterSettings)
        
        let onProjects = data.onProjects
        loggingDelegate?.logWatchlistUserDidSaveFilterSettings(filterSettings: newFilterSettings, onProjects: onProjects)
    }
    
    private func generateDataForNewFilterSettings() -> (filterSettings: WKWatchlistFilterSettings, onProjects: [WKProject]) {
        guard let sectionSelectViewModels = formViewModel.sections as? [WKFormSectionSelectViewModel],
              sectionSelectViewModels.count == 8 else {
            assertionFailure("Unexpected sections setup")
            return (WKWatchlistFilterSettings(offProjects: [], latestRevisions: .notTheLatestRevision, activity: .all, automatedContributions: .all, significance: .all, userRegistration: .all, offTypes: []), [])
        }

        var offProjects: [WKProject] = []
        var onProjects: [WKProject] = []
        let wikimediaProjectsSection = sectionSelectViewModels[0]
        let wikipediasSection = sectionSelectViewModels[1]

        guard wikimediaProjectsSection.items.count == 2,
              wikipediasSection.items.count == projectViewModels.count - 1 else {
            assertionFailure("Unexpected projects section counts")

            return  (WKWatchlistFilterSettings(offProjects: [], latestRevisions: .notTheLatestRevision, activity: .all, automatedContributions: .all, significance: .all, userRegistration: .all, offTypes: []),[])
        }

        for (index, item) in wikimediaProjectsSection.items.enumerated() {
            if !item.isSelected {
                offProjects.append(projectViewModels[index].project)
            } else {
                onProjects.append(projectViewModels[index].project)
            }
        }

		for (index, item) in wikipediasSection.items.enumerated().filter({ !$0.element.isAccessoryRow }) {
            let offsetIndex = index + (wikimediaProjectsSection.items.count)
            if !item.isSelected {
                offProjects.append(projectViewModels[offsetIndex].project)
            } else {
                onProjects.append(projectViewModels[offsetIndex].project)
            }
        }

        let latestRevisionsSection = sectionSelectViewModels[2]
        let activitySection = sectionSelectViewModels[3]
        let automatedContributionsSection = sectionSelectViewModels[4]
        let significanceSection = sectionSelectViewModels[5]
        let userRegistrationSection = sectionSelectViewModels[6]
        let typeOfChangeSection = sectionSelectViewModels[7]

        guard latestRevisionsSection.items.count == 2,
              activitySection.items.count == 3,
              automatedContributionsSection.items.count == 3,
              significanceSection.items.count == 3,
              userRegistrationSection.items.count == 3,
              typeOfChangeSection.items.count == 5 else {
            assertionFailure("Unexpected items count")

            return (WKWatchlistFilterSettings(offProjects: [], latestRevisions: .notTheLatestRevision, activity: .all, automatedContributions: .all, significance: .all, userRegistration: .all, offTypes: []),[])
        }

        let latestRevisionsRequest: WKWatchlistFilterSettings.LatestRevisions
        if latestRevisionsSection.items[0].isSelected {
            latestRevisionsRequest = .notTheLatestRevision
        } else if latestRevisionsSection.items[1].isSelected {
            latestRevisionsRequest = .latestRevision
        } else {
            latestRevisionsRequest = .notTheLatestRevision
        }

        let activityRequest: WKWatchlistFilterSettings.Activity
        if activitySection.items[0].isSelected {
            activityRequest = .all
        } else if activitySection.items[1].isSelected {
            activityRequest = .unseenChanges
        } else if activitySection.items[2].isSelected {
            activityRequest = .seenChanges
        } else {
            activityRequest = .all
        }

        let automatedContributionsRequest: WKWatchlistFilterSettings.AutomatedContributions
        if automatedContributionsSection.items[0].isSelected {
            automatedContributionsRequest = .all
        } else if automatedContributionsSection.items[1].isSelected {
            automatedContributionsRequest = .bot
        } else if automatedContributionsSection.items[2].isSelected {
            automatedContributionsRequest = .human
        } else {
            automatedContributionsRequest = .all
        }

        let significanceRequest: WKWatchlistFilterSettings.Significance
        if significanceSection.items[0].isSelected {
            significanceRequest = .all
        } else if significanceSection.items[1].isSelected {
            significanceRequest = .minorEdits
        } else if significanceSection.items[2].isSelected {
            significanceRequest = .nonMinorEdits
        } else {
            significanceRequest = .all
        }

        let userRegistrationRequest: WKWatchlistFilterSettings.UserRegistration
        if userRegistrationSection.items[0].isSelected {
            userRegistrationRequest = .all
        } else if userRegistrationSection.items[1].isSelected {
            userRegistrationRequest = .unregistered
        } else if userRegistrationSection.items[2].isSelected {
            userRegistrationRequest = .registered
        } else {
            userRegistrationRequest = .all
        }

        var offTypesRequest: [WKWatchlistFilterSettings.ChangeType] = []
        if !typeOfChangeSection.items[0].isSelected {
            offTypesRequest.append(.pageEdits)
        }

        if !typeOfChangeSection.items[1].isSelected {
            offTypesRequest.append(.pageCreations)
        }

        if !typeOfChangeSection.items[2].isSelected {
            offTypesRequest.append(.categoryChanges)
        }

        if !typeOfChangeSection.items[3].isSelected {
            offTypesRequest.append(.wikidataEdits)
        }

        if !typeOfChangeSection.items[4].isSelected {
            offTypesRequest.append(.loggedActions)
        }

        return (WKWatchlistFilterSettings(offProjects: offProjects,
                                        latestRevisions: latestRevisionsRequest,
                                        activity: activityRequest,
                                        automatedContributions: automatedContributionsRequest,
                                        significance: significanceRequest,
                                        userRegistration: userRegistrationRequest,
                                        offTypes: offTypesRequest), onProjects)
    }

	// MARK: - Private

	private func reloadSectionData() {
		let filterSettings = dataController.loadFilterSettings()
		let allProjects = dataController.allWatchlistProjects()
		let offProjects = dataController.offWatchlistProjects()
		self.projectViewModels = Self.projectViewModels(allProjects: allProjects, offProjects: offProjects, strings: localizedStrings)

		let allChangeTypes = dataController.allChangeTypes()
		let offChangeTypes = dataController.offChangeTypes()

		self.formViewModel = WKFormViewModel(sections: [
			Self.section1(projectViewModels: Array(projectViewModels.prefix(2)), strings: localizedStrings),
			Self.section2(projectViewModels: Array(projectViewModels.suffix(from: 2)), strings: localizedStrings, addLanguageAction: addLanguageAction),
			Self.section3(strings: localizedStrings, filterSettings: filterSettings),
			Self.section4(strings: localizedStrings, filterSettings: filterSettings),
			Self.section5(strings: localizedStrings, filterSettings: filterSettings),
			Self.section6(strings: localizedStrings, filterSettings: filterSettings),
			Self.section7(strings: localizedStrings, filterSettings: filterSettings),
			Self.section8(allChangeTypes: allChangeTypes, offChangeTypes: offChangeTypes, strings: localizedStrings, filterSettings: filterSettings)
		])
	}

}

// MARK: - Static Init Helper Methods

private extension WKWatchlistFilterViewModel {
    private static func projectViewModels(allProjects: [WKProject], offProjects: [WKProject], strings: WKWatchlistFilterViewModel.LocalizedStrings) -> [WKProjectViewModel] {

        var projectViewModels: [WKProjectViewModel] = []
        
        let wikipediaProjects = allProjects.filter {
            switch $0 {
            case .wikipedia:
                return true
            default:
                return false
            }
        }
        
        let otherProjects = allProjects.filter {
            switch $0 {
            case .wikipedia:
                return false
            default:
                return true
            }
        }
        
        for project in otherProjects {
            var icon: UIImage? = nil
            switch project {
            case .commons:
                icon = WKIcon.commons
            case .wikidata:
                icon = WKIcon.wikidata
            default:
                break
            }
            
            projectViewModels.append(WKProjectViewModel(project: project, projectName: strings.localizedProjectNames[project], icon: icon, isSelected: !offProjects.contains(project)))
        }
        
        for project in wikipediaProjects {
            projectViewModels.append(WKProjectViewModel(project: project, projectName: strings.localizedProjectNames[project], icon: nil, isSelected: !offProjects.contains(project)))
        }

        return projectViewModels
    }
    
    private static func section1(projectViewModels: [WKProjectViewModel], strings: WKWatchlistFilterViewModel.LocalizedStrings) -> WKFormSectionSelectViewModel {

        let items = projectViewModels.map { projectViewModel in
            return WKFormItemSelectViewModel(image: projectViewModel.icon, title: projectViewModel.projectName, isSelected: projectViewModel.isSelected)

        }

        return WKFormSectionSelectViewModel(header: strings.wikimediaProjectsHeader, items: items, selectType: .multi)
    }

	private static func section2(projectViewModels: [WKProjectViewModel], strings: WKWatchlistFilterViewModel.LocalizedStrings, addLanguageAction: (() -> Void)?) -> WKFormSectionSelectViewModel {

        var items = projectViewModels.map { projectViewModel in
            return WKFormItemSelectViewModel(image: projectViewModel.icon, title: projectViewModel.projectName, isSelected: projectViewModel.isSelected)
        }

		let accessoryRow = WKFormItemSelectViewModel(title: strings.addLanguage, isSelected: false, isAccessoryRow: true)
		accessoryRow.accessoryRowSelectionAction = addLanguageAction
		items.append(accessoryRow)

        return WKFormSectionSelectViewModel(header: strings.wikipediasHeader, items: items, selectType: .multiWithAccessoryRows)
    }

    private static func section3(strings: WKWatchlistFilterViewModel.LocalizedStrings, filterSettings: WKWatchlistFilterSettings) -> WKFormSectionSelectViewModel {
        let items = [
            WKFormItemSelectViewModel(title: strings.latestRevisionsNotLatestRevision, isSelected: filterSettings.latestRevisions == .notTheLatestRevision),
            WKFormItemSelectViewModel(title: strings.latestRevisionsLatestRevision, isSelected: filterSettings.latestRevisions == .latestRevision)
        ]
        return WKFormSectionSelectViewModel(header: strings.latestRevisionsHeader, items: items, selectType: .single)
    }

    private static func section4(strings: WKWatchlistFilterViewModel.LocalizedStrings, filterSettings: WKWatchlistFilterSettings) -> WKFormSectionSelectViewModel {
        let items = [
            WKFormItemSelectViewModel(title: strings.commonAll, isSelected: filterSettings.activity == .all),
            WKFormItemSelectViewModel(title: strings.watchlistActivityUnseenChanges, isSelected: filterSettings.activity == .unseenChanges),
            WKFormItemSelectViewModel(title: strings.watchlistActivitySeenChanges, isSelected: filterSettings.activity == .seenChanges)
        ]
        return WKFormSectionSelectViewModel(header: strings.watchlistActivityHeader, items: items, selectType: .single)
    }

    private static func section5(strings: WKWatchlistFilterViewModel.LocalizedStrings, filterSettings: WKWatchlistFilterSettings) -> WKFormSectionSelectViewModel {
        let items = [
            WKFormItemSelectViewModel(title: strings.commonAll, isSelected: filterSettings.automatedContributions == .all),
            WKFormItemSelectViewModel(title: strings.automatedContributionsBot, isSelected: filterSettings.automatedContributions == .bot),
            WKFormItemSelectViewModel(title: strings.automatedContributionsHuman, isSelected: filterSettings.automatedContributions == .human)
        ]
        return WKFormSectionSelectViewModel(header: strings.automatedContributionsHeader, items: items, selectType: .single)
    }

    private static func section6(strings: WKWatchlistFilterViewModel.LocalizedStrings, filterSettings: WKWatchlistFilterSettings) -> WKFormSectionSelectViewModel {
        let items = [
            WKFormItemSelectViewModel(title: strings.commonAll, isSelected: filterSettings.significance == .all),
            WKFormItemSelectViewModel(title: strings.significanceMinorEdits, isSelected: filterSettings.significance == .minorEdits),
            WKFormItemSelectViewModel(title: strings.significanceNonMinorEdits, isSelected: filterSettings.significance == .nonMinorEdits)
        ]
        return WKFormSectionSelectViewModel(header: strings.significanceHeader, items: items, selectType: .single)
    }

    private static func section7(strings: WKWatchlistFilterViewModel.LocalizedStrings, filterSettings: WKWatchlistFilterSettings) -> WKFormSectionSelectViewModel {
        let items = [
            WKFormItemSelectViewModel(title: strings.commonAll, isSelected: filterSettings.userRegistration == .all),
            WKFormItemSelectViewModel(title: strings.userRegistrationUnregistered, isSelected: filterSettings.userRegistration == .unregistered),
            WKFormItemSelectViewModel(title: strings.userRegistrationRegistered, isSelected: filterSettings.userRegistration == .registered)
        ]
        return WKFormSectionSelectViewModel(header: strings.userRegistrationHeader, items: items, selectType: .single)
    }

    private static func section8(allChangeTypes: [WKWatchlistFilterSettings.ChangeType], offChangeTypes: [WKWatchlistFilterSettings.ChangeType], strings: WKWatchlistFilterViewModel.LocalizedStrings, filterSettings: WKWatchlistFilterSettings) -> WKFormSectionViewModel {

        var items: [WKFormItemSelectViewModel] = []
        for changeType in allChangeTypes {
            
            var title: String
            
            switch changeType {
            case .categoryChanges:
                title = strings.typeOfChangeCategoryChanges
            case .loggedActions:
                title = strings.typeOfChangeLoggedActions
            case .pageCreations:
                title = strings.typeOfChangePageCreations
            case .pageEdits:
                title = strings.typeOfChangePageEdits
            case .wikidataEdits:
                title = strings.typeOfChangeWikidataEdits
            }
            
            items.append(WKFormItemSelectViewModel(title: title, isSelected: !offChangeTypes.contains(changeType)))
        }

        return WKFormSectionSelectViewModel(header: strings.typeOfChangeHeader, items: items, selectType: .multi)
    }
}

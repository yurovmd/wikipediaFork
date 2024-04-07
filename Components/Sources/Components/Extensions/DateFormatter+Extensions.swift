import Foundation

public extension DateFormatter {

	/// Short time only: e.g. `2:48pm`
	static var wkShortTimeFormatter = {
		let dateFormatter = DateFormatter()
		dateFormatter.timeStyle = .short
		dateFormatter.dateStyle = .none
		return dateFormatter
	}()

	/// Full date only: e.g. `Tuesday, August 22, 2023`
	static var wkFullDateFormatter = {
		let dateFormatter = DateFormatter()
		dateFormatter.timeStyle = .none
		dateFormatter.dateStyle = .full
		return dateFormatter
	}()

}

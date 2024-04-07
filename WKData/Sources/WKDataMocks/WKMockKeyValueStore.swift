import Foundation
import WKData

public final class WKMockKeyValueStore: WKKeyValueStore {
    
    public init() {
        self.savedObjects = [:]
    }
    
    private var savedObjects: [String: Codable] = [:]
    public func load<T>(key: String...) throws -> T? where T : Decodable, T : Encodable {
        let defaultsKey = key.joined(separator: ".")
        return savedObjects[defaultsKey] as? T
    }
    
    public func save<T>(key: String..., value: T) throws where T : Decodable, T : Encodable {
        let defaultsKey = key.joined(separator: ".")
        savedObjects[defaultsKey] = value
    }
}

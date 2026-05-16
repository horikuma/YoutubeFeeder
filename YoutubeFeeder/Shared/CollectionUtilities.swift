import Foundation

enum CollectionUtilities {
    static func dictionaryKeepingLastValue<Value>(_ pairs: [(String, Value)]) -> [String: Value] {
        Dictionary(pairs, uniquingKeysWith: { _, rhs in rhs })
    }
}

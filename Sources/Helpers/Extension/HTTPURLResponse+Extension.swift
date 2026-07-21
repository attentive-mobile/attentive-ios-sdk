import Foundation

extension HTTPURLResponse {
    var isSuccessful: Bool { (200...299).contains(statusCode) }
}

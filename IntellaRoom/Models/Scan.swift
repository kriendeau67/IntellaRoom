

import Foundation

struct Scan: Identifiable, Codable, Hashable {
    let id: String
    let projectId: String
    let draqingId: String
    let roomId: String

    let imageFileNames: [String]
    let capturedAt: Date

    var coverageComplete: Bool? = nil
}

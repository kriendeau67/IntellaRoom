import Foundation

struct Scan: Identifiable, Codable {
    let id: UUID

    // Room info
    let roomName: String

    // Where is it on the PDF?
    let x: Int
    let y: Int

    // When was it captured?
    let date: Date

    // Final deliverables (1–4 wall images)
    let imageFileNames: [String]
}

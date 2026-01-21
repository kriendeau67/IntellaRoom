

import Foundation

struct Scan: Identifiable, Codable, Hashable {
    let id: String
    let projectId: String
    let drawingId: String // Fixed the 'q' to a 'g'
    let roomId: String
    let imageFileNames: [String]
    let capturedAt: Date
    var coverageComplete: Bool? = nil
    
    // NEW: Track if the cloud has this yet
        var isUploaded: Bool?
    
    // Helper for the Thumbnail
        func getThumbnailURL(for fileName: String) -> URL {
            let thumbName = fileName.replacingOccurrences(of: ".jpg", with: "_thumb.jpg")
            let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            return paths[0].appendingPathComponent(thumbName)
        }
    
    // Helper to find the photo on the phone's hard drive
    func getLocalURL(for fileName: String) -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent(fileName)
    }
}

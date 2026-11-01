import Foundation
@testable import Devet

/// Test double for StorageRepository — records uploads without network.
class FakeStorageRepository: StorageRepository {
    struct Upload {
        let bytes: Data
        let code: String
        let eventId: String
    }

    var uploads: [Upload] = []
    var uploadResult: Result<String, AuthFailure> = .success("previews/test.jpg")
    var uploadFailureCount = 0
    var uploadFailureAfterCount = Int.max

    func uploadPreviewImage(_ bytes: Data, code: String, eventId: String) async -> Result<String, AuthFailure> {
        uploadFailureCount += 1
        if uploadFailureCount >= uploadFailureAfterCount {
            return .failure(.network)
        }
        uploads.append(Upload(bytes: bytes, code: code, eventId: eventId))
        return uploadResult.map { _ in "\(code).jpg" }
    }

    func clear() {
        uploads.removeAll()
        uploadFailureCount = 0
        uploadFailureAfterCount = Int.max
        uploadResult = .success("previews/test.jpg")
    }
}

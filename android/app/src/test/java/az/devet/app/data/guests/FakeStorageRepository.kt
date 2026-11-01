package az.devet.app.data.guests

import az.devet.app.data.auth.AuthError
import az.devet.app.data.auth.AuthResult

/// Test double for StorageRepository — records uploads without network.
class FakeStorageRepository : StorageRepository {
    data class Upload(val bytes: ByteArray, val code: String, val eventId: String) {
        override fun equals(other: Any?) = other is Upload && code == other.code && eventId == other.eventId
        override fun hashCode() = code.hashCode() xor eventId.hashCode()
    }

    val uploads = mutableListOf<Upload>()
    var uploadResult: AuthResult<String> = AuthResult.Ok("")
    var uploadFailureCount = 0
    var uploadFailureAfterCount = Int.MAX_VALUE

    override suspend fun uploadPreviewImage(bytes: ByteArray, code: String, eventId: String): AuthResult<String> {
        uploadFailureCount++
        if (uploadFailureCount >= uploadFailureAfterCount) {
            return AuthResult.Failure(AuthError.Network)
        }
        uploads.add(Upload(bytes, code, eventId))
        return uploadResult.also {
            if (it is AuthResult.Ok) {
                it.copy(value = "$code.jpg")
            }
        }
    }

    fun clear() {
        uploads.clear()
        uploadFailureCount = 0
        uploadFailureAfterCount = Int.MAX_VALUE
        uploadResult = AuthResult.Ok("")
    }
}

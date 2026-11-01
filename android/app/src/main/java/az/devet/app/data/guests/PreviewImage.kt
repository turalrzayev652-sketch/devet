package az.devet.app.data.guests

import android.graphics.Bitmap
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/// Qonaq üçün adlı önizləmə şəkli: 1200×630 JPEG (bax screens.md §8a, design.md).
data class PreviewImage(
    val bitmap: Bitmap,       // 1200×630, RGB
    val bytes: ByteArray,     // JPEG, ≤ 80 KB
    val code: String,         // guests.code, path = previews/<code>.jpg
) {
    override fun equals(other: Any?) = this === other || (other is PreviewImage && code == other.code)
    override fun hashCode() = code.hashCode()
}

/// Şəkil yaratmaq üçün parametrlər.
@Serializable
data class PreviewParams(
    val displayName: String,     // "Elçin müəllim və ailəsi"
    val code: String,
    val lang: String,             // qonağın dili (az/ru/en/tr)
    @SerialName("template_bg_color")
    val templateBgColor: String?  // hex rəngi, məs. "#faf7f2"
) {
    init {
        require(displayName.isNotBlank()) { "displayName must not be blank" }
        require(code.isNotEmpty()) { "code must not be empty" }
    }
}

/// Hər dildə "sizi dəvət edirik" metni.
val inviteTextByLang = mapOf(
    "az" to "sizi dəvətində bəşər",  // placer for event names
    "ru" to "приглашают вас",
    "en" to "invite you to",
    "tr" to "sizi davetiyelere çağırıyor"
)

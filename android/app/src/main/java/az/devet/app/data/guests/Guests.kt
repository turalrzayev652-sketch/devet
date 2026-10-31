package az.devet.app.data.guests

/** `salutation` enum (PRODUCT.md §5). */
enum class Salutation(val key: String) {
    Muellim("muellim"), Xanim("xanim"), Bey("bey"), None("none");

    companion object {
        fun of(key: String?) = entries.firstOrNull { it.key == key } ?: None
    }
}

/** `side` enum. */
enum class Side(val key: String) {
    Groom("groom"), Bride("bride"), None("none");

    companion object {
        fun of(key: String?) = entries.firstOrNull { it.key == key } ?: None
    }
}

/** A guest to insert (api.md §2 [7]); `code` and `added_by` are set by the server. */
data class NewGuest(
    val name: String,
    val salutation: Salutation = Salutation.None,
    val withFamily: Boolean = false,
    val invitedCount: Int = 1,
    val phoneE164: String? = null,
    val side: Side = Side.None,
    val tableNo: String? = null,
    /** null = the event's default language. */
    val lang: String? = null,
)

/** Field limits shared with the Excel rules (api.md §1 Guest, test-vectors). */
object GuestRules {
    const val MAX_NAME = 80
    const val MAX_COUNT = 50
    const val MAX_TABLE = 12

    fun nameOk(v: String) = v.trim().length in 1..MAX_NAME
    fun countOk(v: Int) = v in 1..MAX_COUNT
    fun tableOk(v: String) = v.trim().length <= MAX_TABLE
}

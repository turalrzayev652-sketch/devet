package az.devet.app.data.events

import java.net.URLDecoder

/**
 * Venue map link → coordinates (screens.md §3 step 4, §15.3). Rules: spec/test-vectors/README.md#maps,
 * cases: spec/test-vectors/maps.json, JS reference: tools/test-vectors/reference.mjs. The URL is split by hand
 * (not java.net.URI) so links with spaces parse the same way as in the browser and on iOS.
 */
object MapsLink {
    sealed interface Result {
        /** Link accepted; [lat]/[lng] are null when the link carries no readable coordinates (short links, other hosts). */
        data class Ok(val lat: Double?, val lng: Double?) : Result
        data class Error(val code: String) : Result
    }

    private const val NUM = """(-?\d{1,3}(?:\.\d+)?)"""
    private val URL = Regex("""^(https?)://([^/?#\s]+)([^?#]*)(?:\?([^#]*))?(?:#.*)?$""", RegexOption.IGNORE_CASE)
    private val GOOGLE = Regex("""^(?:www\.|maps\.)?google\.(?:[a-z]{2,3}|com?\.[a-z]{2})$""")
    private val PIN = Regex("""!3d$NUM!4d$NUM""")
    private val AT = Regex("""@$NUM,$NUM(?:,|$)""")
    private val PAIR = Regex("""^$NUM,\s*$NUM$""")

    fun parse(input: String?): Result {
        val text = input.orEmpty().trim()
        if (text.isEmpty()) return Result.Error("empty")
        val m = URL.matchEntire(text) ?: return Result.Error("invalid_url")
        val (_, authority, path, query) = m.destructured
        val host = authority.substringAfterLast('@').substringBefore(':').lowercase()
        if (host.isEmpty()) return Result.Error("invalid_url")
        if (!isMapHost(host, path)) return Result.Ok(null, null)

        val candidates = mutableListOf<MatchResult>()
        PIN.find(decode(text, plus = false))?.let(candidates::add)
        AT.find(decode(path, plus = false))?.let(candidates::add)
        val params = query.split('&').filter { it.isNotEmpty() }.map {
            val (k, v) = (it.split('=', limit = 2) + "").take(2)
            decode(k, plus = true) to decode(v, plus = true)
        }
        for (name in listOf("q", "query", "ll")) {
            val value = params.firstOrNull { it.first == name }?.second ?: continue
            PAIR.matchEntire(value.trim())?.let(candidates::add)
        }
        for (c in candidates) {
            val lat = c.groupValues[1].toDouble()
            val lng = c.groupValues[2].toDouble()
            if (kotlin.math.abs(lat) <= 90 && kotlin.math.abs(lng) <= 180) return Result.Ok(lat, lng)
        }
        return Result.Ok(null, null)
    }

    private fun isMapHost(host: String, path: String): Boolean {
        if (host == "waze.com" || host == "www.waze.com" || host == "maps.apple.com") return true
        return GOOGLE.matches(host) && (host.startsWith("maps.") || path.startsWith("/maps"))
    }

    /** Percent-decoding that never throws on a stray `%` (keeps the text as is). */
    private fun decode(s: String, plus: Boolean): String =
        runCatching { URLDecoder.decode(if (plus) s else s.replace("+", "%2B"), "UTF-8") }.getOrDefault(s)
}

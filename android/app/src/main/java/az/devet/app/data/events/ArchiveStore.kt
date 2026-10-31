package az.devet.app.data.events

import android.content.Context

/** "Arxivlə" on screen [2] is a local view choice only (api.md §2 [2]: no server field in v1). */
interface ArchiveStore {
    fun archived(): Set<String>
    fun setArchived(id: String, archived: Boolean)
}

class PrefsArchiveStore(context: Context) : ArchiveStore {
    private val prefs = context.getSharedPreferences("events", Context.MODE_PRIVATE)

    override fun archived(): Set<String> = prefs.getStringSet(KEY, emptySet()).orEmpty()

    override fun setArchived(id: String, archived: Boolean) {
        val next = archived().toMutableSet().apply { if (archived) add(id) else remove(id) }
        prefs.edit().putStringSet(KEY, next).apply()
    }

    private companion object {
        const val KEY = "archived_ids"
    }
}

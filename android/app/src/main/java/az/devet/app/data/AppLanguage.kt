package az.devet.app.data

import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat
import java.util.Locale

/** Per-app language (Settings → "Tətbiqin dili"). null = follow the system. */
interface AppLanguage {
    val selected: String?

    /** Language the UI shows now: the selected one, else the system one if supported, else az. */
    val effective: String

    fun select(lang: String?)

    companion object {
        val SUPPORTED = listOf("az", "ru", "en", "tr")
    }
}

/** AppCompat stores the choice (autoStoreLocales below API 33, system per-app setting on 33+). */
class AndroidAppLanguage : AppLanguage {
    override val selected: String?
        get() = AppCompatDelegate.getApplicationLocales().takeIf { !it.isEmpty }?.get(0)?.language?.takeIf { it in AppLanguage.SUPPORTED }

    override val effective: String
        get() = selected ?: Locale.getDefault().language.takeIf { it in AppLanguage.SUPPORTED } ?: "az"

    override fun select(lang: String?) {
        AppCompatDelegate.setApplicationLocales(if (lang == null) LocaleListCompat.getEmptyLocaleList() else LocaleListCompat.forLanguageTags(lang))
    }
}

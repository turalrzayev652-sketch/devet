package az.devet.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/** Generated string files (tools/i18n/generate.mjs) exist for all four languages and match spec/i18n/app.json. */
class StringResourcesTest {
    private val root = File(System.getProperty("devet.repoRoot") ?: error("devet.repoRoot not set"))
    private val res = File(root, "android/app/src/main/res")
    private val folders = mapOf("az" to "values", "ru" to "values-ru", "en" to "values-en", "tr" to "values-tr")

    private fun names(folder: String): Set<String> =
        Regex("""<(?:string|plurals) name="([a-z0-9_]+)"""").findAll(File(res, "$folder/strings.xml").readText()).map { it.groupValues[1] }.toSet()

    @Test
    fun everyLanguageHasTheSameKeys() {
        val az = names("values")
        assertTrue(az.isNotEmpty())
        folders.values.forEach { assertEquals("keys in $it", az, names(it)) }
    }

    @Test
    fun resourcesAreInSyncWithAppJson() {
        val json = File(root, "spec/i18n/app.json").readText()
        val expected = Regex(""""([a-z0-9_.]+)":\s*\{""").findAll(json)
            .map { it.groupValues[1].replace(Regex("""\.(one|few|many|other)$"""), "").replace('.', '_') }
            .toSet()
        assertEquals("run: node tools/i18n/generate.mjs", expected, names("values"))
    }

    @Test
    fun azerbaijaniIsTheDefaultSet() {
        val text = File(res, "values/strings.xml").readText()
        assertTrue(text.contains("""<string name="app_welcome">Xoş gəlmisiniz</string>"""))
        assertTrue(File(res, "values-ru/strings.xml").readText().contains("Добро пожаловать"))
    }
}

package az.devet.app

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import az.devet.app.ui.theme.DarkColors
import az.devet.app.ui.theme.DevetTypography
import az.devet.app.ui.theme.LightColors
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/** Keeps the Compose theme equal to spec/design.md (the source of truth). */
class DesignTokensTest {
    private val designMd: String by lazy {
        val root = System.getProperty("devet.repoRoot") ?: error("devet.repoRoot not set (see app/build.gradle.kts)")
        File(root, "spec/design.md").readText()
    }

    private fun hex(c: Color) = String.format("#%06X", c.toArgb() and 0xFFFFFF)

    @Test
    fun colorTableMatches() {
        // | `color.bg.canvas` | `#FAF7F2` | `#151217` | ... |
        val rows = Regex("""\| `(color\.[\w.]+)` \| `(#[0-9A-Fa-f]{6})` \| `(#[0-9A-Fa-f]{6})` \|""").findAll(designMd).toList()
        assertTrue("design.md colour rows not found", rows.size >= 20)
        for (m in rows) {
            val (token, light, dark) = m.destructured
            val l = LightColors.tokens[token] ?: error("missing light token $token")
            val d = DarkColors.tokens[token] ?: error("missing dark token $token")
            assertEquals("light $token", light.uppercase(), hex(l))
            assertEquals("dark $token", dark.uppercase(), hex(d))
        }
    }

    @Test
    fun statusTableMatches() {
        // | `coming` | Gəlir {n} / … | `#4E7D5B` / `#8CC59A` | `#3F6B4B` / `#8CC59A` | `#E7F0E9` / `#22342A` |
        val pair = """`(#[0-9A-Fa-f]{6})` / `(#[0-9A-Fa-f]{6})`"""
        val rows = Regex("""\| `(coming|declined|viewed|pending|unsent)` \|[^|]*\| $pair \| $pair \| $pair \|""").findAll(designMd).toList()
        assertEquals("five status rows", 5, rows.size)
        for (m in rows) {
            val g = m.groupValues
            val name = g[1]
            listOf("fg" to 2, "text" to 4, "bg" to 6).forEach { (part, i) ->
                assertEquals("light $name.$part", g[i].uppercase(), hex(LightColors.tokens.getValue("color.status.$name.$part")))
                assertEquals("dark $name.$part", g[i + 1].uppercase(), hex(DarkColors.tokens.getValue("color.status.$name.$part")))
            }
        }
    }

    @Test
    fun typeScaleMatches() {
        // | `type.serif.display` | serif | 34 / 40 | 500 | ...
        val rows = Regex("""\| `(type\.[\w.]+)` \| (serif|sans) \| (\d+) / (\d+) \| (\d+)""").findAll(designMd).toList()
        assertEquals("ten type tokens", 10, rows.size)
        val tokens = DevetTypography().tokens
        for (m in rows) {
            val (token, _, size, line, weight) = m.destructured
            val (s, l, w) = tokens[token] ?: error("missing type token $token")
            assertEquals("$token size", size.toFloat(), s, 0.01f)
            assertEquals("$token line height", line.toFloat(), l, 0.01f)
            assertEquals("$token weight", weight.toInt(), w)
        }
    }
}

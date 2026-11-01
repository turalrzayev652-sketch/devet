package az.devet.app.data.guests

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PreviewImageGeneratorTest {
    private val generator = PreviewImageGenerator()

    @Test
    fun generatesValidBitmap() {
        val params = PreviewParams(
            displayName = "Elçin müəllim və ailəsi",
            code = "K7D2M9QX",
            lang = "az",
            templateBgColor = "#faf7f2"
        )
        val preview = generator.generate(params)
        assertEquals(1200, preview.bitmap.width)
        assertEquals(630, preview.bitmap.height)
        assertTrue(preview.bytes.isNotEmpty())
    }

    @Test
    fun compressesTo80KB() {
        val params = PreviewParams(
            displayName = "Elçin müəllim və ailəsi",
            code = "K7D2M9QX",
            lang = "az",
            templateBgColor = "#faf7f2"
        )
        val preview = generator.generate(params)
        assertTrue("Image size ${preview.bytes.size} exceeds 80 KB", preview.bytes.size <= 80 * 1024)
    }

    @Test
    fun handlesAllLanguages() {
        listOf("az", "ru", "en", "tr").forEach { lang ->
            val params = PreviewParams(
                displayName = "Test Name",
                code = "CODE123",
                lang = lang,
                templateBgColor = "#ffffff"
            )
            val preview = generator.generate(params)
            assertEquals(1200, preview.bitmap.width)
            assertTrue(preview.bytes.size > 0)
        }
    }

    @Test
    fun handlesDarkAndLightBackgrounds() {
        val darkParams = PreviewParams(
            displayName = "Dark Test",
            code = "DRK12345",
            lang = "az",
            templateBgColor = "#1a1a1a"
        )
        val darkPreview = generator.generate(darkParams)

        val lightParams = PreviewParams(
            displayName = "Light Test",
            code = "LGT12345",
            lang = "az",
            templateBgColor = "#ffffff"
        )
        val lightPreview = generator.generate(lightParams)

        assertTrue(darkPreview.bytes.size > 0)
        assertTrue(lightPreview.bytes.size > 0)
    }

    @Test
    fun returnsCorrectCode() {
        val params = PreviewParams(
            displayName = "Test",
            code = "TESTCODE",
            lang = "az",
            templateBgColor = "#ffffff"
        )
        val preview = generator.generate(params)
        assertEquals("TESTCODE", preview.code)
    }

    @Test
    fun handlesSpecialCharacters() {
        val params = PreviewParams(
            displayName = "Rəşad Əliyev və ailəsi",
            code = "K7D2M9QX",
            lang = "az",
            templateBgColor = "#faf7f2"
        )
        val preview = generator.generate(params)
        assertEquals(1200, preview.bitmap.width)
        assertTrue(preview.bytes.size <= 80 * 1024)
    }

    @Test
    fun handlesInvalidColorGracefully() {
        val params = PreviewParams(
            displayName = "Test",
            code = "TEST",
            lang = "az",
            templateBgColor = "invalid-color"
        )
        val preview = generator.generate(params)
        assertEquals(1200, preview.bitmap.width)
        assertTrue(preview.bytes.size > 0)
    }

    @Test
    fun truncatesToMaxLength() {
        val longName = "A".repeat(100)
        val params = PreviewParams(
            displayName = longName,
            code = "TEST",
            lang = "az",
            templateBgColor = "#ffffff"
        )
        val preview = generator.generate(params)
        assertEquals(1200, preview.bitmap.width)
        assertTrue(preview.bytes.size <= 80 * 1024)
    }
}

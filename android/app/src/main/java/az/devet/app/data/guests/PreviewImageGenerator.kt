package az.devet.app.data.guests

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.util.Log
import java.io.ByteArrayOutputStream
import kotlin.math.max
import kotlin.math.min

/// Canvas-ə əsasən 1200×630 adlı dəvət şəkli yaratmaq (screens.md §8a, PRODUCT §5).
class PreviewImageGenerator {
    companion object {
        private const val WIDTH = 1200
        private const val HEIGHT = 630
        private const val JPEG_QUALITY = 85
        private const val MAX_BYTES = 80 * 1024
        private const val TAG = "PreviewImageGenerator"
    }

    /// Qonaq üçün preview JPEG yaradır: display_name + "lang.invite_text" (qonağın dilində).
    /// Fon rəngi template.customization.colors["--dv-color-bg"] (hex, məs. "#faf7f2") və ya defolt.
    fun generate(params: PreviewParams): PreviewImage {
        val bgColorStr = params.templateBgColor ?: "#faf7f2"
        val bgColor = try {
            Color.parseColor(bgColorStr)
        } catch (e: IllegalArgumentException) {
            Log.w(TAG, "Invalid bg color '$bgColorStr', using default", e)
            Color.parseColor("#faf7f2")
        }

        val bitmap = Bitmap.createBitmap(WIDTH, HEIGHT, Bitmap.Config.RGB_565)
        val canvas = Canvas(bitmap)
        canvas.drawColor(bgColor)

        // Üst padding
        val topPadding = 120f
        val sidePadding = 60f
        val maxWidth = WIDTH - sidePadding * 2

        // Ad (display_name) — serif, böyük, mərkəzə
        val nameSize = 56f
        val namePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = Typeface.SERIF
            textSize = nameSize
            color = contrastColor(bgColor, Color.BLACK, Color.WHITE)
        }
        val name = params.displayName.take(80)  // Uzunluq məhdudiyəti
        val nameWidth = namePaint.measureText(name)
        val nameX = (WIDTH - nameWidth) / 2
        canvas.drawText(name, nameX, topPadding, namePaint)

        // "dəvət edirik" metni — kiçik, alt
        val inviteText = inviteTextByLang[params.lang] ?: inviteTextByLang["az"]!!
        val inviteSize = 36f
        val invitePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = Typeface.DEFAULT
            textSize = inviteSize
            color = contrastColor(bgColor, Color.BLACK, Color.WHITE)
            alpha = 200  // Cümlə daha şəffaf
        }
        val inviteWidth = invitePaint.measureText(inviteText)
        val inviteX = (WIDTH - inviteWidth) / 2
        val inviteY = topPadding + 100
        canvas.drawText(inviteText, inviteX, inviteY, invitePaint)

        // Watermark — mini kod sağ altında (pulsuz şablonlarda dəqiqləşdirmə üçün)
        val watermarkPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = Typeface.MONOSPACE
            textSize = 20f
            color = contrastColor(bgColor, Color.BLACK, Color.WHITE)
            alpha = 128
        }
        canvas.drawText(params.code, WIDTH - 80f, HEIGHT - 20f, watermarkPaint)

        // JPEG səxavət: başlamaq 85%, lazım olarsa azaldıraq
        var quality = JPEG_QUALITY
        var bytes = compressBitmap(bitmap, quality)
        while (bytes.size > MAX_BYTES && quality > 50) {
            quality -= 5
            bytes = compressBitmap(bitmap, quality)
        }

        if (bytes.size > MAX_BYTES) {
            Log.w(TAG, "Preview image ${params.code} is ${bytes.size} bytes, exceeds ${MAX_BYTES}")
        }

        return PreviewImage(bitmap = bitmap, bytes = bytes, code = params.code)
    }

    private fun compressBitmap(bitmap: Bitmap, quality: Int): ByteArray {
        val output = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, quality, output)
        return output.toByteArray()
    }

    /// Fon rənginə uyğun ziddiyyətli mətn rəngi seç (siyah/ağ).
    private fun contrastColor(bgColor: Int, darkOption: Int, lightOption: Int): Int {
        val r = Color.red(bgColor)
        val g = Color.green(bgColor)
        val b = Color.blue(bgColor)
        // Luminance (WCAG): 0.2126 * R + 0.7152 * G + 0.0722 * B
        val luminance = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255
        return if (luminance > 0.5) darkOption else lightOption
    }
}

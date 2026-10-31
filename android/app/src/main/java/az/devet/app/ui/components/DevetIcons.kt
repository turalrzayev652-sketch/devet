package az.devet.app.ui.components

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.addPathNodes
import androidx.compose.ui.unit.dp

/**
 * Line icons from the prototype (design/prototype/proto.js → ICONS; spec/design.md §6): 24×24, stroke 1.5,
 * round caps and joins. `Icon` tints them with the content colour.
 */
object DevetIcons {
    val back = icon("back", "M15 18l-6-6 6-6")
    val chevronRight = icon("chevronRight", "M9 6l6 6-6 6")
    val eye = icon("eye", "M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z", circle(12f, 12f, 3f))
    val eyeOff = icon(
        "eyeOff", "M3 3l18 18", "M10.6 6.1A9.6 9.6 0 0 1 12 6c6.4 0 10 6 10 6a17 17 0 0 1-3.2 3.9",
        "M6.6 6.6C3.8 8.3 2 12 2 12s3.6 7 10 7c1.7 0 3.2-.4 4.5-1.1", "M9.9 9.9a3 3 0 0 0 4.2 4.2",
    )
    val alert = icon("alert", "M12 3.5l9.5 16.5h-19z", "M12 10v4.5M12 17.5v.01")
    val wifiOff = icon(
        "wifiOff", "M3 3l18 18",
        "M8.5 16.5a5 5 0 0 1 7 0M5 13a10 10 0 0 1 4-2.6M19 13a10 10 0 0 0-2.3-1.7M2 9.5a15 15 0 0 1 4.3-2.7M22 9.5A15 15 0 0 0 12 6c-.8 0-1.6.1-2.4.2",
        "M12 20h.01",
    )
    val check = icon("check", "M5 12.5l4.5 4.5L19 7")
    val mail = icon("mail", rect(3f, 5f, 18f, 14f, 2.5f), "M4 7l8 6 8-6")
    val lock = icon("lock", rect(5f, 10.5f, 14f, 10f, 2.5f), "M8 10.5V8a4 4 0 0 1 8 0v2.5")
    val user = icon("user", circle(12f, 8f, 4f), "M4 20.5v-.5A5.5 5.5 0 0 1 9.5 14.5h5A5.5 5.5 0 0 1 20 20v.5")
    val settings = icon("settings", "M4 7h10M18 7h2M4 17h2M10 17h10", circle(16f, 7f, 2f), circle(8f, 17f, 2f))
    val globe = icon("globe", circle(12f, 12f, 9f), "M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18")
    val close = icon("close", "M6 6l12 12M18 6L6 18")
    val more = icon("more", circle(5f, 12f, 1f), circle(12f, 12f, 1f), circle(19f, 12f, 1f))
    val trash = icon("trash", "M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3")

    /** Botanical line drawing behind the sign-in brand (prototype ART.botanical, 393×210). */
    val botanical: ImageVector = ImageVector.Builder("botanical", 393.dp, 210.dp, 393f, 210f).apply {
        fun line(d: String, alpha: Float) = addPath(
            addPathNodes(d), stroke = SolidColor(Color.Black), strokeAlpha = alpha, strokeLineWidth = 1.2f,
            strokeLineCap = StrokeCap.Round,
        )
        line("M-10 190 C 80 150, 120 80, 210 60 S 360 70, 410 20", .55f)
        line(
            "M60 162 c 10 -22 34 -30 52 -24 c -8 20 -30 32 -52 24z M128 110 c 18 -16 42 -14 56 -2 c -16 14 -40 16 -56 2z " +
                "M196 66 c 6 -24 28 -38 48 -36 c -4 22 -26 38 -48 36z M262 58 c 20 -10 42 -2 52 12 c -20 8 -42 2 -52 -12z " +
                "M330 44 c 8 -20 30 -28 48 -22 c -8 18 -30 28 -48 22z",
            .7f,
        )
        line("M40 205 C 110 175, 150 140, 170 100", .35f)
        line(circle(214f, 58f, 3f), .6f)
        line(circle(300f, 52f, 2.5f), .6f)
    }.build()

    /** Envelope mark for the "check your e-mail" screens (prototype ART.emptyGuests, 180×140). */
    val envelope: ImageVector = ImageVector.Builder("envelope", 180.dp, 140.dp, 180f, 140f).apply {
        fun line(d: String, alpha: Float) = addPath(
            addPathNodes(d), stroke = SolidColor(Color.Black), strokeAlpha = alpha, strokeLineWidth = 1.4f,
            strokeLineCap = StrokeCap.Round, strokeLineJoin = StrokeJoin.Round,
        )
        line(rect(40f, 22f, 100f, 80f, 10f), .9f)
        line("M40 34 L90 70 L140 34", .9f)
        line("M20 118 C 50 100, 70 128, 100 112 S 150 104, 166 118", .5f)
        line("M150 18 l3 8 8 3 -8 3 -3 8 -3 -8 -8 -3 8 -3z", .8f)
        line("M28 44 l2 5 5 2 -5 2 -2 5 -2 -5 -5 -2 5 -2z", .6f)
    }.build()

    private fun icon(name: String, vararg paths: String): ImageVector =
        ImageVector.Builder(name, 24.dp, 24.dp, 24f, 24f).apply {
            paths.forEach {
                addPath(
                    addPathNodes(it), stroke = SolidColor(Color.Black), strokeLineWidth = 1.5f,
                    strokeLineCap = StrokeCap.Round, strokeLineJoin = StrokeJoin.Round,
                )
            }
        }.build()

    private fun circle(cx: Float, cy: Float, r: Float) = "M${cx - r} ${cy}a$r $r 0 1 0 ${2 * r} 0a$r $r 0 1 0 ${-2 * r} 0"

    private fun rect(x: Float, y: Float, w: Float, h: Float, r: Float) =
        "M${x + r} ${y}h${w - 2 * r}a$r $r 0 0 1 $r ${r}v${h - 2 * r}a$r $r 0 0 1 ${-r} ${r}h${-(w - 2 * r)}" +
            "a$r $r 0 0 1 ${-r} ${-r}v${-(h - 2 * r)}a$r $r 0 0 1 $r ${-r}z"
}

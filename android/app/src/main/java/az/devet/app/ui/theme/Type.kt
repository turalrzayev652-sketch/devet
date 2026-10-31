package az.devet.app.ui.theme

import androidx.compose.runtime.Immutable
import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.font.FontVariation.Settings
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import az.devet.app.R

// Bundled variable fonts (OFL): both contain all Azerbaijani letters and Cyrillic (checked; spec/design.md §1).
// Font(resId, …, variationSettings) is still marked experimental in Compose; the API is stable in practice.
@OptIn(ExperimentalTextApi::class)
private fun inter(weight: Int) = Font(R.font.inter_variable, FontWeight(weight), variationSettings = Settings(FontVariation.weight(weight)))

@OptIn(ExperimentalTextApi::class)
private fun serif(weight: Int) = Font(R.font.noto_serif_display_variable, FontWeight(weight), variationSettings = Settings(FontVariation.weight(weight)))

val InterFamily = FontFamily(inter(400), inter(500), inter(600))
val SerifFamily = FontFamily(serif(500), serif(600))

/** Type tokens from spec/design.md §3 (`type.serif.display` → [serifDisplay]). Sizes in sp follow font scaling. */
@Immutable
data class DevetTypography(
    val serifDisplay: TextStyle = TextStyle(fontFamily = SerifFamily, fontWeight = FontWeight.Medium, fontSize = 34.sp, lineHeight = 40.sp, letterSpacing = (-0.01).em),
    val serifTitle: TextStyle = TextStyle(fontFamily = SerifFamily, fontWeight = FontWeight.Medium, fontSize = 28.sp, lineHeight = 34.sp),
    val serifHeadline: TextStyle = TextStyle(fontFamily = SerifFamily, fontWeight = FontWeight.SemiBold, fontSize = 22.sp, lineHeight = 28.sp),
    val title1: TextStyle = TextStyle(fontFamily = InterFamily, fontWeight = FontWeight.SemiBold, fontSize = 28.sp, lineHeight = 34.sp),
    val title2: TextStyle = TextStyle(fontFamily = InterFamily, fontWeight = FontWeight.SemiBold, fontSize = 22.sp, lineHeight = 28.sp),
    val headline: TextStyle = TextStyle(fontFamily = InterFamily, fontWeight = FontWeight.SemiBold, fontSize = 17.sp, lineHeight = 24.sp),
    val body: TextStyle = TextStyle(fontFamily = InterFamily, fontWeight = FontWeight.Normal, fontSize = 17.sp, lineHeight = 24.sp),
    val callout: TextStyle = TextStyle(fontFamily = InterFamily, fontWeight = FontWeight.Normal, fontSize = 15.sp, lineHeight = 20.sp),
    val footnote: TextStyle = TextStyle(fontFamily = InterFamily, fontWeight = FontWeight.Normal, fontSize = 13.sp, lineHeight = 18.sp),
    val caption: TextStyle = TextStyle(fontFamily = InterFamily, fontWeight = FontWeight.Medium, fontSize = 11.sp, lineHeight = 14.sp, letterSpacing = 0.02.em),
) {
    /** `type.*` token → (size sp, line height sp, weight) for the design.md comparison test. */
    val tokens: Map<String, Triple<Float, Float, Int>>
        get() = mapOf(
            "type.serif.display" to serifDisplay, "type.serif.title" to serifTitle, "type.serif.headline" to serifHeadline,
            "type.sans.title1" to title1, "type.sans.title2" to title2, "type.sans.headline" to headline,
            "type.sans.body" to body, "type.sans.callout" to callout, "type.sans.footnote" to footnote, "type.sans.caption" to caption,
        ).mapValues { (_, s) -> Triple(s.fontSize.value, s.lineHeight.value, s.fontWeight!!.weight) }
}

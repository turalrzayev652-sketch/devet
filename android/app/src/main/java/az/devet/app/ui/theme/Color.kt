package az.devet.app.ui.theme

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color

/** One guest status: dot/icon colour, pill text and pill background (spec/design.md §2.2). */
@Immutable
data class StatusColors(val fg: Color, val text: Color, val bg: Color)

/**
 * Colour tokens from spec/design.md §2. Names follow the token names: `color.brand.primary` → [brandPrimary].
 * [tokens] lists every value under its token name; a unit test compares it with design.md.
 */
@Immutable
data class DevetColors(
    val bgCanvas: Color,
    val bgSurface: Color,
    val bgSunken: Color,
    val bgRaised: Color,
    val bgOverlay: Color,
    val textPrimary: Color,
    val textSecondary: Color,
    val textOnBrand: Color,
    val textLink: Color,
    val borderHairline: Color,
    val borderControl: Color,
    val borderFocus: Color,
    val brandPrimary: Color,
    val brandPressed: Color,
    val brandSubtle: Color,
    val accentGold: Color,
    val accentGoldStrong: Color,
    val accentGoldText: Color,
    val accentGoldSubtle: Color,
    val feedbackDanger: Color,
    val feedbackDangerBg: Color,
    val feedbackSuccess: Color,
    val feedbackSuccessBg: Color,
    val feedbackWarning: Color,
    val feedbackWarningBg: Color,
    val whatsapp: Color,
    val statusComing: StatusColors,
    val statusDeclined: StatusColors,
    val statusViewed: StatusColors,
    val statusPending: StatusColors,
    val statusUnsent: StatusColors,
    val isDark: Boolean,
) {
    val tokens: Map<String, Color>
        get() = buildMap {
            put("color.bg.canvas", bgCanvas)
            put("color.bg.surface", bgSurface)
            put("color.bg.sunken", bgSunken)
            put("color.bg.raised", bgRaised)
            put("color.text.primary", textPrimary)
            put("color.text.secondary", textSecondary)
            put("color.text.onBrand", textOnBrand)
            put("color.text.link", textLink)
            put("color.border.hairline", borderHairline)
            put("color.border.control", borderControl)
            put("color.border.focus", borderFocus)
            put("color.brand.primary", brandPrimary)
            put("color.brand.pressed", brandPressed)
            put("color.brand.subtle", brandSubtle)
            put("color.accent.gold", accentGold)
            put("color.accent.goldStrong", accentGoldStrong)
            put("color.accent.goldText", accentGoldText)
            put("color.accent.goldSubtle", accentGoldSubtle)
            put("color.feedback.danger", feedbackDanger)
            put("color.feedback.dangerBg", feedbackDangerBg)
            put("color.feedback.success", feedbackSuccess)
            put("color.feedback.successBg", feedbackSuccessBg)
            put("color.feedback.warning", feedbackWarning)
            put("color.feedback.warningBg", feedbackWarningBg)
            put("color.whatsapp", whatsapp)
            listOf(
                "coming" to statusComing, "declined" to statusDeclined, "viewed" to statusViewed,
                "pending" to statusPending, "unsent" to statusUnsent,
            ).forEach { (name, s) ->
                put("color.status.$name.fg", s.fg)
                put("color.status.$name.text", s.text)
                put("color.status.$name.bg", s.bg)
            }
        }
}

val LightColors = DevetColors(
    bgCanvas = Color(0xFFFAF7F2),
    bgSurface = Color(0xFFFFFFFF),
    bgSunken = Color(0xFFF3EEE7),
    bgRaised = Color(0xFFFFFFFF),
    bgOverlay = Color(0x661F1B24),
    textPrimary = Color(0xFF1F1B24),
    textSecondary = Color(0xFF6B6470),
    textOnBrand = Color(0xFFFFFFFF),
    textLink = Color(0xFF4A2C4F),
    borderHairline = Color(0xFFEAE4DC),
    borderControl = Color(0xFF8F8790),
    borderFocus = Color(0xFF4A2C4F),
    brandPrimary = Color(0xFF4A2C4F),
    brandPressed = Color(0xFF3A2140),
    brandSubtle = Color(0xFFEFE8F0),
    accentGold = Color(0xFFC9A66B),
    accentGoldStrong = Color(0xFFA3813A),
    accentGoldText = Color(0xFF7A5C27),
    accentGoldSubtle = Color(0xFFF6EEDF),
    feedbackDanger = Color(0xFFA8423B),
    feedbackDangerBg = Color(0xFFF7E6E4),
    feedbackSuccess = Color(0xFF3F6B4B),
    feedbackSuccessBg = Color(0xFFE7F0E9),
    feedbackWarning = Color(0xFF7A5C27),
    feedbackWarningBg = Color(0xFFF6EEDF),
    whatsapp = Color(0xFF25D366),
    statusComing = StatusColors(Color(0xFF4E7D5B), Color(0xFF3F6B4B), Color(0xFFE7F0E9)),
    statusDeclined = StatusColors(Color(0xFFB5564F), Color(0xFF9E443D), Color(0xFFF7E6E4)),
    statusViewed = StatusColors(Color(0xFF5B7896), Color(0xFF4A6683), Color(0xFFE5ECF3)),
    statusPending = StatusColors(Color(0xFF9A9299), Color(0xFF625B66), Color(0xFFEFECEF)),
    statusUnsent = StatusColors(Color(0xFF6B6470), Color(0xFF6B6470), Color(0xFFF3EEE7)),
    isDark = false,
)

val DarkColors = DevetColors(
    bgCanvas = Color(0xFF151217),
    bgSurface = Color(0xFF211C24),
    bgSunken = Color(0xFF1A161D),
    bgRaised = Color(0xFF2B2530),
    bgOverlay = Color(0x99000000),
    textPrimary = Color(0xFFF3EEF4),
    textSecondary = Color(0xFFB8AFBB),
    textOnBrand = Color(0xFF1F1B24),
    textLink = Color(0xFFC9A3CF),
    borderHairline = Color(0xFF352E39),
    borderControl = Color(0xFF7E7581),
    borderFocus = Color(0xFFC9A3CF),
    brandPrimary = Color(0xFFC9A3CF),
    brandPressed = Color(0xFFB48BBA),
    brandSubtle = Color(0xFF3A2D3E),
    accentGold = Color(0xFFC9A66B),
    accentGoldStrong = Color(0xFFC9A66B),
    accentGoldText = Color(0xFFD9BC86),
    accentGoldSubtle = Color(0xFF3A3122),
    feedbackDanger = Color(0xFFEC9A93),
    feedbackDangerBg = Color(0xFF3F2422),
    feedbackSuccess = Color(0xFF8CC59A),
    feedbackSuccessBg = Color(0xFF22342A),
    feedbackWarning = Color(0xFFD9BC86),
    feedbackWarningBg = Color(0xFF3A3122),
    whatsapp = Color(0xFF25D366),
    statusComing = StatusColors(Color(0xFF8CC59A), Color(0xFF8CC59A), Color(0xFF22342A)),
    statusDeclined = StatusColors(Color(0xFFEC9A93), Color(0xFFEC9A93), Color(0xFF3F2422)),
    statusViewed = StatusColors(Color(0xFFA3BCD8), Color(0xFFA3BCD8), Color(0xFF22303D)),
    statusPending = StatusColors(Color(0xFF9F97A2), Color(0xFFC2BAC2), Color(0xFF2F2A31)),
    statusUnsent = StatusColors(Color(0xFF8C8390), Color(0xFFB8AFBB), Color(0xFF2B2530)),
    isDark = true,
)

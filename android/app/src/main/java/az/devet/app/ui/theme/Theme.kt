package az.devet.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.staticCompositionLocalOf

private val LocalColors = staticCompositionLocalOf { LightColors }
private val LocalTypography = staticCompositionLocalOf { DevetTypography() }

/** Access tokens in UI code: `DevetTheme.colors.brandPrimary`, `DevetTheme.type.serifTitle`. */
object DevetTheme {
    val colors: DevetColors
        @Composable @ReadOnlyComposable get() = LocalColors.current
    val type: DevetTypography
        @Composable @ReadOnlyComposable get() = LocalTypography.current
}

// Material 3 components (dialogs, sheets, text fields) read their colours from this mapping.
private fun DevetColors.toMaterial(): ColorScheme {
    val base = if (isDark) darkColorScheme() else lightColorScheme()
    return base.copy(
        primary = brandPrimary, onPrimary = textOnBrand, primaryContainer = brandSubtle, onPrimaryContainer = brandPrimary,
        secondary = accentGoldStrong, onSecondary = textOnBrand, secondaryContainer = accentGoldSubtle, onSecondaryContainer = accentGoldText,
        background = bgCanvas, onBackground = textPrimary, surface = bgSurface, onSurface = textPrimary,
        surfaceVariant = bgSunken, onSurfaceVariant = textSecondary, surfaceContainer = bgSurface, surfaceContainerHigh = bgRaised,
        outline = borderControl, outlineVariant = borderHairline, error = feedbackDanger, onError = textOnBrand,
        errorContainer = feedbackDangerBg, onErrorContainer = feedbackDanger, scrim = bgOverlay,
    )
}

private fun DevetTypography.toMaterial() = Typography(
    displaySmall = serifDisplay, headlineLarge = serifTitle, headlineMedium = serifHeadline,
    titleLarge = title2, titleMedium = headline, bodyLarge = body, bodyMedium = callout,
    bodySmall = footnote, labelLarge = headline, labelMedium = footnote, labelSmall = caption,
)

@Composable
fun DevetTheme(darkTheme: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    val colors = if (darkTheme) DarkColors else LightColors
    val type = DevetTypography()
    CompositionLocalProvider(LocalColors provides colors, LocalTypography provides type) {
        MaterialTheme(colorScheme = colors.toMaterial(), typography = type.toMaterial(), content = content)
    }
}

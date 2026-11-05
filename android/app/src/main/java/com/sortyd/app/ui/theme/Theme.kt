package com.sortyd.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.graphics.Color

// ── Custom color slots not in M3 ──
data class SortydExtendedColors(
    val warning: Color,
    val onWarning: Color,
    val success: Color,
    val onSuccess: Color,
    val danger: Color,
    val onDanger: Color,
    val accent: Color,
    val coral: Color,
    val bg0: Color,
    val bg1: Color,
    val bg2: Color,
    val bg3: Color,
    val text0: Color,
    val text1: Color,
    val text2: Color,
    val borderAccent: Color,
    val borderSubtle: Color,
    val healthSteps: Color,
    val healthCalories: Color,
    val healthDistance: Color,
    val healthScreenTime: Color,
    val todoGreen: Color,
)

val LocalSortydColors = compositionLocalOf {
    SortydExtendedColors(
        warning = WarningColor,
        onWarning = OnWarning,
        success = SuccessColor,
        onSuccess = OnSuccess,
        danger = DangerColor,
        onDanger = OnDanger,
        accent = AccentDark,
        coral = CoralDark,
        bg0 = Bg0Dark,
        bg1 = Bg1Dark,
        bg2 = Bg2Dark,
        bg3 = Bg3Dark,
        text0 = Text0Dark,
        text1 = Text1Dark,
        text2 = Text2Dark,
        borderAccent = BorderAccentDark,
        borderSubtle = BorderSubtleDark,
        healthSteps = HealthSteps,
        healthCalories = HealthCalories,
        healthDistance = HealthDistance,
        healthScreenTime = HealthScreenTime,
        todoGreen = TodoGreen,
    )
}

private val DarkColorScheme = darkColorScheme(
    primary = AccentDark,
    onPrimary = OnAccentDark,
    secondary = CoralDark,
    onSecondary = OnCoralDark,
    tertiary = SuccessColor,
    error = DangerColor,
    onError = OnDanger,
    background = Bg0Dark,
    onBackground = Text0Dark,
    surface = Bg1Dark,
    onSurface = Text0Dark,
    surfaceVariant = Bg2Dark,
    onSurfaceVariant = Text1Dark,
    outline = Text2Dark,
    outlineVariant = Bg3Dark,
)

private val LightColorScheme = lightColorScheme(
    primary = AccentLight,
    onPrimary = Color.White,
    secondary = CoralLight,
    onSecondary = Color.White,
    tertiary = SuccessColor,
    error = DangerColor,
    onError = Color.White,
    background = Bg0Light,
    onBackground = Text0Light,
    surface = Bg1Light,
    onSurface = Text0Light,
    surfaceVariant = Bg2Light,
    onSurfaceVariant = Text1Light,
    outline = Text2Light,
    outlineVariant = Bg3Light,
)

private val DarkExtendedColors = SortydExtendedColors(
    warning = WarningColor,
    onWarning = OnWarning,
    success = SuccessColor,
    onSuccess = OnSuccess,
    danger = DangerColor,
    onDanger = OnDanger,
    accent = AccentDark,
    coral = CoralDark,
    bg0 = Bg0Dark,
    bg1 = Bg1Dark,
    bg2 = Bg2Dark,
    bg3 = Bg3Dark,
    text0 = Text0Dark,
    text1 = Text1Dark,
    text2 = Text2Dark,
    borderAccent = BorderAccentDark,
    borderSubtle = BorderSubtleDark,
    healthSteps = HealthSteps,
    healthCalories = HealthCalories,
    healthDistance = HealthDistance,
    healthScreenTime = HealthScreenTime,
    todoGreen = TodoGreen,
)

private val LightExtendedColors = SortydExtendedColors(
    warning = WarningColor,
    onWarning = OnWarning,
    success = SuccessColor,
    onSuccess = OnSuccess,
    danger = DangerColor,
    onDanger = OnDanger,
    accent = AccentLight,
    coral = CoralLight,
    bg0 = Bg0Light,
    bg1 = Bg1Light,
    bg2 = Bg2Light,
    bg3 = Bg3Light,
    text0 = Text0Light,
    text1 = Text1Light,
    text2 = Text2Light,
    borderAccent = BorderAccentLight,
    borderSubtle = BorderSubtleLight,
    healthSteps = HealthSteps,
    healthCalories = HealthCalories,
    healthDistance = HealthDistance,
    healthScreenTime = HealthScreenTime,
    todoGreen = TodoGreen,
)

@Composable
fun SortydTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    appFont: AppFont = AppFont.ROUNDED,
    content: @Composable () -> Unit,
) {
    val colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme
    val extendedColors = if (darkTheme) DarkExtendedColors else LightExtendedColors

    CompositionLocalProvider(
        LocalSortydColors provides extendedColors,
    ) {
        MaterialTheme(
            colorScheme = colorScheme,
            typography = sortydTypography(appFont),
            shapes = SortydShapes,
            content = content,
        )
    }
}

// Convenience accessor
object SortydColors {
    val current: SortydExtendedColors
        @Composable get() = LocalSortydColors.current
}

package com.sortyd.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

// ─── Brand Colors ─────────────────────────────────────────────────────────────

val Teal = Color(0xFF00D9FF)
val Violet = Color(0xFF7C6FFF)
val VioletLight = Color(0xFF5A4ECC)

// Dark palette
val DarkBG0 = Color(0xFF0A0A0A)
val DarkBG1 = Color(0xFF141414)
val DarkBG2 = Color(0xFF1E1E1E)
val DarkBG3 = Color(0xFF282828)
val DarkText0 = Color(0xFFEDEDED)
val DarkText1 = Color(0xFFA0A0A0)
val DarkText2 = Color(0xFF636363)
val DarkAccent = Teal
val DarkCoral = Color(0xFF00C4B4)
val DarkSuccess = Color(0xFF4FD49A)
val DarkWarning = Color(0xFFFFBC55)
val DarkDanger = Color(0xFFFF6B6B)
val DarkGlassBorder = Color(0x1AFFFFFF)

// Light palette
val LightBG0 = Color(0xFFF2F2FA)
val LightBG1 = Color(0xFFFAFAFF)
val LightBG2 = Color(0xFFEAEAF5)
val LightBG3 = Color(0xFFDDDDF0)
val LightText0 = Color(0xFF0C0D16)
val LightText1 = Color(0xFF4A4A80)
val LightText2 = Color(0xFF9090B8)
val LightAccent = VioletLight
val LightSuccess = Color(0xFF12A362)
val LightWarning = Color(0xFFD4850A)
val LightDanger = Color(0xFFCC2222)
val LightGlassBorder = Color(0x1A5A4ECC)

// Health task colors
val StepsColor = Color(0xFF4FC3F7)
val CaloriesColor = Color(0xFFFF7043)
val DistanceColor = Color(0xFF4CAF50)

// ─── SortydColors ─────────────────────────────────────────────────────────────

data class SortydColors(
    val bg0: Color,
    val bg1: Color,
    val bg2: Color,
    val bg3: Color,
    val text0: Color,
    val text1: Color,
    val text2: Color,
    val accent: Color,
    val teal: Color,
    val violet: Color,
    val success: Color,
    val warning: Color,
    val danger: Color,
    val coral: Color,
    val glassBorder: Color,
    val isDark: Boolean
)

val LocalSortydColors = staticCompositionLocalOf {
    darkSortydColors()
}

fun darkSortydColors() = SortydColors(
    bg0 = DarkBG0, bg1 = DarkBG1, bg2 = DarkBG2, bg3 = DarkBG3,
    text0 = DarkText0, text1 = DarkText1, text2 = DarkText2,
    accent = DarkAccent, teal = Teal, violet = Violet,
    success = DarkSuccess, warning = DarkWarning, danger = DarkDanger,
    coral = DarkCoral,
    glassBorder = DarkGlassBorder, isDark = true
)

fun lightSortydColors() = SortydColors(
    bg0 = LightBG0, bg1 = LightBG1, bg2 = LightBG2, bg3 = LightBG3,
    text0 = LightText0, text1 = LightText1, text2 = LightText2,
    accent = LightAccent, teal = VioletLight, violet = Violet,
    success = LightSuccess, warning = LightWarning, danger = LightDanger,
    coral = Color(0xFF00C4B4), // Default light coral
    glassBorder = LightGlassBorder, isDark = false
)

val sortydColors: SortydColors
    @Composable
    @ReadOnlyComposable
    get() = LocalSortydColors.current

// ─── Typography ───────────────────────────────────────────────────────────────

val SortydTypography = Typography(
    displayLarge = TextStyle(fontSize = 34.sp, fontWeight = FontWeight.Black, fontFamily = FontFamily.Default),
    headlineLarge = TextStyle(fontSize = 26.sp, fontWeight = FontWeight.Bold),
    headlineMedium = TextStyle(fontSize = 20.sp, fontWeight = FontWeight.Bold),
    headlineSmall = TextStyle(fontSize = 17.sp, fontWeight = FontWeight.SemiBold),
    bodyLarge = TextStyle(fontSize = 15.sp, fontWeight = FontWeight.Normal),
    bodyMedium = TextStyle(fontSize = 13.sp, fontWeight = FontWeight.Normal),
    bodySmall = TextStyle(fontSize = 11.sp, fontWeight = FontWeight.Normal),
    labelMedium = TextStyle(fontSize = 11.sp, fontWeight = FontWeight.SemiBold),
    labelSmall = TextStyle(fontSize = 9.sp, fontWeight = FontWeight.SemiBold)
)

// ─── Material3 Color Scheme ───────────────────────────────────────────────────

private val DarkColorScheme = darkColorScheme(
    primary = Teal,
    secondary = Violet,
    background = DarkBG0,
    surface = DarkBG1,
    onBackground = DarkText0,
    onSurface = DarkText0
)

private val LightColorScheme = lightColorScheme(
    primary = VioletLight,
    secondary = Violet,
    background = LightBG0,
    surface = LightBG1,
    onBackground = LightText0,
    onSurface = LightText0
)

// ─── Theme Entry Point ────────────────────────────────────────────────────────

@Composable
fun SortydTheme(
    isDark: Boolean = true,
    content: @Composable () -> Unit
) {
    val sortydColors = if (isDark) darkSortydColors() else lightSortydColors()
    val colorScheme = if (isDark) DarkColorScheme else LightColorScheme

    CompositionLocalProvider(LocalSortydColors provides sortydColors) {
        MaterialTheme(
            colorScheme = colorScheme,
            typography = SortydTypography,
            content = content
        )
    }
}

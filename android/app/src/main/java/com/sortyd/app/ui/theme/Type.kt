package com.sortyd.app.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.googlefonts.Font
import androidx.compose.ui.text.googlefonts.GoogleFont
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import com.sortyd.app.R

import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind

// ── Text Glow Extension ──
fun TextStyle.glow(color: Color, radius: Float = 8f): TextStyle {
    return this.copy(
        shadow = Shadow(
            color = color.copy(alpha = 0.5f),
            offset = Offset.Zero,
            blurRadius = radius
        )
    )
}

// ── Modifier Glow Extension ──
fun Modifier.glow(color: Color, radius: Float = 8f): Modifier = this.drawBehind {
    drawCircle(
        color = color.copy(alpha = 0.15f),
        radius = size.minDimension / 2 + radius,
        center = center
    )
}

val provider = GoogleFont.Provider(
    providerAuthority = "com.google.android.gms.fonts",
    providerPackage = "com.google.android.gms",
    certificates = R.array.com_google_android_gms_fonts_certs
)

// ── Font Families ──
val NunitoFamily = FontFamily(
    Font(googleFont = GoogleFont("Nunito"), fontProvider = provider, weight = FontWeight.Light),
    Font(googleFont = GoogleFont("Nunito"), fontProvider = provider, weight = FontWeight.Normal),
    Font(googleFont = GoogleFont("Nunito"), fontProvider = provider, weight = FontWeight.Medium),
    Font(googleFont = GoogleFont("Nunito"), fontProvider = provider, weight = FontWeight.SemiBold),
    Font(googleFont = GoogleFont("Nunito"), fontProvider = provider, weight = FontWeight.Bold),
    Font(googleFont = GoogleFont("Nunito"), fontProvider = provider, weight = FontWeight.ExtraBold),
    Font(googleFont = GoogleFont("Nunito"), fontProvider = provider, weight = FontWeight.Black),
)

val RobotoFamily = FontFamily(
    Font(googleFont = GoogleFont("Roboto"), fontProvider = provider, weight = FontWeight.Normal),
    Font(googleFont = GoogleFont("Roboto"), fontProvider = provider, weight = FontWeight.Medium),
    Font(googleFont = GoogleFont("Roboto"), fontProvider = provider, weight = FontWeight.Bold),
)

val LoraFamily = FontFamily(
    Font(googleFont = GoogleFont("Lora"), fontProvider = provider, weight = FontWeight.Normal),
    Font(googleFont = GoogleFont("Lora"), fontProvider = provider, weight = FontWeight.Medium),
    Font(googleFont = GoogleFont("Lora"), fontProvider = provider, weight = FontWeight.Bold),
)

val JetBrainsMonoFamily = FontFamily(
    Font(googleFont = GoogleFont("JetBrains Mono"), fontProvider = provider, weight = FontWeight.Normal),
    Font(googleFont = GoogleFont("JetBrains Mono"), fontProvider = provider, weight = FontWeight.Medium),
    Font(googleFont = GoogleFont("JetBrains Mono"), fontProvider = provider, weight = FontWeight.Bold),
)

// ── Enum matching iOS AppFont ──
enum class AppFont(val family: FontFamily, val label: String) {
    ROUNDED(NunitoFamily, "Rounded"),
    SANS(RobotoFamily, "Sans"),
    SERIF(LoraFamily, "Serif"),
    MONO(JetBrainsMonoFamily, "Mono"),
}

fun sortydTypography(font: AppFont = AppFont.ROUNDED): Typography {
    val ff = font.family
    return Typography(
        displaySmall = TextStyle(          // h1 — 34sp heavy
            fontFamily = ff,
            fontWeight = FontWeight.Black,
            fontSize = 34.sp,
            letterSpacing = (-0.02).em,
        ),
        headlineMedium = TextStyle(        // h2 — 24sp bold
            fontFamily = ff,
            fontWeight = FontWeight.Bold,
            fontSize = 24.sp,
            letterSpacing = (-0.01).em,
        ),
        headlineSmall = TextStyle(         // h3 — 20sp bold
            fontFamily = ff,
            fontWeight = FontWeight.Bold,
            fontSize = 20.sp,
        ),
        bodyLarge = TextStyle(             // body — 16sp medium
            fontFamily = ff,
            fontWeight = FontWeight.Medium,
            fontSize = 16.sp,
            lineHeight = 24.sp,
        ),
        bodyMedium = TextStyle(            // sub — 14sp medium
            fontFamily = ff,
            fontWeight = FontWeight.Medium,
            fontSize = 14.sp,
            lineHeight = 20.sp,
        ),
        bodySmall = TextStyle(             // small body — 12sp
            fontFamily = ff,
            fontWeight = FontWeight.Normal,
            fontSize = 12.sp,
            lineHeight = 18.sp,
        ),
        labelLarge = TextStyle(            // button — 14sp semibold
            fontFamily = ff,
            fontWeight = FontWeight.SemiBold,
            fontSize = 14.sp,
            letterSpacing = 0.04.em,
        ),
        labelMedium = TextStyle(           // caption — 12sp semibold
            fontFamily = ff,
            fontWeight = FontWeight.SemiBold,
            fontSize = 12.sp,
            letterSpacing = 0.06.em,
        ),
        labelSmall = TextStyle(            // tiny — 10sp bold
            fontFamily = ff,
            fontWeight = FontWeight.Bold,
            fontSize = 10.sp,
            letterSpacing = 0.12.em,
        ),
        titleLarge = TextStyle(            // section title — 18sp bold
            fontFamily = ff,
            fontWeight = FontWeight.Bold,
            fontSize = 18.sp,
        ),
        titleMedium = TextStyle(           // card title — 14sp semibold
            fontFamily = ff,
            fontWeight = FontWeight.SemiBold,
            fontSize = 14.sp,
        ),
        titleSmall = TextStyle(            // small title — 12sp semibold
            fontFamily = ff,
            fontWeight = FontWeight.SemiBold,
            fontSize = 12.sp,
            letterSpacing = 0.08.em,
        ),
    )
}

// Custom hero percentage style (not in Material typography scale)
val HeroPercentageStyle = TextStyle(
    fontFamily = NunitoFamily,
    fontWeight = FontWeight.Black,
    fontSize = 72.sp,
    letterSpacing = (-0.04).em,
)

// Section label tracking style
val SectionLabelStyle = TextStyle(
    fontFamily = NunitoFamily,
    fontWeight = FontWeight.Bold,
    fontSize = 10.sp,
    letterSpacing = 0.12.em,
)

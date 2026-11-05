package com.sortyd.app.ui.components

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.sortyd.app.ui.theme.SortydColors
import java.util.*

@Composable
fun CheatBlockPopup(
    onDismiss: () -> Unit
) {
    val colors = SortydColors.current
    
    val locale = Locale.getDefault().language
    val (title, message, emoji) = when (locale) {
        "es" -> Triple("¡No hagas trampa!", "Editar el pasado es para viajeros en el tiempo. ¡Concéntrate en hoy!", "🛑")
        "ar" -> Triple("لا غش!", "تعديل الماضي للمسافرين عبر الزمن. ركز على اليوم!", "🛑")
        else -> Triple("No Cheating!", "Editing the past is for time travelers. Focus on today!", "🛑")
    }

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black.copy(alpha = 0.7f)),
            contentAlignment = Alignment.Center
        ) {
            // Organic Blobs Background
            OrganicBlobsOverlay()

            Card(
                modifier = Modifier
                    .padding(32.dp)
                    .widthIn(max = 400.dp),
                shape = RoundedCornerShape(24.dp),
                colors = CardDefaults.cardColors(containerColor = colors.bg1.copy(alpha = 0.95f)),
                elevation = CardDefaults.cardElevation(defaultElevation = 8.dp)
            ) {
                Column(
                    modifier = Modifier.padding(24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        text = emoji,
                        fontSize = 48.sp,
                        modifier = Modifier.padding(bottom = 16.dp)
                    )
                    
                    Text(
                        text = title,
                        style = MaterialTheme.typography.headlineSmall.copy(fontWeight = FontWeight.Bold),
                        color = colors.text0,
                        textAlign = TextAlign.Center
                    )
                    
                    Spacer(modifier = Modifier.height(8.dp))
                    
                    Text(
                        text = message,
                        style = MaterialTheme.typography.bodyMedium,
                        color = colors.text2,
                        textAlign = TextAlign.Center
                    )
                    
                    Spacer(modifier = Modifier.height(24.dp))
                    
                    Button(
                        onClick = onDismiss,
                        colors = ButtonDefaults.buttonColors(containerColor = colors.accent),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(
                            text = if (locale == "es") "Entendido" else if (locale == "ar") "فهمت" else "Got it",
                            color = Color.Black,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun OrganicBlobsOverlay() {
    val colors = SortydColors.current
    
    Box(modifier = Modifier.fillMaxSize().blur(60.dp)) {
        Blob(color = colors.accent, period = 3800, offsetScale = 0.2f)
        Blob(color = colors.coral, period = 4400, offsetScale = 0.3f)
        Blob(color = colors.accent.copy(alpha = 0.5f), period = 5000, offsetScale = 0.25f)
    }
}

@Composable
private fun Blob(color: Color, period: Int, offsetScale: Float) {
    val infiniteTransition = rememberInfiniteTransition(label = "blob")
    
    val xOffset by infiniteTransition.animateFloat(
        initialValue = -100f,
        targetValue = 100f,
        animationSpec = infiniteRepeatable(
            animation = tween(period, easing = EaseInOut),
            repeatMode = RepeatMode.Reverse
        ),
        label = "xOffset"
    )
    
    val yOffset by infiniteTransition.animateFloat(
        initialValue = -100f,
        targetValue = 100f,
        animationSpec = infiniteRepeatable(
            animation = tween((period * 1.3).toInt(), easing = EaseInOut),
            repeatMode = RepeatMode.Reverse
        ),
        label = "yOffset"
    )

    Canvas(modifier = Modifier.fillMaxSize()) {
        drawCircle(
            brush = Brush.radialGradient(
                colors = listOf(color.copy(alpha = 0.4f), Color.Transparent),
                center = center + androidx.compose.ui.geometry.Offset(xOffset * offsetScale * size.width / 100, yOffset * offsetScale * size.height / 100),
                radius = size.minDimension * 0.4f
            ),
            center = center + androidx.compose.ui.geometry.Offset(xOffset * offsetScale * size.width / 100, yOffset * offsetScale * size.height / 100),
            radius = size.minDimension * 0.4f
        )
    }
}

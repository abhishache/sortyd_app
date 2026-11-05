package com.sortyd.app.ui.overlays

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sortyd.app.ui.localization.SortydStrings
import com.sortyd.app.ui.theme.SortydColors
import kotlinx.coroutines.delay

@Composable
fun GhostDayOverlay(
    visible: Boolean,
    onDismiss: () -> Unit,
    onGoToToday: () -> Unit,
    language: String = "en",
) {
    val colors = SortydColors.current
    val messages = remember(language) {
        listOf(
            Triple("🎉", SortydStrings.t(language, "Perfect Day!"), SortydStrings.t(language, "You crushed every single task. Keep this energy going!")),
            Triple("🏆", SortydStrings.t(language, "Champion!"), SortydStrings.t(language, "100% completion. You are unstoppable!")),
            Triple("⭐", SortydStrings.t(language, "Flawless!"), SortydStrings.t(language, "Not a single task missed. That is dedication!")),
        )
    }
    val message = remember(messages) { messages.random() }

    // Auto-dismiss after 4 seconds
    LaunchedEffect(visible) {
        if (visible) {
            delay(4000)
            onDismiss()
        }
    }

    AnimatedVisibility(
        visible = visible,
        enter = fadeIn(tween(300)),
        exit = fadeOut(tween(450)),
    ) {
        Box(
            modifier = Modifier.fillMaxSize()
                .background(Color.Black.copy(alpha = 0.15f))
                .clickable(
                    indication = null,
                    interactionSource = remember { MutableInteractionSource() },
                ) { onDismiss() },
            contentAlignment = Alignment.Center,
        ) {
            // Animated blobs
            AnimatedBlobs()

            // Content
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.padding(32.dp),
            ) {
                // Emoji with spring pop + wiggle
                val emojiScale by animateFloatAsState(
                    if (visible) 1f else 0f,
                    spring(dampingRatio = 0.5f, stiffness = Spring.StiffnessMedium),
                    label = "emojiScale",
                )
                val wiggle by rememberInfiniteTransition(label = "wiggle").animateFloat(
                    -13f, 13f,
                    infiniteRepeatable(tween(800, easing = EaseInOut), RepeatMode.Reverse),
                    label = "wiggleAngle",
                )

                Text(
                    message.first,
                    fontSize = 44.sp,
                    modifier = Modifier.scale(emojiScale).rotate(wiggle),
                )

                Spacer(Modifier.height(20.dp))

                Text(
                    message.second,
                    style = MaterialTheme.typography.headlineMedium.copy(fontWeight = FontWeight.Black),
                    color = colors.text0,
                    textAlign = TextAlign.Center,
                )

                Spacer(Modifier.height(8.dp))

                Text(
                    message.third,
                    style = MaterialTheme.typography.bodyMedium,
                    color = colors.text1,
                    textAlign = TextAlign.Center,
                )
            }

            // Bottom button
            Button(
                onClick = { onDismiss(); onGoToToday() },
                modifier = Modifier.align(Alignment.BottomCenter)
                    .padding(bottom = 48.dp)
                    .fillMaxWidth(0.6f)
                    .height(48.dp),
                shape = RoundedCornerShape(24.dp),
                colors = ButtonDefaults.buttonColors(containerColor = colors.accent, contentColor = colors.bg0),
            ) {
                Text(SortydStrings.t(language, "Go to Today"), style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.Bold))
            }
        }
    }
}

@Composable
private fun AnimatedBlobs() {
    val colors = SortydColors.current
    val infinite = rememberInfiniteTransition(label = "blobs")

    val blob1X by infinite.animateFloat(-30f, 30f, infiniteRepeatable(tween(3500, easing = EaseInOut), RepeatMode.Reverse), label = "b1x")
    val blob1Y by infinite.animateFloat(-20f, 25f, infiniteRepeatable(tween(4200, easing = EaseInOut), RepeatMode.Reverse), label = "b1y")
    val blob2X by infinite.animateFloat(25f, -25f, infiniteRepeatable(tween(3800, easing = EaseInOut), RepeatMode.Reverse), label = "b2x")

    Box(modifier = Modifier.fillMaxSize()) {
        // Blob 1 — accent
        Box(
            modifier = Modifier.size(200.dp)
                .offset(blob1X.dp, blob1Y.dp)
                .align(Alignment.Center)
                .alpha(0.15f)
                .background(
                    Brush.radialGradient(listOf(colors.accent, Color.Transparent)),
                    RoundedCornerShape(50),
                ),
        )
        // Blob 2 — coral
        Box(
            modifier = Modifier.size(180.dp)
                .offset(blob2X.dp, (-blob1Y).dp)
                .align(Alignment.Center)
                .alpha(0.12f)
                .background(
                    Brush.radialGradient(listOf(colors.coral, Color.Transparent)),
                    RoundedCornerShape(50),
                ),
        )
    }
}

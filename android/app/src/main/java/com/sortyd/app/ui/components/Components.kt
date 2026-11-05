package com.sortyd.app.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.DirectionsRun
import androidx.compose.material.icons.filled.DirectionsWalk
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.Smartphone
import androidx.compose.material.icons.filled.Whatshot
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.scale
import kotlinx.coroutines.delay
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sortyd.app.data.model.DailyRecapData
import com.sortyd.app.data.model.HealthTaskType
import com.sortyd.app.data.model.SortydTask
import com.sortyd.app.ui.localization.SortydStrings
import com.sortyd.app.ui.theme.SortydColors

// ── Task Row (matches iOS screenshot: title, subtitle, health icon + progress, checkbox) ──
@Composable
fun TaskRow(
    task: SortydTask, healthProgress: Double = 0.0, onToggle: () -> Unit,
    onTap: (() -> Unit)? = null, modifier: Modifier = Modifier, language: String = "en",
    isTodoStyle: Boolean = false,
    trailingContent: (@Composable (() -> Unit))? = null,
) {
    val colors = SortydColors.current
    val haptic = LocalHapticFeedback.current
    val todoGreen = Color(0xFF4CAF50)
    val bgColor by animateColorAsState(
        if (isTodoStyle) todoGreen.copy(alpha = if (task.isCompleted) 0.08f else 0.06f)
        else if (task.isCompleted) colors.bg2.copy(0.35f) else colors.bg1,
        tween(200),
        label = "taskBg")
    val borderColor by animateColorAsState(
        if (isTodoStyle) todoGreen.copy(alpha = if (task.isCompleted) 0.28f else 0.22f)
        else if (task.isCompleted) colors.accent.copy(0.12f) else colors.bg3,
        tween(200),
        label = "taskBorder")

    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(bgColor)
            .border(0.5.dp, borderColor, RoundedCornerShape(16.dp))
            .clickable { onTap?.invoke() }
            .padding(horizontal = 14.dp, vertical = 14.dp),
    ) {
        // Title + subtitle
        Column(modifier = Modifier.weight(1f)) {
            Text(
                task.title,
                style = MaterialTheme.typography.bodyLarge.copy(
                    fontWeight = FontWeight.SemiBold,
                    textDecoration = if (task.isCompleted) TextDecoration.LineThrough else TextDecoration.None,
                ),
                color = if (task.isCompleted) colors.text2.copy(alpha = 0.68f) else colors.text0,
                maxLines = 2, overflow = TextOverflow.Ellipsis,
            )
            // Subtitle: "Anytime" or "Completed" or reminder time
            val subtitle = when {
                task.isCompleted -> SortydStrings.t(language, "Completed")
                task.reminderTime != null -> {
                    val cal = java.util.Calendar.getInstance().apply { timeInMillis = task.reminderTime }
                    "🔔 ${String.format("%02d:%02d", cal.get(java.util.Calendar.HOUR_OF_DAY), cal.get(java.util.Calendar.MINUTE))}"
                }
                else -> SortydStrings.t(language, "Anytime")
            }
            Text(
                subtitle, 
                style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp), 
                color = if (task.isCompleted) colors.text2.copy(alpha = 0.62f) else if (isTodoStyle) todoGreen.copy(alpha = 0.74f) else colors.text2,
                modifier = Modifier.padding(top = 2.dp)
            )
        }

        // Health progress visual (matches iOS "Health Tank")
        if (task.isHealthTask && task.healthTarget != null) {
            val progress = healthProgress.toFloat()
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(horizontal = 4.dp)) {
                Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(horizontal = 8.dp)) {
                    val current = (healthProgress * task.healthTarget).toInt()
                    val target = task.healthTarget.toInt()
                    val progressColor = when {
                        task.healthType == HealthTaskType.SCREEN_TIME.rawValue && healthProgress < 1.0 -> colors.danger
                        task.healthType == HealthTaskType.STEPS.rawValue -> colors.healthSteps
                        task.healthType == HealthTaskType.CALORIES.rawValue -> colors.healthCalories
                        task.healthType == HealthTaskType.DISTANCE.rawValue -> colors.healthDistance
                        task.healthType == HealthTaskType.SCREEN_TIME.rawValue -> colors.healthScreenTime
                        else -> colors.accent
                    }
                    Text(
                        if (task.healthType == HealthTaskType.DISTANCE.rawValue)
                            String.format("%.1f", healthProgress * task.healthTarget)
                        else "$current",
                        style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold, fontSize = 11.sp),
                        color = progressColor,
                    )
                    Text("${target.takeIf { it > 0 } ?: ""}", style = MaterialTheme.typography.labelSmall.copy(fontSize = 7.sp), color = colors.text2.copy(0.6f))
                }
                
                SmallHealthBar(task.healthType ?: "", progress)
                
                Spacer(Modifier.width(12.dp))
                
                // Icon Box
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier
                        .size(32.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(colors.bg2)
                ) {
                    val icon = when (task.healthType) {
                        HealthTaskType.STEPS.rawValue -> Icons.Default.DirectionsWalk
                        HealthTaskType.CALORIES.rawValue -> Icons.Default.Whatshot
                        HealthTaskType.DISTANCE.rawValue -> Icons.Default.DirectionsRun
                        HealthTaskType.SCREEN_TIME.rawValue -> Icons.Default.Smartphone // Using Smartphone for screen time
                        else -> Icons.Default.Check
                    }
                    Icon(icon, null, tint = colors.text2.copy(0.5f), modifier = Modifier.size(16.dp))
                }
            }
            Spacer(Modifier.width(12.dp))
        }

        trailingContent?.invoke()

        // Checkbox (matches iOS circle checkbox)
        TaskCheckbox(
            checked = if (task.healthType == HealthTaskType.SCREEN_TIME.rawValue) (healthProgress >= 1.0) else task.isCompleted,
            healthType = task.healthType,
            enabled = task.healthType != HealthTaskType.SCREEN_TIME.rawValue
        ) {
            haptic.performHapticFeedback(HapticFeedbackType.LongPress)
            onToggle()
        }
    }
}

@Composable
private fun TaskCheckbox(checked: Boolean, healthType: String?, enabled: Boolean = true, onToggle: () -> Unit) {
    val colors = SortydColors.current
    val checkColor = when {
        healthType == HealthTaskType.SCREEN_TIME.rawValue && !checked -> colors.danger
        healthType == HealthTaskType.STEPS.rawValue -> colors.healthSteps
        healthType == HealthTaskType.CALORIES.rawValue -> colors.healthCalories
        healthType == HealthTaskType.DISTANCE.rawValue -> colors.healthDistance
        healthType == HealthTaskType.SCREEN_TIME.rawValue -> colors.healthScreenTime
        else -> colors.accent
    }
    val scale by animateFloatAsState(
        if (checked) 1f else 0f, spring(stiffness = Spring.StiffnessMediumLow, dampingRatio = 0.65f), label = "chk")

    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier
            .size(44.dp)
            .clip(CircleShape)
            .then(if (enabled) Modifier.clickable { onToggle() } else Modifier)
    ) {
        Canvas(Modifier.size(30.dp)) {
            if (checked) drawCircle(color = checkColor, radius = size.minDimension / 2 * scale)
            else drawCircle(color = checkColor.copy(0.3f), radius = size.minDimension / 2, style = Stroke(2.dp.toPx()))
        }
        if (checked) Icon(Icons.Filled.Check, "Done", tint = Color.Black, modifier = Modifier.size(16.dp).alpha(scale))
    }
}

// ── Section Label ──
@Composable
fun SectionLabel(
    title: String,
    badge: String? = null,
    actionLabel: String? = null,
    onAction: (() -> Unit)? = null,
    modifier: Modifier = Modifier,
    actionContent: @Composable (RowScope.() -> Unit)? = null
) {
    val colors = SortydColors.current
    Row(verticalAlignment = Alignment.CenterVertically, modifier = modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)) {
        Text(title.uppercase(), style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold, letterSpacing = 1.5.sp), color = colors.text2)
        Spacer(Modifier.weight(1f))
        if (badge != null) {
            Text(badge, style = MaterialTheme.typography.labelSmall, color = colors.text2)
            if (actionContent != null || (actionLabel != null && onAction != null)) {
                Spacer(Modifier.width(8.dp))
            }
        }
        if (actionContent != null) {
            actionContent()
        } else if (actionLabel != null && onAction != null) {
            TextButton(onClick = onAction) {
                Text(actionLabel, style = MaterialTheme.typography.labelMedium, color = colors.accent)
            }
        }
    }
}

// ── Empty State ──
@Composable
fun EmptyState(icon: String = "📋", title: String, subtitle: String, modifier: Modifier = Modifier) {
    val colors = SortydColors.current
    val infinite = rememberInfiniteTransition(label = "emptyPulse")
    val pulseAlpha by infinite.animateFloat(0.3f, 0.8f, infiniteRepeatable(tween(2600, easing = EaseInOut), RepeatMode.Reverse), label = "pulse")

    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center,
        modifier = modifier.fillMaxWidth().padding(48.dp)) {
        // Concentric rings (matching iOS screenshot)
        Box(contentAlignment = Alignment.Center) {
            Canvas(Modifier.size(120.dp)) {
                // Outer ring
                drawCircle(color = colors.accent.copy(alpha = pulseAlpha * 0.06f), radius = size.minDimension / 2, style = Stroke(1.dp.toPx()))
                // Middle ring
                drawCircle(color = colors.accent.copy(alpha = pulseAlpha * 0.1f), radius = size.minDimension / 2 * 0.75f, style = Stroke(1.dp.toPx()))
                // Inner ring
                drawCircle(color = colors.accent.copy(alpha = pulseAlpha * 0.15f), radius = size.minDimension / 2 * 0.5f, style = Stroke(1.5.dp.toPx()))
                // Orbital dots
                val dotRadius = 2.dp.toPx()
                val r = size.minDimension / 2 * 0.75f
                for (angle in listOf(0f, 90f, 180f, 270f, 45f, 225f)) {
                    val rad = Math.toRadians(angle.toDouble())
                    drawCircle(colors.accent.copy(alpha = 0.3f), dotRadius,
                        center = Offset(center.x + r * kotlin.math.cos(rad).toFloat(), center.y + r * kotlin.math.sin(rad).toFloat()))
                }
            }
            // Center icon
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier.size(48.dp).clip(RoundedCornerShape(12.dp)).background(colors.accent.copy(0.1f))
                    .border(0.5.dp, colors.accent.copy(0.3f), RoundedCornerShape(12.dp)),
            ) { Text(icon, fontSize = 24.sp) }
        }
        Spacer(Modifier.height(24.dp))
        Text(title, style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold), color = colors.text0)
        Spacer(Modifier.height(6.dp))
        Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = colors.text2, textAlign = androidx.compose.ui.text.style.TextAlign.Center)
    }
}

// ── Theme Toggle ──
@Composable
fun ThemeToggle(isDark: Boolean, onToggle: () -> Unit, modifier: Modifier = Modifier) {
    IconButton(onClick = onToggle, modifier = modifier.size(44.dp)) {
        Text(if (isDark) "☀️" else "🌙", fontSize = 16.sp)
    }
}

// ── Donut Chart ──
@Composable
fun DonutChart(fraction: Float, modifier: Modifier = Modifier, size: Int = 200, lineWidth: Float = 14f) {
    val colors = SortydColors.current
    val animFrac by animateFloatAsState(fraction, tween(600, 150, EaseOut), label = "donut")
    Canvas(modifier.size(size.dp)) {
        val stroke = Stroke(lineWidth, cap = StrokeCap.Round)
        val arcSize = Size(this.size.width - lineWidth, this.size.height - lineWidth)
        val topLeft = Offset(lineWidth / 2, lineWidth / 2)
        drawArc(color = colors.bg2, 0f, 360f, false, topLeft = topLeft, size = arcSize, style = stroke)
        drawArc(brush = Brush.sweepGradient(listOf(colors.coral, colors.accent, colors.coral)),
            -90f, 360f * animFrac, false, topLeft = topLeft, size = arcSize, style = stroke)
    }
}

// ── Small Health Bar ──
@Composable
fun SmallHealthBar(taskType: String, progress: Float, modifier: Modifier = Modifier) {
    val colors = SortydColors.current
    val barColor = when {
        taskType == HealthTaskType.SCREEN_TIME.rawValue && progress < 1.0f -> colors.danger
        taskType == HealthTaskType.STEPS.rawValue -> colors.healthSteps
        taskType == HealthTaskType.CALORIES.rawValue -> colors.healthCalories
        taskType == HealthTaskType.DISTANCE.rawValue -> colors.healthDistance
        taskType == HealthTaskType.SCREEN_TIME.rawValue -> colors.healthScreenTime
        else -> colors.accent
    }
    val animProg by animateFloatAsState(progress.coerceIn(0f, 1f), tween(600), label = "hBar")
    Canvas(modifier.width(6.dp).height(32.dp)) {
        val cr = 3.dp.toPx()
        drawRoundRect(barColor.copy(0.15f), size = size, cornerRadius = CornerRadius(cr))
        val fh = size.height * animProg
        drawRoundRect(barColor, topLeft = Offset(0f, size.height - fh), size = Size(size.width, fh), cornerRadius = CornerRadius(cr))
    }
}
fun Modifier.dualGlow(violetIntensity: Float = 0.15f, cyanIntensity: Float = 0.1f) = this.then(
    Modifier.drawBehind {
        drawCircle(
            brush = Brush.radialGradient(
                colors = listOf(Color(0xFF8B5CF6).copy(alpha = violetIntensity), Color.Transparent),
                center = Offset(size.width, 0f),
                radius = size.width * 0.8f
            )
        )
        drawCircle(
            brush = Brush.radialGradient(
                colors = listOf(Color(0xFF06B6D4).copy(alpha = cyanIntensity), Color.Transparent),
                center = Offset(0f, size.height),
                radius = size.width * 0.8f
            )
        )
    }
)

@Composable
fun FingerTapOverlay(modifier: Modifier = Modifier, onPressState: (Boolean) -> Unit) {
    val handColor = Color(0xFF8D6E63)
    var tap by remember { mutableStateOf(false) }
    var pulse by remember { mutableStateOf(false) }
    
    val fingerOffset by animateFloatAsState(
        targetValue = if (tap) 10f else 0f,
        animationSpec = spring(dampingRatio = 0.5f), label = "fingerTap"
    )
    val fingerScale by animateFloatAsState(
        targetValue = if (tap) 0.85f else 1.1f,
        animationSpec = spring(dampingRatio = 0.5f), label = "fingerScale"
    )
    val pulseScale by animateFloatAsState(
        targetValue = if (pulse) 1.6f else 0.8f,
        animationSpec = tween(500), label = "pulseScale"
    )
    val pulseAlpha by animateFloatAsState(
        targetValue = if (pulse) 0f else 0.7f,
        animationSpec = tween(500), label = "pulseAlpha"
    )

    LaunchedEffect(Unit) {
        delay(1000)
        while(true) {
            tap = true
            onPressState(true)
            pulse = true
            delay(350)
            tap = false
            onPressState(false)
            delay(500)
            pulse = false
            delay(1500)
        }
    }

    Box(
        modifier = modifier.offset(x = 110.dp, y = (-20).dp),
        contentAlignment = Alignment.Center
    ) {
        Canvas(Modifier.size(40.dp)) {
            drawCircle(
                color = handColor.copy(alpha = pulseAlpha),
                radius = (size.minDimension / 2) * pulseScale,
                style = Stroke(2.dp.toPx())
            )
        }
        Text("👆🏽", fontSize = 40.sp, modifier = Modifier.scale(fingerScale).offset(y = fingerOffset.dp))
    }
}

// ── Daily Recap Banner (Slides from top) ──
@Composable
fun DailyRecapBanner(
    data: DailyRecapData,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier
) {
    val colors = SortydColors.current
    var isVisible by remember { mutableStateOf(false) }
    
    LaunchedEffect(Unit) {
        delay(500) // Small delay for "wow" effect after app load
        isVisible = true
        
        delay(5000) // 5-second auto dismiss
        isVisible = false
    }

    androidx.compose.animation.AnimatedVisibility(
        visible = isVisible,
        enter = androidx.compose.animation.fadeIn() + androidx.compose.animation.slideInVertically(initialOffsetY = { -it }),
        exit = androidx.compose.animation.fadeOut() + androidx.compose.animation.slideOutVertically(targetOffsetY = { -it }),
        modifier = modifier.fillMaxWidth().padding(top = 40.dp)
    ) {
        Box(
            modifier = Modifier
                .padding(horizontal = 16.dp, vertical = 8.dp)
                .fillMaxWidth()
                .shadow(
                    elevation = 20.dp,
                    shape = RoundedCornerShape(24.dp),
                    spotColor = Color.Black.copy(alpha = 0.5f),
                    ambientColor = colors.accent.copy(alpha = 0.2f)
                )
                .clip(RoundedCornerShape(24.dp))
                .background(colors.bg1.copy(alpha = 0.85f))
                .background(
                    Brush.linearGradient(
                        colors = listOf(
                            colors.accent.copy(alpha = 0.15f),
                            Color.Transparent,
                            Color(0xFF7C6FFF).copy(alpha = 0.1f)
                        )
                    )
                )
                .border(
                    width = 1.dp,
                    brush = Brush.linearGradient(
                        colors = listOf(Color.White.copy(alpha = 0.3f), Color.White.copy(alpha = 0.05f))
                    ),
                    shape = RoundedCornerShape(24.dp)
                )
                .dualGlow(violetIntensity = 0.15f, cyanIntensity = 0.1f)
                .padding(16.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier
                        .size(54.dp)
                        .clip(CircleShape)
                        .background(
                            Brush.linearGradient(
                                colors = listOf(colors.accent, Color(0xFF7C6FFF))
                            )
                        )
                        .border(1.dp, Color.White.copy(alpha = 0.4f), CircleShape)
                ) {
                    Box(
                        contentAlignment = Alignment.Center,
                        modifier = Modifier
                            .size(48.dp)
                            .clip(CircleShape)
                            .background(colors.bg0.copy(alpha = 0.8f))
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(data.emoji, fontSize = 16.sp)
                            Text("${data.percentage}%", style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Black), color = colors.accent)
                        }
                    }
                }
                
                Spacer(Modifier.width(16.dp))
                
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        data.dateLabel.uppercase(),
                        style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold, letterSpacing = 1.5.sp),
                        color = colors.text2.copy(0.9f)
                    )
                    Spacer(Modifier.height(2.dp))
                    Text(
                        data.message,
                        style = MaterialTheme.typography.bodyMedium.copy(lineHeight = 18.sp, fontWeight = FontWeight.Medium),
                        color = colors.text0
                    )
                }
                
                IconButton(onClick = { 
                    isVisible = false
                }) {
                    Icon(androidx.compose.material.icons.Icons.Default.KeyboardArrowDown, null, tint = colors.text2.copy(0.6f), modifier = Modifier.scale(1.2f, -1.2f))
                }
            }
        }
    }
    
    LaunchedEffect(isVisible) {
        if (!isVisible) {
            delay(500)
            onDismiss()
        }
    }
}

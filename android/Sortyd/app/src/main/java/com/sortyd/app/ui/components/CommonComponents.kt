package com.sortyd.app.ui.components

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.*
import androidx.compose.ui.geometry.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.*
import com.sortyd.app.ui.theme.*
import com.sortyd.app.model.*
import kotlin.math.*

// ─── Circular Progress Ring ───────────────────────────────────────────────────

@Composable
fun CircularProgressRing(
    progress: Float,
    size: Dp = 56.dp,
    strokeWidth: Dp = 5.dp,
    trackColor: Color = sortydColors.bg3,
    progressColor: Color = sortydColors.teal,
    modifier: Modifier = Modifier
) {
    val animProgress by animateFloatAsState(
        targetValue = progress,
        animationSpec = tween(700, easing = FastOutSlowInEasing),
        label = "ring_progress"
    )

    Canvas(modifier = modifier.size(size)) {
        val stroke = strokeWidth.toPx()
        val radius = (size.toPx() - stroke) / 2f
        val topLeft = Offset(stroke / 2f, stroke / 2f)
        val arcSize = Size(radius * 2, radius * 2)

        // Track
        drawArc(
            color = trackColor,
            startAngle = -90f,
            sweepAngle = 360f,
            useCenter = false,
            topLeft = topLeft,
            size = arcSize,
            style = Stroke(stroke, cap = StrokeCap.Round)
        )

        // Progress
        val brush = Brush.sweepGradient(
            0f to progressColor,
            0.5f to progressColor.copy(alpha = 0.7f),
            1f to progressColor
        )
        drawArc(
            brush = brush,
            startAngle = -90f,
            sweepAngle = 360f * animProgress,
            useCenter = false,
            topLeft = topLeft,
            size = arcSize,
            style = Stroke(stroke, cap = StrokeCap.Round)
        )
    }
}

// ─── Glass Card ───────────────────────────────────────────────────────────────

@Composable
fun GlassCard(
    modifier: Modifier = Modifier,
    cornerRadius: Dp = 24.dp,
    alpha: Float = 0.03f,
    padding: Dp = 24.dp,
    content: @Composable ColumnScope.() -> Unit
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(cornerRadius))
            .background(Color.White.copy(alpha = alpha))
            .border(
                1.dp,
                Color.White.copy(alpha = 0.05f),
                RoundedCornerShape(cornerRadius)
            )
    ) {
        Column(
            modifier = Modifier.padding(padding),
            content = content
        )
    }
}

// ─── Gradient Button ──────────────────────────────────────────────────────────

@Composable
fun GradientButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    content: @Composable RowScope.() -> Unit
) {
    Button(
        onClick = onClick,
        modifier = modifier,
        enabled = enabled,
        colors = ButtonDefaults.buttonColors(containerColor = Color.Transparent),
        contentPadding = PaddingValues(0.dp)
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    brush = if (enabled) Brush.horizontalGradient(
                        listOf(sortydColors.teal, sortydColors.violet)
                    ) else Brush.horizontalGradient(
                        listOf(sortydColors.bg3, sortydColors.bg3)
                    ),
                    shape = CircleShape
                )
                .padding(vertical = 14.dp, horizontal = 24.dp),
            contentAlignment = Alignment.Center
        ) {
            Row(
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
                content = content
            )
        }
    }
}

// ─── Task Checkbox Row ────────────────────────────────────────────────────────

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun TaskCheckboxRow(
    task: SortydTask,
    healthProgress: Double = 0.0,
    onToggle: () -> Unit,
    onLongPress: () -> Unit = {},
    modifier: Modifier = Modifier,
    hasStreak: Boolean = false
) {
    val c = sortydColors
    val isCompleted = task.isCompleted

    Row(
        modifier = modifier
            .fillMaxWidth()
            .combinedClickable(onClick = onToggle, onLongClick = onLongPress)
            .padding(vertical = 12.dp, horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    text = task.title,
                    style = MaterialTheme.typography.bodyLarge.copy(
                        fontWeight = if (isCompleted) FontWeight.Normal else FontWeight.SemiBold,
                        color = if (isCompleted) Color.White.copy(alpha = 0.25f) else Color.White,
                        textDecoration = if (isCompleted) androidx.compose.ui.text.style.TextDecoration.LineThrough
                        else androidx.compose.ui.text.style.TextDecoration.None,
                        letterSpacing = 0.2.sp
                    ),
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f, fill = false)
                )
                
                if (hasStreak) {
                    Icon(
                        Icons.Default.Whatshot,
                        contentDescription = null,
                        tint = Color(0xFFFF5722),
                        modifier = Modifier.size(14.dp)
                    )
                }
            }

            // Health task progress or subtitle
            if (task.isHealthTask && !isCompleted && healthProgress > 0.0) {
                Spacer(Modifier.height(4.dp))
                val type = task.resolvedHealthType
                val healthColor = when (type) {
                    HealthTaskType.STEPS -> StepsColor
                    HealthTaskType.CALORIES -> CaloriesColor
                    HealthTaskType.DISTANCE -> DistanceColor
                    else -> c.teal
                }
                val current = ((task.healthTarget ?: 0.0) * healthProgress).toInt()
                val target = (task.healthTarget ?: 0.0).toInt()
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    LinearProgressIndicator(
                        progress = { healthProgress.toFloat().coerceIn(0f, 1f) },
                        modifier = Modifier.weight(1f).height(4.dp).clip(RoundedCornerShape(2.dp)),
                        color = healthColor,
                        trackColor = Color.White.copy(alpha = 0.05f)
                    )
                    Text(
                        "$current / $target ${type.unit}",
                        style = MaterialTheme.typography.labelSmall.copy(
                            fontWeight = FontWeight.Bold,
                            letterSpacing = 0.5.sp
                        ),
                        color = healthColor
                    )
                }
            } else {
                Text(
                    if (isCompleted) "COMPLETED" else "ANYTIME",
                    style = MaterialTheme.typography.labelSmall.copy(
                        color = if (isCompleted) c.teal.copy(alpha = 0.4f) else Color.White.copy(alpha = 0.2f),
                        fontWeight = FontWeight.Black,
                        letterSpacing = 1.sp
                    )
                )
            }
        }

        // Checkbox on the RIGHT
        Box(
            modifier = Modifier
                .size(28.dp)
                .background(
                    if (isCompleted) c.teal else Color.White.copy(alpha = 0.03f),
                    CircleShape
                )
                .border(
                    1.5.dp,
                    if (isCompleted) c.teal else Color.White.copy(alpha = 0.12f),
                    CircleShape
                ),
            contentAlignment = Alignment.Center
        ) {
            if (isCompleted) {
                Icon(
                    Icons.Default.Check,
                    contentDescription = null,
                    tint = Color.Black,
                    modifier = Modifier.size(16.dp)
                )
            }
        }
    }
}

// ─── List Pill (header) ───────────────────────────────────────────────────────

@Composable
fun ListPill(
    list: TaskList,
    isActive: Boolean,
    healthValues: Map<String, Double> = emptyMap(),
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val c = sortydColors
    val fraction = list.completionFraction(healthValues).toFloat()

    Column(
        modifier = modifier
            .clickable(onClick = onClick)
            .padding(horizontal = 4.dp, vertical = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Box(contentAlignment = Alignment.Center) {
            CircularProgressRing(
                progress = fraction,
                size = 48.dp,
                strokeWidth = 4.dp,
                trackColor = if (isActive) c.accent.copy(alpha = 0.2f) else c.bg3,
                progressColor = if (isActive) c.accent else c.text2
            )
            Text(
                list.emoji,
                style = MaterialTheme.typography.bodyMedium
            )
        }
        Text(
            list.cleanName,
            style = MaterialTheme.typography.labelSmall.copy(
                color = if (isActive) c.accent else c.text2,
                fontWeight = if (isActive) FontWeight.Bold else FontWeight.Normal
            ),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.widthIn(max = 60.dp)
        )
    }
}

// ─── Heatmap Cell ─────────────────────────────────────────────────────────────

@Composable
fun HeatmapCell(fraction: Double, size: Dp = 18.dp) {
    val c = sortydColors
    val color = when {
        fraction >= 0.9 -> c.accent
        fraction >= 0.7 -> c.accent.copy(alpha = 0.7f)
        fraction >= 0.5 -> c.accent.copy(alpha = 0.45f)
        fraction >= 0.2 -> c.accent.copy(alpha = 0.2f)
        fraction > 0 -> c.accent.copy(alpha = 0.1f)
        else -> c.bg3.copy(alpha = 0.4f)
    }
    Box(
        modifier = Modifier
            .size(size)
            .background(color = color, shape = RoundedCornerShape(3.dp))
    )
}

// ─── Toast Banner ─────────────────────────────────────────────────────────────

@Composable
fun ConflictToast(message: String, visible: Boolean, color: Color = sortydColors.warning) {
    AnimatedVisibility(
        visible = visible,
        enter = slideInVertically(initialOffsetY = { -it }) + fadeIn(),
        exit = slideOutVertically(targetOffsetY = { -it }) + fadeOut()
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(color.copy(alpha = 0.15f), RoundedCornerShape(12.dp))
                .border(1.dp, color.copy(alpha = 0.4f), RoundedCornerShape(12.dp))
                .padding(12.dp)
        ) {
            Text(message, style = MaterialTheme.typography.bodySmall, color = color)
        }
    }
}

// ─── Grade Badge ──────────────────────────────────────────────────────────────

@Composable
fun GradeBadge(grade: String, avg: Double, modifier: Modifier = Modifier) {
    val c = sortydColors
    val gradeColor = when {
        grade.startsWith("A") -> c.success
        grade.startsWith("B") -> c.teal
        grade.startsWith("C") -> c.warning
        else -> c.danger
    }
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(32.dp))
            .background(Color.White.copy(alpha = 0.05f))
            .border(1.dp, Color.White.copy(alpha = 0.08f), RoundedCornerShape(32.dp))
            .padding(horizontal = 24.dp, vertical = 24.dp),
        contentAlignment = Alignment.Center
    ) {
        // Background glow
        Box(
            modifier = Modifier
                .size(80.dp)
                .blur(30.dp)
                .background(gradeColor.copy(alpha = 0.15f), CircleShape)
        )

        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                grade,
                style = MaterialTheme.typography.displayLarge.copy(
                    color = gradeColor,
                    fontWeight = FontWeight.Black,
                    fontSize = 100.sp,
                    letterSpacing = (-6).sp
                )
            )
            Text(
                "GRADE",
                style = MaterialTheme.typography.labelSmall.copy(
                    color = Color.White.copy(alpha = 0.4f),
                    fontWeight = FontWeight.Black,
                    letterSpacing = 2.sp
                )
            )
        }
    }
}

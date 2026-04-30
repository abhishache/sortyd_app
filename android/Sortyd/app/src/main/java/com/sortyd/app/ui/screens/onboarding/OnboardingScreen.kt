package com.sortyd.app.ui.screens.onboarding

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.*
import androidx.compose.foundation.shape.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.ui.draw.blur
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.*
import androidx.hilt.navigation.compose.hiltViewModel
import com.sortyd.app.model.AppLanguage
import com.sortyd.app.ui.components.GradientButton
import com.sortyd.app.ui.theme.*
import com.sortyd.app.viewmodel.AppViewModel
import kotlinx.coroutines.launch

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun OnboardingScreen(
    onDismiss: () -> Unit,
    vm: AppViewModel = hiltViewModel()
) {
    val c = sortydColors
    val pagerState = rememberPagerState(pageCount = { 4 })
    val scope = rememberCoroutineScope()
    val lang by vm.appLanguage.collectAsStateWithLifecycle()

    // Floating glow animation
    val glowPulse by rememberInfiniteTransition(label = "glow").animateFloat(
        initialValue = 0.1f, targetValue = 0.4f,
        animationSpec = infiniteRepeatable(tween(2400, easing = FastOutSlowInEasing), RepeatMode.Reverse),
        label = "glow_val"
    )

    val pages = obPages(lang)

    Box(modifier = Modifier.fillMaxSize().background(if (c.isDark) Color(0xFF07080F) else Color(0xFFF5F4FF))) {
        // Background blobs
        ObAtmosphere(teal = c.teal, violet = c.violet)

        Column(
            modifier = Modifier.fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Logo header
            Spacer(Modifier.height(48.dp))
            ObLogoHeader(c = c, glowPulse = glowPulse)
            Spacer(Modifier.height(16.dp))

            // Page cards
            HorizontalPager(
                state = pagerState,
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                contentPadding = PaddingValues(horizontal = 24.dp),
                pageSpacing = 16.dp
            ) { page ->
                when (page) {
                    0 -> LanguageCard(vm = vm, lang = lang)
                    1 -> HabitCard(lang = lang)
                    2 -> AIInsightsCard(lang = lang)
                    3 -> HealthKitCard(lang = lang)
                }
            }

            // Bottom section
            Column(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                // Page dots
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    repeat(4) { idx ->
                        Box(
                            modifier = Modifier
                                .height(5.dp)
                                .width(if (idx == pagerState.currentPage) 22.dp else 5.dp)
                                .background(
                                    brush = if (idx == pagerState.currentPage)
                                        Brush.horizontalGradient(listOf(c.teal, c.violet))
                                    else Brush.horizontalGradient(listOf(c.bg3, c.bg3)),
                                    shape = CircleShape
                                )
                                .animateContentSize()
                        )
                    }
                }

                Spacer(Modifier.height(16.dp))

                // Headline + sub
                val page = pages.getOrNull(pagerState.currentPage)
                AnimatedContent(
                    targetState = pagerState.currentPage,
                    transitionSpec = {
                        slideInHorizontally { it } + fadeIn() togetherWith
                                slideOutHorizontally { -it } + fadeOut()
                    },
                    label = "headline_anim"
                ) { idx ->
                    val p = pages.getOrNull(idx)
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        p?.headline?.let { hl ->
                            Text(
                                hl,
                                style = MaterialTheme.typography.headlineLarge.copy(
                                    color = if (c.isDark) Color.White else Color(0xFF0C0D20),
                                    fontWeight = FontWeight.Black,
                                    textAlign = TextAlign.Center
                                ),
                                textAlign = TextAlign.Center
                            )
                        }
                        Spacer(Modifier.height(6.dp))
                        p?.sub?.let { sub ->
                            Text(
                                sub,
                                style = MaterialTheme.typography.bodyMedium.copy(
                                    color = if (c.isDark) Color.White.copy(alpha = 0.5f) else Color(0xFF0C0D20).copy(alpha = 0.5f),
                                    textAlign = TextAlign.Center
                                ),
                                textAlign = TextAlign.Center,
                                maxLines = 2
                            )
                        }
                    }
                }

                Spacer(Modifier.height(16.dp))

                // HealthKit disclosure badge
                HealthKitBadge()
                Spacer(Modifier.height(8.dp))

                // AI disclaimer
                Text(
                    "AI analytics use goal titles only — processed securely",
                    style = MaterialTheme.typography.labelSmall.copy(
                        color = if (c.isDark) Color.White.copy(alpha = 0.25f) else Color(0xFF0C0D20).copy(alpha = 0.3f)
                    ),
                    textAlign = TextAlign.Center
                )

                Spacer(Modifier.height(16.dp))

                // CTA button
                GradientButton(
                    onClick = {
                        if (pagerState.currentPage < 3) {
                            scope.launch { pagerState.animateScrollToPage(pagerState.currentPage + 1) }
                        } else {
                            onDismiss()
                        }
                    },
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(
                        if (pagerState.currentPage == 3) "Get Started" else "Continue",
                        color = Color.White, fontWeight = FontWeight.Bold
                    )
                    Spacer(Modifier.width(8.dp))
                    Icon(Icons.AutoMirrored.Filled.ArrowForward, null, tint = Color.White, modifier = Modifier.size(16.dp))
                }
                Spacer(Modifier.height(40.dp))
            }
        }
    }
}

// ─── Onboarding Cards ─────────────────────────────────────────────────────────

@Composable
private fun LanguageCard(vm: AppViewModel, lang: AppLanguage) {
    val c = sortydColors
    ObCard {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            AppLanguage.entries.forEach { language ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(
                            if (lang == language) c.teal.copy(alpha = 0.1f) else c.bg2.copy(alpha = 0.5f),
                            RoundedCornerShape(12.dp)
                        )
                        .border(
                            1.5.dp,
                            if (lang == language) c.teal else Color.Transparent,
                            RoundedCornerShape(12.dp)
                        )
                        .clickable { vm.setLanguage(language) }
                        .padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        language.displayName,
                        style = MaterialTheme.typography.bodyMedium.copy(
                            color = if (lang == language) c.teal else c.text0,
                            fontWeight = if (lang == language) FontWeight.Bold else FontWeight.Normal
                        ),
                        modifier = Modifier.weight(1f)
                    )
                    if (lang == language) {
                        Icon(Icons.Default.Check, null, tint = c.teal, modifier = Modifier.size(18.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun HabitCard(lang: AppLanguage) {
    val c = sortydColors
    ObCard {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            // Sample list with mock tasks
            val tasks = listOf(
                "Morning meditation" to true,
                "Workout 30 min" to true,
                "Read 20 pages" to true,
                "Journal entry" to false,
                "Cold shower" to false
            )
            // Header
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Icon(Icons.Default.GridView, null, tint = c.teal, modifier = Modifier.size(10.dp))
                Text("YOUR HABITS", style = MaterialTheme.typography.labelSmall.copy(color = c.teal, letterSpacing = 2.sp))
            }
            tasks.forEach { (title, done) ->
                Row(
                    modifier = Modifier.fillMaxWidth().padding(vertical = 3.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(16.dp)
                            .background(if (done) c.teal else Color.Transparent, CircleShape)
                            .border(1.5.dp, if (done) c.teal else c.glassBorder, CircleShape),
                        contentAlignment = Alignment.Center
                    ) {
                        if (done) Icon(Icons.Default.Check, null, tint = c.bg0, modifier = Modifier.size(8.dp))
                    }
                    Text(
                        title,
                        style = MaterialTheme.typography.bodySmall.copy(
                            color = if (done) c.text2 else c.text0,
                            textDecoration = if (done) androidx.compose.ui.text.style.TextDecoration.LineThrough
                            else androidx.compose.ui.text.style.TextDecoration.None
                        )
                    )
                }
            }
        }
    }
}

@Composable
private fun AIInsightsCard(lang: AppLanguage) {
    val c = sortydColors
    ObCard {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Icon(Icons.Default.AutoAwesome, null, tint = c.violet, modifier = Modifier.size(10.dp))
                Text("AI COACH INSIGHTS", style = MaterialTheme.typography.labelSmall.copy(color = c.violet, letterSpacing = 2.sp))
            }
            InsightRow("Mornings beat evenings by 2×", "☀️", Color(0xFFFFD60A))
            InsightRow("You skip Fridays 80% of the time", "🔥", Color(0xFFFF6B35))
            InsightRow("Workout streak: personal best!", "🏆", c.teal)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                StatBadge("B+", "Grade", c.teal)
                StatBadge("78%", "Weekly", c.violet)
                StatBadge("12d", "Streak", Color(0xFFFF6B35))
            }
        }
    }
}

@Composable
private fun InsightRow(text: String, emoji: String, color: Color) {
    val c = sortydColors
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(color.copy(alpha = 0.07f), RoundedCornerShape(8.dp))
            .padding(8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Text(emoji, style = MaterialTheme.typography.bodySmall)
        Text(text, style = MaterialTheme.typography.bodySmall.copy(color = c.text1))
    }
}

@Composable
private fun StatBadge(value: String, label: String, color: Color) {
    val c = sortydColors
    Column(
        modifier = Modifier
            .background(color.copy(alpha = 0.1f), RoundedCornerShape(10.dp))
            .padding(horizontal = 12.dp, vertical = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(value, style = MaterialTheme.typography.headlineSmall.copy(color = color, fontWeight = FontWeight.Black))
        Text(label, style = MaterialTheme.typography.labelSmall.copy(color = c.text2))
    }
}

@Composable
private fun HealthKitCard(lang: AppLanguage) {
    val c = sortydColors
    ObCard {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Center
            ) {
                Icon(Icons.Default.Favorite, null, tint = Color(0xFFFF375F), modifier = Modifier.size(40.dp))
            }
            Text(
                "Health Connect",
                style = MaterialTheme.typography.headlineSmall.copy(color = c.text0, fontWeight = FontWeight.Bold),
                textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth()
            )
            // Health metrics demo
            listOf(
                Triple("👟", "Steps", "8,240 / 10,000"),
                Triple("🔥", "Calories", "420 / 500 kcal"),
                Triple("🏃", "Distance", "3.2 / 5.0 km")
            ).forEach { (icon, label, value) ->
                Row(
                    modifier = Modifier.fillMaxWidth()
                        .background(c.bg2.copy(alpha = 0.5f), RoundedCornerShape(10.dp))
                        .padding(10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Text(icon)
                    Text(label, style = MaterialTheme.typography.bodySmall.copy(color = c.text1), modifier = Modifier.weight(1f))
                    Text(value, style = MaterialTheme.typography.bodySmall.copy(color = c.accent, fontWeight = FontWeight.SemiBold))
                }
            }
        }
    }
}

// ─── Helper Composables ───────────────────────────────────────────────────────

@Composable
private fun ObCard(content: @Composable ColumnScope.() -> Unit) {
    val c = sortydColors
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                if (c.isDark) Color(0xFF10111C) else Color.White,
                RoundedCornerShape(24.dp)
            )
            .border(
                1.5.dp,
                Brush.linearGradient(listOf(c.teal.copy(alpha = 0.3f), c.violet.copy(alpha = 0.15f))),
                RoundedCornerShape(24.dp)
            )
            .padding(20.dp),
        content = content
    )
}

@Composable
private fun ObLogoHeader(c: SortydColors, glowPulse: Float) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Box(
            modifier = Modifier
                .size(54.dp)
                .background(
                    if (c.isDark) Color(0xFF0E1019) else Color.White,
                    RoundedCornerShape(16.dp)
                )
                .border(
                    1.5.dp,
                    Brush.linearGradient(listOf(c.teal.copy(alpha = 0.5f), c.violet.copy(alpha = 0.3f))),
                    RoundedCornerShape(16.dp)
                ),
            contentAlignment = Alignment.Center
        ) {
            Column(
                modifier = Modifier.padding(10.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                LogoBar(fill = 1.0f, colors = listOf(c.teal, c.violet))
                LogoBar(fill = 0.7f, colors = listOf(c.violet.copy(alpha = 0.8f), c.teal.copy(alpha = 0.8f)))
                LogoBar(fill = 0.38f, colors = listOf(c.violet.copy(alpha = 0.5f), c.teal.copy(alpha = 0.5f)))
            }
        }
        Text(
            "sortyd",
            style = MaterialTheme.typography.headlineMedium.copy(
                color = if (c.isDark) Color.White.copy(alpha = 0.4f) else Color(0xFF1A1A2E).copy(alpha = 0.5f),
                fontWeight = FontWeight.Light,
                letterSpacing = 6.sp
            )
        )
    }
}

@Composable
private fun LogoBar(fill: Float, colors: List<Color>) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(3.5.dp)
            .background(Color.White.copy(alpha = 0.07f), CircleShape)
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth(fill)
                .fillMaxHeight()
                .background(Brush.horizontalGradient(colors), CircleShape)
        )
    }
}

@Composable
private fun ObAtmosphere(teal: Color, violet: Color) {
    Box(modifier = Modifier.fillMaxSize()) {
        // Teal blob top-left
        Box(
            modifier = Modifier
                .size(300.dp)
                .offset((-60).dp, 40.dp)
                .blur(80.dp)
                .background(teal.copy(alpha = 0.08f), CircleShape)
        )
        // Violet blob bottom-right
        Box(
            modifier = Modifier
                .size(260.dp)
                .align(Alignment.BottomEnd)
                .offset(40.dp, (-80).dp)
                .blur(70.dp)
                .background(violet.copy(alpha = 0.12f), CircleShape)
        )
    }
}

@Composable
private fun HealthKitBadge() {
    val c = sortydColors
    val heartRed = Color(0xFFFF375F)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(heartRed.copy(alpha = 0.07f), RoundedCornerShape(12.dp))
            .border(0.8.dp, heartRed.copy(alpha = 0.2f), RoundedCornerShape(12.dp))
            .padding(10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Icon(Icons.Default.Favorite, null, tint = heartRed, modifier = Modifier.size(20.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text("Uses Health Connect", style = MaterialTheme.typography.bodySmall.copy(color = c.text0, fontWeight = FontWeight.Bold))
            Text("Reads steps & calories for fitness task tracking", style = MaterialTheme.typography.labelSmall.copy(color = c.text2))
        }
        Icon(Icons.Default.Lock, null, tint = heartRed.copy(alpha = 0.7f), modifier = Modifier.size(16.dp))
    }
}

// ─── Page Data Model ──────────────────────────────────────────────────────────

private data class OBPage(val headline: String, val sub: String)

private fun obPages(lang: AppLanguage): List<OBPage> = when (lang) {
    AppLanguage.ARABIC -> listOf(
        OBPage("اختر لغتك", "يمكنك تغيير هذا لاحقاً في الإعدادات"),
        OBPage("نظم يومك", "نظم عاداتك في قوائم يومية. ركز على ما يهم"),
        OBPage("تحليلات الذكاء الاصطناعي", "احصل على تحليل دقيق لسلوكك. يجد الذكاء الاصطناعي الأنماط التي تفوتك"),
        OBPage("توصيل بـHealth Connect", "زامِن خطواتك وسعراتك تلقائياً. شاهد تقدمك في الوقت الفعلي")
    )
    AppLanguage.SPANISH -> listOf(
        OBPage("Elige tu\nidioma", "Puedes cambiar esto más tarde en los Ajustes"),
        OBPage("Estructura\ntu día", "Agrupa hábitos en listas. Enfócate en lo que importa"),
        OBPage("Análisis con IA", "Obtén un desglose de tu comportamiento. La IA encuentra lo que tú no ves"),
        OBPage("Salud de Android", "Sincroniza pasos y calorías. Mira tu progreso en tiempo real")
    )
    else -> listOf(
        OBPage("Choose your\nlanguage", "You can change this later in Settings"),
        OBPage("Structure\nyour day", "Group habits into daily lists. Focus on what matters, one list at a time"),
        OBPage("AI-Powered\nInsights", "Get a sharp breakdown of your behavior. AI finds the patterns you miss"),
        OBPage("Health Connect\nIntegration", "Sync your steps and calories automatically. See your progress in real-time")
    )
}

package com.sortyd.app.ui.screens.onboarding

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.*
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.health.connect.client.PermissionController
import com.sortyd.app.services.HealthConnectManager
import com.sortyd.app.ui.theme.SortydColors
import com.sortyd.app.viewmodel.SortydViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private val Teal   = Color(0xFF3ECFFF)
private val Violet = Color(0xFF7C6FFF)
private val Pink   = Color(0xFFFF375F)

private data class OBPage(val line1: String, val line2: String, val sub: String)

private fun obPages(lang: String) = when (lang) {
    "ar" -> listOf(
        OBPage("اختر لغتك",          "",                "يمكنك تغيير هذا لاحقاً في الإعدادات."),
        OBPage("نظم",               "يومك",             "نظّم عاداتك في قوائم يومية. ركز على ما يهم."),
        OBPage("تحليلات",           "الذكاء الاصطناعي",  "احصل على تحليل دقيق لسلوكك. يجد الذكاء الاصطناعي الأنماط التي تفوتك."),
        OBPage("Health",            "Connect",          "زامِن خطواتك وسعراتك تلقائياً. شاهد تقدمك في الوقت الفعلي."),
    )
    "es" -> listOf(
        OBPage("Elige tu",          "idioma",           "Puedes cambiar esto más tarde en Ajustes."),
        OBPage("Estructura",        "tu día",           "Agrupa hábitos en listas. Enfócate en lo que importa, una lista a la vez."),
        OBPage("Análisis",          "con IA",           "Obtén un desglose de tu comportamiento. La IA encuentra lo que tú no ves."),
        OBPage("Health",            "Connect",          "Sincroniza pasos y calorías. Mira tu progreso en tiempo real."),
    )
    else -> listOf(
        OBPage("Choose your",       "language",         "You can change this later in Settings."),
        OBPage("Structure",         "your day",         "Group habits into daily lists. Focus on what matters, one list at a time."),
        OBPage("AI-Powered",        "Insights",         "Get a sharp breakdown of your behavior. AI finds the patterns you miss."),
        OBPage("Health",            "Integration",      "Sync your steps and calories automatically. See your progress in real-time."),
    )
}

@Composable
fun OnboardingScreen(
    viewModel: SortydViewModel,
    onComplete: () -> Unit,
) {
    val colors = SortydColors.current
    val context = LocalContext.current
    val healthManager = remember { HealthConnectManager(context) }
    val scope = rememberCoroutineScope()

    val pagerState = rememberPagerState(pageCount = { 4 })
    val currentPage = pagerState.currentPage

    val storedLang by viewModel.selectedLanguage.collectAsState()
    var selectedLang by remember(storedLang) { mutableStateOf(storedLang) }

    var cardReady by remember { mutableStateOf(false) }
    var launched  by remember { mutableStateOf(false) }
    var btnDown   by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) { launched = true }
    LaunchedEffect(currentPage) { cardReady = false; delay(100); cardReady = true }

    val inf = rememberInfiniteTransition(label = "ob_inf")
    val glowPulse     by inf.animateFloat(0f, 1f, infiniteRepeatable(tween(2600, easing = FastOutSlowInEasing), RepeatMode.Reverse), "glow")
    val logoFloat     by inf.animateFloat(0f, -6f, infiniteRepeatable(tween(4200, easing = FastOutSlowInEasing), RepeatMode.Reverse), "logo")
    val meshShift     by inf.animateFloat(0f, 1f, infiniteRepeatable(tween(6500, easing = LinearEasing), RepeatMode.Reverse), "mesh")
    val particlePhase by inf.animateFloat(0f, 1f, infiniteRepeatable(tween(5500, easing = FastOutSlowInEasing), RepeatMode.Reverse), "ptcl")

    val entryProg by animateFloatAsState(if (launched) 1f else 0f, spring(stiffness = Spring.StiffnessMediumLow), label = "entry")
    val btnScale  by animateFloatAsState(if (btnDown) 0.97f else 1f, spring(stiffness = Spring.StiffnessMedium), label = "btn")

    val pages = remember(selectedLang) { obPages(selectedLang) }

    val permissionLauncher = rememberLauncherForActivityResult(
        PermissionController.createRequestPermissionResultContract()
    ) { onComplete() }

    Box(Modifier.fillMaxSize().background(colors.bg0)) {

        // ── Mesh atmosphere ──────────────────────────────────────────
        Box(Modifier.fillMaxSize().blur(55.dp)) {
            Canvas(Modifier.fillMaxSize()) {
                drawOval(
                    brush = Brush.radialGradient(
                        listOf(Teal.copy(0.10f), Color.Transparent),
                        center = Offset(-70f + meshShift * 20f, size.height * 0.04f - meshShift * 10f),
                        radius = 440f
                    ),
                    size = androidx.compose.ui.geometry.Size(440f, 360f)
                )
                drawOval(
                    brush = Brush.radialGradient(
                        listOf(Violet.copy(0.14f), Color.Transparent),
                        center = Offset(size.width * 0.52f - meshShift * 14f, size.height * 0.56f + meshShift * 10f),
                        radius = 380f
                    ),
                    size = androidx.compose.ui.geometry.Size(380f, 340f)
                )
                drawCircle(
                    brush = Brush.radialGradient(
                        listOf(Violet.copy(0.10f), Color.Transparent),
                        center = Offset(size.width * 0.76f, size.height * 0.17f + meshShift * 8f),
                        radius = 240f
                    )
                )
            }
        }

        // ── Floating particles ────────────────────────────────────────
        Canvas(Modifier.fillMaxSize()) {
            val particleData = listOf(
                Triple(0.10f, 0.28f, 55f), Triple(0.86f, 0.16f, 75f), Triple(0.22f, 0.64f, 48f),
                Triple(0.70f, 0.48f, 68f), Triple(0.42f, 0.82f, 88f), Triple(0.62f, 0.10f, 52f),
                Triple(0.06f, 0.54f, 62f), Triple(0.90f, 0.68f, 72f), Triple(0.34f, 0.38f, 44f),
                Triple(0.78f, 0.82f, 60f)
            )
            particleData.forEachIndexed { i, (xf, yf, drift) ->
                val isTeal = i % 2 == 0
                val color = if (isTeal) Teal.copy(0.40f) else Violet.copy(0.40f)
                val cx = size.width * xf
                val cy = size.height * yf - particlePhase * drift
                drawCircle(color, radius = if (i % 3 == 0) 4f else 3f, center = Offset(cx, cy))
            }
        }

        Column(Modifier.fillMaxSize().statusBarsPadding(), horizontalAlignment = Alignment.CenterHorizontally) {

            // ── Logo header ──────────────────────────────────────────
            LogoHeader(
                logoFloat = logoFloat,
                glowPulse = glowPulse,
                modifier = Modifier
                    .padding(top = 20.dp, bottom = 12.dp)
                    .alpha(entryProg)
                    .offset(y = ((1f - entryProg) * -16).dp)
            )

            // ── Showcase cards ───────────────────────────────────────
            HorizontalPager(
                state = pagerState,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(300.dp)
                    .padding(horizontal = 20.dp)
                    .scale(0.92f + entryProg * 0.08f)
                    .alpha(entryProg),
            ) { page ->
                ShowcaseCard(
                    page = page,
                    selectedLang = selectedLang,
                    onLangSelected = { lang -> selectedLang = lang; viewModel.setLanguage(lang) },
                    cardReady = cardReady && currentPage == page,
                )
            }

            Spacer(Modifier.weight(1f))

            // ── Bottom section ───────────────────────────────────────
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier
                    .padding(horizontal = 24.dp)
                    .navigationBarsPadding()
                    .padding(bottom = 20.dp)
                    .alpha(entryProg)
                    .offset(y = ((1f - entryProg) * 26).dp),
            ) {
                // Page dots
                PageDots(currentPage = currentPage, pageCount = 4)

                Spacer(Modifier.height(18.dp))

                // 2-line headline — line2 has teal→violet gradient
                val page = pages.getOrNull(currentPage)
                if (page != null) {
                    Text(
                        page.line1,
                        style = MaterialTheme.typography.headlineMedium.copy(
                            fontWeight = FontWeight.Black,
                            fontSize = 26.sp,
                        ),
                        color = colors.text0,
                        textAlign = TextAlign.Center,
                    )
                    if (page.line2.isNotEmpty()) {
                        Text(
                            page.line2,
                            style = MaterialTheme.typography.headlineMedium.copy(
                                fontWeight = FontWeight.Black,
                                fontSize = 26.sp,
                                brush = Brush.horizontalGradient(listOf(
                                    if (currentPage == 3) Pink else Teal, 
                                    if (currentPage == 3) Color(0xFFFF7E5F) else Violet
                                )),
                            ),
                            textAlign = TextAlign.Center,
                        )
                    }
                    Spacer(Modifier.height(6.dp))
                    Text(
                        page.sub,
                        style = MaterialTheme.typography.bodyMedium.copy(
                            lineHeight = 20.sp,
                            fontSize = 13.sp,
                        ),
                        color = colors.text1.copy(0.55f),
                        textAlign = TextAlign.Center,
                        maxLines = 2,
                        modifier = Modifier.height(40.dp),
                    )
                }

                Spacer(Modifier.height(10.dp))

                // Health Connect disclosure (only on relevant page)
                HealthDisclosure(selectedLang, isVisible = currentPage == 3)

                Spacer(Modifier.height(8.dp))

                // AI disclaimer
                val disclaimer = when (selectedLang) {
                    "ar" -> "تستخدم الرؤى عناوين العادات فقط — تتم معالجتها بأمان."
                    "es" -> "La IA solo usa títulos de hábitos — procesados de forma segura."
                    else -> "AI insights use habit titles only — processed securely, never sold."
                }
                Text(
                    disclaimer,
                    style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
                    color = colors.text2.copy(0.45f),
                    textAlign = TextAlign.Center,
                    maxLines = 2,
                    modifier = Modifier.padding(bottom = 10.dp),
                )

                // CTA button
                val ctaLabel = when {
                    currentPage == 3 -> when (selectedLang) { "ar" -> "ابدأ الآن"; "es" -> "Empezar"; else -> "Get Started" }
                    else -> when (selectedLang) { "ar" -> "متابعة"; "es" -> "Continuar"; else -> "Continue" }
                }
                val ctaGradient = if (currentPage == 3) {
                    Brush.horizontalGradient(listOf(Pink, Color(0xFFFF7E5F)))
                } else {
                    Brush.horizontalGradient(listOf(Teal, Violet))
                }
                
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(54.dp)
                        .scale(btnScale)
                        .clip(RoundedCornerShape(27.dp))
                        .background(ctaGradient)
                        .shadow(
                            elevation = (8 + glowPulse * 8).dp,
                            shape = RoundedCornerShape(27.dp),
                            ambientColor = (if (currentPage == 3) Pink else Teal).copy(0.35f),
                            spotColor = (if (currentPage == 3) Pink else Teal).copy(0.35f),
                        )
                        .clickable {
                            btnDown = true
                            scope.launch {
                                delay(130)
                                btnDown = false
                                when {
                                    currentPage < 3 -> pagerState.animateScrollToPage(currentPage + 1)
                                    HealthConnectManager.isAvailable(context) ->
                                        permissionLauncher.launch(healthManager.permissions)
                                    else -> onComplete()
                                }
                            }
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            ctaLabel,
                            style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold, fontSize = 15.sp),
                            color = Color.White,
                        )
                        Text("→", fontSize = 14.sp, color = Color.White, fontWeight = FontWeight.Bold)
                    }
                }
            }
        }
    }
}

// ── Logo Header ──────────────────────────────────────────────────────────────

@Composable
private fun LogoHeader(logoFloat: Float, glowPulse: Float, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .offset(y = logoFloat.dp)
        ) {
            // Outer glow ring
            Box(
                Modifier
                    .size(68.dp)
                    .clip(RoundedCornerShape(24.dp))
                    .background(Teal.copy(0.03f + glowPulse * 0.07f))
                    .blur(10.dp)
            )
            // Icon container
            Box(
                modifier = Modifier
                    .size(54.dp)
                    .clip(RoundedCornerShape(18.dp))
                    .background(Color(0xFF0E1019))
                    .border(
                        1.dp,
                        Brush.linearGradient(listOf(Teal.copy(0.45f), Violet.copy(0.25f))),
                        RoundedCornerShape(18.dp),
                    ),
                contentAlignment = Alignment.Center,
            ) {
                // Bar chart bars
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 9.dp),
                    verticalArrangement = Arrangement.spacedBy(5.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    LogoBar(1.00f, listOf(Teal, Violet))
                    LogoBar(0.70f, listOf(Violet.copy(0.80f), Teal.copy(0.80f)))
                    LogoBar(0.38f, listOf(Violet.copy(0.50f), Teal.copy(0.50f)))
                }
            }
        }
        Text(
            "sortyd",
            style = MaterialTheme.typography.bodyLarge.copy(
                fontWeight = FontWeight.Light,
                fontSize = 20.sp,
                letterSpacing = 6.sp,
            ),
            color = Color.White.copy(0.40f),
        )
    }
}

@Composable
private fun LogoBar(fill: Float, barColors: List<Color>) {
    Box(
        Modifier
            .fillMaxWidth()
            .height(3.5.dp)
    ) {
        Box(Modifier.fillMaxSize().clip(RoundedCornerShape(2.dp)).background(Color.White.copy(0.07f)))
        Box(
            Modifier
                .fillMaxWidth(fill)
                .fillMaxHeight()
                .clip(RoundedCornerShape(2.dp))
                .background(Brush.horizontalGradient(barColors))
        )
    }
}

// ── Page Dots ────────────────────────────────────────────────────────────────

@Composable
private fun PageDots(currentPage: Int, pageCount: Int) {
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        repeat(pageCount) { i ->
            val width by animateDpAsState(if (i == currentPage) 22.dp else 5.dp, label = "dot_$i")
            val dotBrush = if (i == currentPage) {
                if (i == 3) Brush.horizontalGradient(listOf(Pink, Color(0xFFFF7E5F)))
                else Brush.horizontalGradient(listOf(Teal, Violet))
            } else {
                Brush.linearGradient(listOf(Color.White.copy(0.12f), Color.White.copy(0.12f)))
            }
            Box(
                Modifier
                    .height(5.dp)
                    .width(width)
                    .clip(RoundedCornerShape(3.dp))
                    .background(dotBrush)
            )
        }
    }
}

// ── Health Disclosure Badge ──────────────────────────────────────────────────

@Composable
private fun HealthDisclosure(lang: String, isVisible: Boolean) {
    val colors = SortydColors.current
    
    val alpha by animateFloatAsState(
        targetValue = if (isVisible) 1f else 0f,
        animationSpec = tween(500),
        label = "disclosureAlpha"
    )
    
    if (alpha <= 0.01f) return

    val title = when (lang) { "ar" -> "يستخدم Health Connect"; "es" -> "Usa Health Connect"; else -> "Uses Health Connect" }
    val body  = when (lang) {
        "ar" -> "يقرأ الخطوات والسعرات لتتبع عادات اللياقة البدنية"
        "es" -> "Lee pasos y calorías para rastrear hábitos de fitness"
        else -> "Reads steps & active calories to track fitness habits"
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .alpha(alpha)
            .clip(RoundedCornerShape(14.dp))
            .background(colors.bg1.copy(0.4f))
            .border(
                BorderStroke(
                    0.8.dp,
                    Brush.verticalGradient(listOf(Pink.copy(0.4f), Pink.copy(0.05f)))
                ),
                RoundedCornerShape(14.dp)
            )
            .padding(horizontal = 12.dp, vertical = 10.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier
                .size(30.dp)
                .clip(RoundedCornerShape(8.dp))
                .background(Pink.copy(0.12f)),
            contentAlignment = Alignment.Center,
        ) {
            Text("❤️", fontSize = 13.sp)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold, fontSize = 12.sp), color = colors.text0.copy(0.85f))
            Text(body, style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp), color = colors.text2.copy(0.7f), maxLines = 2)
        }
        Text("🔒", fontSize = 11.sp, color = Pink.copy(0.6f))
    }
}

// ── Showcase Cards ───────────────────────────────────────────────────────────

@Composable
private fun ShowcaseCard(
    page: Int,
    selectedLang: String,
    onLangSelected: (String) -> Unit,
    cardReady: Boolean,
) {
    val (topColor, botColor) = when (page) {
        0 -> Teal to Violet
        1 -> Violet to Teal
        2 -> Teal to Violet
        else -> Pink to Color(0xFFFF7E5F)
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .clip(RoundedCornerShape(26.dp))
            .background(Color(0xFF10111C))
            .background(
                Brush.linearGradient(
                    listOf(topColor.copy(0.07f), botColor.copy(0.03f), Color.Transparent)
                )
            )
            .border(
                2.dp,
                Brush.linearGradient(
                    listOf(topColor.copy(0.34f), botColor.copy(0.14f), Color.White.copy(0.04f))
                ),
                RoundedCornerShape(26.dp),
            ),
    ) {
        // Gloss highlight
        Box(
            Modifier
                .fillMaxSize()
                .background(
                    Brush.linearGradient(
                        listOf(Color.White.copy(0.07f), Color.Transparent),
                        start = Offset(0f, 0f), end = Offset(0f, 200f)
                    )
                )
        )
        when (page) {
            0 -> LanguageCard(selectedLang = selectedLang, onSelect = onLangSelected)
            1 -> HabitsCard(cardReady = cardReady, selectedLang = selectedLang)
            2 -> AICard(cardReady = cardReady, selectedLang = selectedLang)
            3 -> HealthCard(cardReady = cardReady, selectedLang = selectedLang)
        }
    }
}

// ── Card 0: Language Selector ────────────────────────────────────────────────

@Composable
private fun LanguageCard(selectedLang: String, onSelect: (String) -> Unit) {
    val langs = listOf("en" to "English", "es" to "Español", "ar" to "العربية")
    Column(
        Modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterVertically),
    ) {
        langs.forEach { (code, name) ->
            val selected = code == selectedLang
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(if (selected) Teal.copy(0.10f) else Color.White.copy(0.05f))
                    .border(
                        if (selected) 2.dp else 0.dp,
                        if (selected) Teal else Color.Transparent,
                        RoundedCornerShape(12.dp),
                    )
                    .clickable { onSelect(code) }
                    .padding(16.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    name,
                    style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.Bold, fontSize = 16.sp),
                    color = Color.White.copy(if (selected) 1f else 0.75f),
                )
                if (selected) Text("✓", color = Teal, fontWeight = FontWeight.Bold, fontSize = 16.sp)
            }
        }
    }
}

// ── Card 1: Habits Showcase ──────────────────────────────────────────────────

@Composable
private fun HabitsCard(cardReady: Boolean, selectedLang: String) {
    val l: (String) -> String = { key ->
        when (selectedLang) {
            "ar" -> mapOf(
                "YOUR HABITS" to "عاداتك", "Free forever" to "مجاني للأبد",
                "Morning Routine" to "الروتين الصباحي", "5 of 5 complete" to "٥ من ٥ مكتمل",
                "Fitness" to "اللياقة", "Learning" to "التعلم", "Mindfulness" to "التأمل"
            )[key] ?: key
            "es" -> mapOf(
                "YOUR HABITS" to "TUS HÁBITOS", "Free forever" to "Gratis para siempre",
                "Morning Routine" to "Rutina Mañanera", "5 of 5 complete" to "5 de 5 completo",
                "Fitness" to "Fitness", "Learning" to "Aprendizaje", "Mindfulness" to "Mindfulness"
            )[key] ?: key
            else -> key
        }
    }

    Column(
        Modifier.fillMaxSize().padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(0.dp),
    ) {
        // Eyebrow row
        Row(
            Modifier.fillMaxWidth().padding(bottom = 10.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(5.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("⬛", fontSize = 9.sp, color = Teal)
                Text(l("YOUR HABITS"), style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.ExtraBold, fontSize = 9.sp, letterSpacing = 2.sp), color = Teal.copy(0.85f))
            }
            Row(
                Modifier.clip(RoundedCornerShape(10.dp)).background(Teal.copy(0.08f)).border(0.6.dp, Teal.copy(0.22f), RoundedCornerShape(10.dp)).padding(horizontal = 8.dp, vertical = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("✓", color = Teal, fontSize = 9.sp, fontWeight = FontWeight.Bold)
                Text(l("Free forever"), style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp, fontWeight = FontWeight.SemiBold), color = Color.White.copy(0.45f))
            }
        }

        // Hero row — Morning Routine
        val barProg by animateFloatAsState(if (cardReady) 1f else 0f, tween(900, easing = FastOutSlowInEasing), label = "bar_main")
        Row(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(14.dp))
                .background(Teal.copy(0.07f))
                .border(1.dp, Brush.linearGradient(listOf(Teal.copy(0.40f), Teal.copy(0.08f))), RoundedCornerShape(14.dp))
                .padding(11.dp)
                .alpha(if (cardReady) 1f else 0f),
            horizontalArrangement = Arrangement.spacedBy(11.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(Modifier.size(38.dp).clip(RoundedCornerShape(10.dp)).background(Teal.copy(0.14f)), contentAlignment = Alignment.Center) { Text("🌅", fontSize = 20.sp) }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(l("Morning Routine"), style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.Bold, fontSize = 13.sp), color = Color.White)
                    Text("100%", style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.Black, fontSize = 12.sp, brush = Brush.horizontalGradient(listOf(Teal, Violet))))
                }
                Box(Modifier.fillMaxWidth().height(4.dp).clip(RoundedCornerShape(2.dp)).background(Color.White.copy(0.07f))) {
                    Box(Modifier.fillMaxWidth(barProg).fillMaxHeight().background(Brush.horizontalGradient(listOf(Teal, Violet))))
                }
                Row(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically, modifier = Modifier.alpha(if (cardReady) 1f else 0f)) {
                    Text("✓", color = Teal, fontSize = 9.sp)
                    Text(l("5 of 5 complete"), style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp), color = Color.White.copy(0.48f))
                }
            }
        }

        Spacer(Modifier.height(6.dp))

        // Support rows
        listOf("💪" to l("Fitness") to 0.72f, "📚" to l("Learning") to 0.40f, "🧘" to l("Mindfulness") to 0.60f).forEachIndexed { idx, (pair, pct) ->
            val (emoji, name) = pair
            val rowProg by animateFloatAsState(if (cardReady) pct else 0f, tween(800, delayMillis = 220 + idx * 80, easing = FastOutSlowInEasing), label = "sr_$idx")
            Row(
                Modifier.fillMaxWidth().padding(vertical = 4.dp).alpha(if (cardReady) 1f else 0f),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(emoji, fontSize = 13.sp)
                Text(name, style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Medium, fontSize = 11.sp), color = Color.White.copy(0.42f), modifier = Modifier.weight(1f))
                Box(Modifier.width(74.dp).height(3.dp).clip(RoundedCornerShape(2.dp)).background(Color.White.copy(0.07f))) {
                    Box(Modifier.fillMaxWidth(rowProg).fillMaxHeight().background(Brush.horizontalGradient(listOf(Violet.copy(0.75f), Teal.copy(0.75f)))))
                }
                Text("${(pct * 100).toInt()}%", style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp, fontWeight = FontWeight.SemiBold), color = Color.White.copy(0.24f), modifier = Modifier.width(24.dp), textAlign = TextAlign.End)
            }
        }
    }
}

// ── Card 2: AI Insights ──────────────────────────────────────────────────────

@Composable
private fun AICard(cardReady: Boolean, selectedLang: String) {
    val l: (String) -> String = { key ->
        when (selectedLang) {
            "ar" -> mapOf(
                "AI COACH INSIGHTS" to "رؤى مدرب الذكاء الاصطناعي",
                "Mornings beat evenings by 2×" to "الصباح أفضل بمرتين",
                "8am vs. 8pm — consistently" to "٨ صباحاً مقابل ٨ مساءً باستمرار",
                "You skip Fridays 80% of the time" to "تتخطى أيام الجمعة ٨٠٪",
                "Workout streak: personal best!" to "أفضل رقم شخصي للتمارين!",
                "Grade" to "الدرجة", "Weekly" to "أسبوعي", "Streak" to "سلسلة"
            )[key] ?: key
            "es" -> mapOf(
                "AI COACH INSIGHTS" to "RECOMENDACIONES DE IA",
                "Mornings beat evenings by 2×" to "Mañanas rinden 2× más",
                "8am vs. 8pm — constante" to "8am vs 8pm — constante",
                "You skip Fridays 80% of the time" to "Fallas viernes un 80%",
                "Workout streak: personal best!" to "¡Récord personal de entreno!",
                "Grade" to "Nota", "Weekly" to "Semanal", "Streak" to "Racha"
            )[key] ?: key
            else -> key
        }
    }

    Column(
        Modifier.fillMaxSize().padding(17.dp),
        verticalArrangement = Arrangement.spacedBy(9.dp),
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(5.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("✨", fontSize = 9.sp)
            Text(l("AI COACH INSIGHTS"), style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.ExtraBold, fontSize = 9.sp, letterSpacing = 2.sp), color = Violet.copy(0.85f))
        }

        // Featured insight
        val featScale by animateFloatAsState(if (cardReady) 1f else 0.50f, spring(stiffness = Spring.StiffnessMedium), label = "feat")
        val featAlpha by animateFloatAsState(if (cardReady) 1f else 0f, tween(400, delayMillis = 80), label = "featA")
        Row(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(13.dp))
                .background(Color(0xFFFFD60A).copy(0.06f))
                .border(0.8.dp, Color(0xFFFFD60A).copy(0.22f), RoundedCornerShape(13.dp))
                .padding(11.dp)
                .alpha(featAlpha),
            horizontalArrangement = Arrangement.spacedBy(11.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(Modifier.size(38.dp).scale(featScale).clip(RoundedCornerShape(10.dp)).background(Color(0xFFFFD60A).copy(0.14f)), contentAlignment = Alignment.Center) {
                Text("☀️", fontSize = 17.sp)
            }
            Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(l("Mornings beat evenings by 2×"), style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.Bold, fontSize = 12.sp), color = Color.White.copy(0.92f))
                Text(l("8am vs. 8pm — consistently"), style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp), color = Color.White.copy(0.38f))
            }
        }

        // Secondary rows
        listOf("🔥" to l("You skip Fridays 80% of the time") to Color(0xFFFF6B35), "🏆" to l("Workout streak: personal best!") to Teal).forEachIndexed { idx, (pair, color) ->
            val (icon, text) = pair
            val a by animateFloatAsState(if (cardReady) 1f else 0f, tween(400, delayMillis = 140 + idx * 80), label = "si$idx")
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(9.dp))
                    .background(Color.White.copy(0.025f))
                    .border(0.5.dp, Color.White.copy(0.06f), RoundedCornerShape(9.dp))
                    .padding(horizontal = 8.dp, vertical = 6.dp)
                    .alpha(a),
                horizontalArrangement = Arrangement.spacedBy(9.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(Modifier.size(24.dp).clip(RoundedCornerShape(7.dp)).background(color.copy(0.10f)), contentAlignment = Alignment.Center) { Text(icon, fontSize = 10.sp) }
                Text(text, style = MaterialTheme.typography.labelSmall.copy(fontSize = 11.sp), color = Color.White.copy(0.55f))
            }
        }

        // Stat pills
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            listOf("B+" to l("Grade") to Teal, "78%" to l("Weekly") to Violet, "12d" to l("Streak") to Color(0xFFFF6B35)).forEachIndexed { idx, (pair, color) ->
                val (value, label) = pair
                val s by animateFloatAsState(if (cardReady) 1f else 0.78f, spring(stiffness = Spring.StiffnessMedium), label = "sp$idx")
                val a by animateFloatAsState(if (cardReady) 1f else 0f, tween(300, delayMillis = 380 + idx * 90), label = "sa$idx")
                Column(
                    Modifier.weight(1f).scale(s).alpha(a)
                        .clip(RoundedCornerShape(10.dp))
                        .background(color.copy(0.07f))
                        .border(0.5.dp, color.copy(0.16f), RoundedCornerShape(10.dp))
                        .padding(vertical = 8.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(2.dp),
                ) {
                    Text(value, style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Black, fontSize = 17.sp), color = color)
                    Text(label, style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold, fontSize = 8.sp), color = Color.White.copy(0.34f))
                }
            }
        }
    }
}

// ── Card 3: Health Card ──────────────────────────────────────────────────────

@Composable
private fun HealthCard(cardReady: Boolean, selectedLang: String) {
    val l: (String) -> String = { key ->
        when (selectedLang) {
            "ar" -> mapOf(
                "HEALTH SYNC" to "مزامنة الصحة",
                "Steps" to "الخطوات", "Calories" to "السعرات", "Distance" to "المسافة",
                "Daily Goal" to "الهدف اليومي", "Active" to "نشط"
            )[key] ?: key
            "es" -> mapOf(
                "HEALTH SYNC" to "SINCRONIZACIÓN",
                "Steps" to "Pasos", "Calories" to "Calorías", "Distance" to "Distancia",
                "Daily Goal" to "Meta Diaria", "Active" to "Activo"
            )[key] ?: key
            else -> key
        }
    }

    Column(Modifier.fillMaxSize().padding(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(5.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("❤️", fontSize = 9.sp)
            Text(l("HEALTH SYNC"), style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.ExtraBold, fontSize = 9.sp, letterSpacing = 2.sp), color = Pink.copy(0.85f))
        }

        // Hero Stat: Steps
        val stepsProg by animateFloatAsState(if (cardReady) 0.82f else 0f, tween(1200, easing = EaseOutQuart), label = "steps")
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(18.dp))
                .background(Pink.copy(0.05f))
                .border(1.dp, Pink.copy(0.2f), RoundedCornerShape(18.dp))
                .padding(16.dp)
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                    Column {
                        Text(l("Steps"), style = MaterialTheme.typography.labelSmall, color = Color.White.copy(0.5f))
                        Text("8,241", style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Black), color = Color.White)
                    }
                    Box(Modifier.size(40.dp).clip(CircleShape).background(Pink.copy(0.1f)), contentAlignment = Alignment.Center) {
                        Text("👟", fontSize = 20.sp)
                    }
                }
                Box(Modifier.fillMaxWidth().height(6.dp).clip(CircleShape).background(Color.White.copy(0.05f))) {
                    Box(Modifier.fillMaxWidth(stepsProg).fillMaxHeight().background(Brush.horizontalGradient(listOf(Pink, Color(0xFFFF7E5F)))))
                }
                Text("82% of 10,000", style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp), color = Pink.copy(0.7f))
            }
        }

        // Secondary stats
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            listOf("🔥" to "420" to l("Calories"), "📍" to "5.2" to l("Distance")).forEach { (pair, label) ->
                val (emoji, value) = pair
                Column(
                    Modifier.weight(1f).clip(RoundedCornerShape(14.dp)).background(Color.White.copy(0.03f)).border(0.5.dp, Color.White.copy(0.08f), RoundedCornerShape(14.dp)).padding(12.dp),
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Text(emoji, fontSize = 14.sp)
                    Text(value, style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold), color = Color.White)
                    Text(label, style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp), color = Color.White.copy(0.4f))
                }
            }
        }
    }
}

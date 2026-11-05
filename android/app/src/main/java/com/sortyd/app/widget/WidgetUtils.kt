package com.sortyd.app.widget

import android.graphics.*
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import kotlin.math.cos
import kotlin.math.sin

object WidgetUtils {

    // ── COLORS (Matching iOS WTheme) ─────────────────────────
    const val COLOR_BG0 = 0xFF141414.toInt()
    const val COLOR_BG1 = 0xFF1E1E1E.toInt()
    const val COLOR_BG2 = 0xFF282828.toInt()
    const val COLOR_BG3 = 0xFF333333.toInt()
    
    const val COLOR_PRIMARY   = 0xFF3ECFFF.toInt() // Cyan
    const val COLOR_SECONDARY = 0xFF7C6FFF.toInt() // Violet
    
    const val COLOR_TEXT0 = 0xFFFFFFFF.toInt()
    const val COLOR_TEXT1 = 0xFFA0A0A0.toInt()
    const val COLOR_TEXT2 = 0xFF707070.toInt()
    
    const val COLOR_GLASS_BORDER = 0x1FFFFFFF.toInt() // White 12% approx

    const val COLOR_ORANGE   = 0xFFFF7043.toInt()
    const val COLOR_YELLOW   = 0xFFFFCC00.toInt()
    const val COLOR_SKY_BLUE = 0xFF4FC3F7.toInt()

    fun statusColor(fraction: Float): Int {
        return when {
            fraction <= 0f   -> COLOR_BG3
            fraction < 0.40f -> getOpacity(COLOR_SECONDARY, 0.6f)
            fraction < 0.80f -> getOpacity(COLOR_PRIMARY, 0.6f)
            fraction < 1.0f  -> COLOR_SECONDARY
            else             -> COLOR_PRIMARY
        }
    }

    private fun getOpacity(color: Int, opacity: Float): Int {
        val alpha = (255 * opacity).toInt().coerceIn(0, 255)
        return (color and 0x00FFFFFF) or (alpha shl 24)
    }

    private fun getDim(color: Int): Int = getOpacity(color, 0.6f)

    fun bubbleHeat(fraction: Float): Int {
        return when {
            fraction <= 0f   -> COLOR_BG2
            fraction < 0.4f  -> getDim(COLOR_SECONDARY)
            fraction < 0.8f  -> getDim(COLOR_PRIMARY)
            else             -> COLOR_PRIMARY
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: Segmented Radial Arc  (iOS SmallWidget segmentedArc)
    // 24 butt-capped segments, neon accent fill + dim track
    // ─────────────────────────────────────────────────────────
    fun drawSegmentedArc(
        fraction:   Float,
        sizePx:     Int   = 180,
        segments:   Int   = 24,
        accentArgb: Int   = COLOR_PRIMARY,
        trackArgb:  Int   = COLOR_BG3
    ): Bitmap {
        val bmp    = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val paint  = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style      = Paint.Style.STROKE
            strokeWidth = sizePx * 0.14f
            strokeCap  = Paint.Cap.BUTT
        }
        val pad  = paint.strokeWidth / 2f + 4f
        val rect = RectF(pad, pad, sizePx - pad, sizePx - pad)

        val gapDeg         = 4.5f
        val sweepPerSeg    = 360f / segments - gapDeg
        val filledSegments = (fraction * segments).toInt()

        // Track (unfilled)
        paint.color = trackArgb
        for (i in 0 until segments) {
            val startAngle = -90f + i * (360f / segments)
            canvas.drawArc(rect, startAngle, sweepPerSeg, false, paint)
        }

        // Filled segments with gradient color walk
        for (i in 0 until filledSegments) {
            val t = if (segments > 1) i.toFloat() / (segments - 1) else 0f
            paint.color = lerpColor(COLOR_SECONDARY, COLOR_PRIMARY, t)
            val startAngle = -90f + i * (360f / segments)
            canvas.drawArc(rect, startAngle, sweepPerSeg, false, paint)
        }

        // Glow
        if (filledSegments > 0) {
            val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style      = Paint.Style.STROKE
                strokeWidth = sizePx * 0.14f + 6f
                strokeCap  = Paint.Cap.BUTT
                color      = (COLOR_PRIMARY and 0x00FFFFFF) or 0x50000000
                maskFilter = BlurMaskFilter(14f, BlurMaskFilter.Blur.NORMAL)
            }
            val startAngle = -90f + (filledSegments - 1) * (360f / segments)
            canvas.drawArc(rect, startAngle, sweepPerSeg, false, glowPaint)
        }

        return bmp
    }

    // ─────────────────────────────────────────────────────────
    // MARK: Smooth Sparkline  (iOS sparklineGraph)
    // Cubic bezier through points, gradient stroke
    // ─────────────────────────────────────────────────────────
    fun drawSparkline(
        points: List<Float>,
        w: Int  = 300,
        h: Int  = 80,
        accentArgb: Int = COLOR_SECONDARY
    ): Bitmap {
        val bmp    = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        if (points.size < 2) return bmp

        val padded = if (points.size < 7) List(7 - points.size) { 0f } + points else points.takeLast(7)

        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style      = Paint.Style.STROKE
            strokeWidth = 4f
            strokeCap  = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
            shader     = LinearGradient(
                0f, 0f, w.toFloat(), 0f,
                intArrayOf(accentArgb and 0x00FFFFFF, accentArgb),
                null,
                Shader.TileMode.CLAMP
            )
        }

        val path  = Path()
        val stepX = w.toFloat() / (padded.size - 1)

        for (i in padded.indices) {
            val x = i * stepX
            val y = h * (1f - padded[i]).coerceIn(0f, 1f)
            if (i == 0) {
                path.moveTo(x, y)
            } else {
                val px   = (i - 1) * stepX
                val py   = h * (1f - padded[i - 1]).coerceIn(0f, 1f)
                val midX = (px + x) / 2f
                path.cubicTo(midX, py, midX, y, x, y)
            }
        }

        canvas.drawPath(path, paint)
        return bmp
    }

    // ─────────────────────────────────────────────────────────
    // MARK: Liquid Health Tank  (iOS WidgetTank)
    // Rounded rect, bottom-anchored fill
    // ─────────────────────────────────────────────────────────
    fun drawTank(
        progress:   Float,
        accentArgb: Int,
        w: Int = 56,
        h: Int = 72
    ): Bitmap {
        val bmp    = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val radius = w * 0.28f

        // Track
        val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = COLOR_BG3 }
        canvas.drawRoundRect(0f, 0f, w.toFloat(), h.toFloat(), radius, radius, trackPaint)

        // Liquid fill (bottom-anchored)
        val eff     = progress.coerceIn(0.12f, 1f)
        val fillH   = h * eff
        val fillTop = h - fillH

        val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
                0f, h.toFloat(), 0f, fillTop,
                intArrayOf(accentArgb, lerpColor(accentArgb, 0xFFFFFFFF.toInt(), 0.28f)),
                null,
                Shader.TileMode.CLAMP
            )
        }
        val fillPath = Path().apply {
            addRoundRect(0f, fillTop, w.toFloat(), h.toFloat(), radius, radius, Path.Direction.CW)
        }
        canvas.drawPath(fillPath, fillPaint)

        // Soft glow overlay
        if (progress > 0f) {
            val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color      = (accentArgb and 0x00FFFFFF) or 0x28000000
                maskFilter = BlurMaskFilter(8f, BlurMaskFilter.Blur.NORMAL)
            }
            canvas.drawRoundRect(0f, 0f, w.toFloat(), h.toFloat(), radius, radius, glowPaint)
        }

        return bmp
    }

    // ─────────────────────────────────────────────────────────
    // MARK: Solid Ring  (iOS outer/inner ring in MediumWidget)
    // ─────────────────────────────────────────────────────────
    fun drawRingBitmap(
        fraction:   Float,
        sizePx:     Int   = 280,
        strokePx:   Float = 32f,
        accentArgb: Int   = COLOR_PRIMARY,
        trackArgb:  Int   = COLOR_BG3,
        glowArgb:   Int   = 0x00000000,
        padding:    Float = 0f
    ): Bitmap {
        val bmp    = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val half   = strokePx / 2f + padding
        val rect   = RectF(half, half, sizePx - half, sizePx - half)

        // Track
        val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style      = Paint.Style.STROKE
            strokeWidth = strokePx
            strokeCap  = Paint.Cap.ROUND
            color      = trackArgb
        }
        canvas.drawOval(rect, trackPaint)

        // Fill
        val fillSweep = (fraction * 360f).coerceIn(0f, 360f)
        val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style      = Paint.Style.STROKE
            strokeWidth = strokePx
            strokeCap  = Paint.Cap.ROUND
            shader     = SweepGradient(
                sizePx / 2f, sizePx / 2f,
                intArrayOf(COLOR_SECONDARY, COLOR_PRIMARY, COLOR_SECONDARY),
                floatArrayOf(0f, 0.5f, 1f)
            )
        }
        canvas.save()
        canvas.rotate(-90f, sizePx / 2f, sizePx / 2f)
        canvas.drawArc(rect, 0f, fillSweep, false, fillPaint)
        canvas.restore()

        // Glow
        if (glowArgb != 0 && fraction > 0f) {
            val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style      = Paint.Style.STROKE
                strokeWidth = strokePx + 8f
                strokeCap  = Paint.Cap.ROUND
                color      = glowArgb
                maskFilter = BlurMaskFilter(12f, BlurMaskFilter.Blur.NORMAL)
            }
            canvas.save()
            canvas.rotate(-90f, sizePx / 2f, sizePx / 2f)
            canvas.drawArc(rect, 0f, fillSweep.coerceAtMost(30f), false, glowPaint)
            canvas.restore()
        }

        return bmp
    }

    // ─────────────────────────────────────────────────────────
    // MARK: Bar Chart  (iOS 5-day mini bar chart in MediumWidget)
    // ─────────────────────────────────────────────────────────
    fun drawBarChart(
        values:     List<Float>,
        w: Int      = 100,
        h: Int      = 48,
        todayFraction: Float = 0f
    ): Bitmap {
        val bmp    = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val n      = values.size.coerceAtLeast(1)
        val barW   = (w.toFloat() / n) * 0.55f
        val gap    = (w.toFloat() / n) * 0.45f
        val paint  = Paint(Paint.ANTI_ALIAS_FLAG)

        values.forEachIndexed { i, v ->
            val barH = (h * v.coerceIn(0f, 1f)).coerceAtLeast(6f)
            val x    = i * (barW + gap) + gap / 2f
            val top  = h - barH
            val isToday = i == values.size - 1

            paint.color = if (isToday) statusColor(todayFraction) else COLOR_BG2
            
            val r = barW / 2f
            canvas.drawRoundRect(x, top, x + barW, h.toFloat(), r, r, paint)

            if (isToday) {
                val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.STROKE
                    strokeWidth = 2f
                    color = COLOR_GLASS_BORDER
                }
                canvas.drawRoundRect(x, top, x + barW, h.toFloat(), r, r, borderPaint)
            }
        }
        return bmp
    }

    // ─────────────────────────────────────────────────────────
    // MARK: Check Circle  (interactive task pill check mark)
    // ─────────────────────────────────────────────────────────
    fun drawCheckCircle(
        checked:    Boolean,
        sizePx:     Int = 60,
        accentArgb: Int = COLOR_PRIMARY
    ): Bitmap {
        val bmp    = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val cx     = sizePx / 2f
        val cy     = sizePx / 2f
        val r      = sizePx / 2f - 3f

        if (checked) {
            // Filled circle
            val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = getOpacity(accentArgb, 0.25f)
            }
            canvas.drawCircle(cx, cy, r, bgPaint)
            val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style       = Paint.Style.STROKE
                strokeWidth = 3f
                color       = accentArgb
            }
            canvas.drawCircle(cx, cy, r, ringPaint)
            // Checkmark
            val ckPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style       = Paint.Style.STROKE
                strokeWidth = sizePx * 0.13f
                strokeCap   = Paint.Cap.ROUND
                strokeJoin  = Paint.Join.ROUND
                color       = accentArgb
            }
            val path = Path().apply {
                moveTo(cx - r * 0.38f, cy)
                lineTo(cx - r * 0.05f, cy + r * 0.35f)
                lineTo(cx + r * 0.42f, cy - r * 0.3f)
            }
            canvas.drawPath(path, ckPaint)
        } else {
            // Empty ring
            val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style       = Paint.Style.STROKE
                strokeWidth = 3f
                color       = COLOR_GLASS_BORDER
            }
            canvas.drawCircle(cx, cy, r, ringPaint)
        }
        return bmp
    }

    // ─────────────────────────────────────────────────────────
    // MARK: Heatmap Calendar  (iOS MonthlyWidgetView full grid)
    // Uniform circles coloured by completion intensity
    // ─────────────────────────────────────────────────────────
    fun drawHeatmapCalendar(
        year:       Int,
        month:      Int,
        snapshots:  Map<String, Double>,
        w: Int = 700,
        h: Int = 380,
        todayFraction: Float = 0f
    ): Bitmap {
        val bmp    = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)

        val yearMonth = YearMonth.of(year, month)
        val fmt       = DateTimeFormatter.ofPattern("yyyy-MM-dd")
        val today     = LocalDate.now()

        val daysInMonth   = yearMonth.lengthOfMonth()
        val firstDay      = yearMonth.atDay(1)
        val firstDow      = firstDay.dayOfWeek.value % 7
        val columns       = 7
        val totalCells    = firstDow + daysInMonth
        val rows          = (totalCells + columns - 1) / columns

        val hPad = w * 0.03f
        val vPad = h * 0.04f
        val gridW = w - hPad * 2
        val gridH = h - vPad * 2

        val cellW  = gridW / columns
        val cellH  = gridH / rows
        val dia    = minOf(cellW, cellH) * 0.78f
        val radius = dia / 2f

        val dayLetters = listOf("S", "M", "T", "W", "T", "F", "S")

        // Day-of-week header row
        val headerH   = cellH * 0.55f
        val headerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color     = COLOR_TEXT1
            textAlign = Paint.Align.CENTER
            textSize  = (dia * 0.38f).coerceIn(10f, 20f)
            typeface  = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }
        dayLetters.forEachIndexed { col, letter ->
            val cx = hPad + col * cellW + cellW / 2f
            canvas.drawText(letter, cx, vPad + headerH * 0.75f, headerPaint)
        }

        // Divider
        val divPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = COLOR_BG3 }
        canvas.drawRect(hPad, vPad + headerH, w - hPad, vPad + headerH + 1f, divPaint)

        val gridTop = vPad + headerH + 4f

        // Circle cells
        val circlePaint = Paint(Paint.ANTI_ALIAS_FLAG)
        val textPaint   = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textAlign = Paint.Align.CENTER
            textSize  = (dia * 0.30f).coerceIn(8f, 16f)
            typeface  = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }
        val todayPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style       = Paint.Style.STROKE
            strokeWidth = 2.5f
            color       = statusColor(todayFraction)
        }

        for (day in 1..daysInMonth) {
            val cell    = firstDow + day - 1
            val row     = cell / columns
            val col     = cell % columns
            val date    = yearMonth.atDay(day)
            val key     = date.format(fmt)
            val frac    = snapshots[key]?.toFloat() ?: 0f
            val isToday  = date == today
            val isFuture = date.isAfter(today)

            val cx = hPad + col * cellW + cellW / 2f
            val cy = gridTop + row * (gridH / rows) + (gridH / rows) / 2f

            circlePaint.color = bubbleHeat(frac)
            if (isFuture) circlePaint.color = COLOR_BG1

            circlePaint.maskFilter = if (!isFuture && frac > 0.25f)
                BlurMaskFilter(radius * 0.25f, BlurMaskFilter.Blur.NORMAL) else null

            canvas.drawCircle(cx, cy, radius, circlePaint)

            // Today ring
            if (isToday) canvas.drawCircle(cx, cy, radius + 2.5f, todayPaint)

            // Day number
            textPaint.color = when {
                isFuture     -> COLOR_TEXT2
                frac > 0.65f -> COLOR_BG0
                else         -> COLOR_TEXT1
            }
            canvas.drawText(day.toString(), cx, cy + (textPaint.textSize * 0.35f), textPaint)
        }

        return bmp
    }

    // ─────────────────────────────────────────────────────────
    // MARK: Divider line
    // ─────────────────────────────────────────────────────────
    fun drawDivider(w: Int = 1000, h: Int = 2, colorArgb: Int = COLOR_BG3): Bitmap {
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        Canvas(bmp).drawColor(colorArgb)
        return bmp
    }

    // ─────────────────────────────────────────────────────────

    fun drawHealthDial(progress: Float, colorArgb: Int, sizePx: Int): Bitmap {
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = sizePx * 0.12f
            strokeCap = Paint.Cap.ROUND
        }

        val r = sizePx * 0.4f
        val rect = RectF(sizePx/2 - r, sizePx/2 - r, sizePx/2 + r, sizePx/2 + r)
        
        // Track
        paint.color = COLOR_BG3
        canvas.drawArc(rect, 0f, 360f, false, paint)
        
        // Progress
        paint.color = colorArgb
        paint.setShadowLayer(6f, 0f, 0f, colorArgb)
        canvas.drawArc(rect, -90f, progress.coerceIn(0.01f, 1f) * 360f, false, paint)
        
        return bitmap
    }

    // ─────────────────────────────────────────────────────────
    // MARK: Colour helpers
    // ─────────────────────────────────────────────────────────
    private fun lerpColor(from: Int, to: Int, t: Float): Int {
        val f = t.coerceIn(0f, 1f)
        val aF = Color.alpha(from); val rF = Color.red(from); val gF = Color.green(from); val bF = Color.blue(from)
        val aT = Color.alpha(to);   val rT = Color.red(to);   val gT = Color.green(to);   val bT = Color.blue(to)
        return Color.argb(
            (aF + (aT - aF) * f).toInt(),
            (rF + (rT - rF) * f).toInt(),
            (gF + (gT - gF) * f).toInt(),
            (bF + (bT - bF) * f).toInt()
        )
    }
}

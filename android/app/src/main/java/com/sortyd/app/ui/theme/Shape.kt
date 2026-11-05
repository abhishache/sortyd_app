package com.sortyd.app.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Shapes
import androidx.compose.ui.unit.dp

val SortydShapes = Shapes(
    extraSmall = RoundedCornerShape(4.dp),   // r4
    small = RoundedCornerShape(8.dp),        // r8
    medium = RoundedCornerShape(16.dp),      // r16
    large = RoundedCornerShape(20.dp),       // r20
    extraLarge = RoundedCornerShape(24.dp),  // r24
)

// Custom shapes not in M3 Shapes
val SmallMediumShape = RoundedCornerShape(12.dp)   // r12
val PillShape = RoundedCornerShape(32.dp)          // r32 — sheets, pills
val FullCircleShape = RoundedCornerShape(50)        // circle

package com.lingos.app.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

private val Monospace = FontFamily.Monospace

val LINGOSTypography = Typography(
    displayLarge = TextStyle(fontFamily = Monospace, fontWeight = FontWeight.Bold, fontSize = 57.sp, lineHeight = 64.sp),
    displayMedium = TextStyle(fontFamily = Monospace, fontWeight = FontWeight.Bold, fontSize = 45.sp, lineHeight = 52.sp),
    displaySmall = TextStyle(fontFamily = Monospace, fontWeight = FontWeight.Bold, fontSize = 36.sp, lineHeight = 44.sp),
    headlineLarge = TextStyle(fontFamily = Monospace, fontWeight = FontWeight.SemiBold, fontSize = 32.sp, lineHeight = 40.sp),
    headlineMedium = TextStyle(fontFamily = Monospace, fontWeight = FontWeight.SemiBold, fontSize = 28.sp, lineHeight = 36.sp),
    headlineSmall = TextStyle(fontFamily = Monospace, fontWeight = FontWeight.SemiBold, fontSize = 24.sp, lineHeight = 32.sp),
    titleLarge = TextStyle(fontFamily = Monospace, fontWeight = FontWeight.Medium, fontSize = 22.sp, lineHeight = 28.sp),
    titleMedium = TextStyle(fontFamily = Monospace, fontWeight = FontWeight.Medium, fontSize = 16.sp, lineHeight = 24.sp, letterSpacing = 0.15.sp),
    titleSmall = TextStyle(fontFamily = Monospace, fontWeight = FontWeight.Medium, fontSize = 14.sp, lineHeight = 20.sp, letterSpacing = 0.1.sp),
    bodyLarge = TextStyle(fontFamily = Monospace, fontWeight = FontWeight.Normal, fontSize = 16.sp, lineHeight = 24.sp, letterSpacing = 0.5.sp),
    bodyMedium = TextStyle(fontFamily = Monospace, fontWeight = FontWeight.Normal, fontSize = 14.sp, lineHeight = 20.sp, letterSpacing = 0.25.sp),
    bodySmall = TextStyle(fontFamily = Monospace, fontWeight = FontWeight.Normal, fontSize = 12.sp, lineHeight = 16.sp, letterSpacing = 0.4.sp),
    labelLarge = TextStyle(fontFamily = Monospace, fontWeight = FontWeight.Medium, fontSize = 14.sp, lineHeight = 20.sp, letterSpacing = 0.1.sp),
    labelMedium = TextStyle(fontFamily = Monospace, fontWeight = FontWeight.Medium, fontSize = 12.sp, lineHeight = 16.sp, letterSpacing = 0.5.sp),
    labelSmall = TextStyle(fontFamily = Monospace, fontWeight = FontWeight.Medium, fontSize = 11.sp, lineHeight = 16.sp, letterSpacing = 0.5.sp)
)

object SplashTypography {
    val Welcome = TextStyle(fontFamily = Monospace, fontWeight = FontWeight.Bold, fontSize = 36.sp, letterSpacing = 2.sp)
    val Ling = TextStyle(fontFamily = Monospace, fontWeight = FontWeight.Bold, fontSize = 42.sp, letterSpacing = 4.sp)
    val Loading = TextStyle(fontFamily = Monospace, fontWeight = FontWeight.Normal, fontSize = 14.sp, letterSpacing = 1.sp)
    val Log = TextStyle(fontFamily = Monospace, fontWeight = FontWeight.Normal, fontSize = 12.sp, letterSpacing = 0.5.sp)
    val Cursor = TextStyle(fontFamily = Monospace, fontWeight = FontWeight.Bold, fontSize = 42.sp)
}

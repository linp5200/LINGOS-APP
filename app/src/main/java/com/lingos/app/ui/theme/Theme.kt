package com.lingos.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat

private val DarkColorScheme = darkColorScheme(
    background = LINGOSColors.Background,
    surface = LINGOSColors.Surface,
    primary = LINGOSColors.AccentRed,
    secondary = LINGOSColors.AccentCyan,
    tertiary = LINGOSColors.Success,
    onBackground = LINGOSColors.TextPrimary,
    onSurface = LINGOSColors.TextPrimary,
    onPrimary = Color.White,
    onSecondary = Color.White
)

@Composable
fun LINGOSTheme(content: @Composable () -> Unit) {
    val colorScheme = DarkColorScheme
    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as androidx.activity.ComponentActivity).window
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = false
            WindowCompat.getInsetsController(window, view).isAppearanceLightNavigationBars = false
        }
    }
    MaterialTheme(
        colorScheme = colorScheme,
        typography = LINGOSTypography,
        content = content
    )
}

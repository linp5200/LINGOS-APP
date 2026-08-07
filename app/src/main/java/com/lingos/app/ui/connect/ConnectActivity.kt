package com.lingos.app.ui.connect

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import com.lingos.app.ui.theme.LINGOSTheme
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class ConnectActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) { super.onCreate(savedInstanceState); enableEdgeToEdge(); setContent { LINGOSTheme { Surface(modifier=Modifier.fillMaxSize(), color=MaterialTheme.colorScheme.background) { ConnectScreen(onConnected={ startActivity(android.content.Intent(this, MainActivity::class.java)); finish() }, onBack={ finish() }) } } } }
}

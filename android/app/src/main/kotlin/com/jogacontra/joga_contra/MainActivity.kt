package com.jogacontra.joga_contra

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        criarCanalDeAvisos()
    }

    /**
     * Canal das notificações push (Android 8+). O mesmo id é enviado pelo
     * backend (CANAL_ANDROID em backend/src/services/push.ts) e é o canal
     * padrão do Firebase no AndroidManifest.xml. Criar de novo não muda nada.
     */
    private fun criarCanalDeAvisos() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val canal = NotificationChannel(
            "joga_contra_avisos",
            "Avisos do Joga Contra",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Desafios, jogos confirmados, cancelamentos e mensagens."
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(canal)
    }
}

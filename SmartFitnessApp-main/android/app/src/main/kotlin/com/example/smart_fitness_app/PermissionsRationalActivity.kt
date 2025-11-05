package com.example.smart_fitness_app

import android.app.Activity
import android.os.Bundle
import android.widget.TextView

class PermissionsRationalActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?){
        super.onCreate(savedInstanceState)

        val message = """
            smart fitness app uses health connect data (steps and heart rate) to display your daily progress. your health data stays on your device and is never shared without your permission.
        """.trimIndent()

        val textView = TextView(this)
        textView.text = message
        textView.textSize = 18f
        textView.setPadding(32,32,32,32)
        setContentView(textView)
    }
}


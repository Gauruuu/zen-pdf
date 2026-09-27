package com.zenpdf.app.zen_pdf

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

import android.provider.OpenableColumns

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.zenpdf.app/intents"
    private var initialPdfPath: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent?.action == Intent.ACTION_VIEW || intent?.action == Intent.ACTION_SEND) {
            val uri: Uri? = intent.data ?: intent.getParcelableExtra(Intent.EXTRA_STREAM)
            if (uri != null) {
                initialPdfPath = copyUriToTempFile(uri)
            }
        }
    }

    private fun copyUriToTempFile(uri: Uri): String? {
        return try {
            if (uri.scheme == "file") {
                return uri.path
            }
            var fileName = "opened_document.pdf"
            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (nameIndex != -1) {
                        val name = cursor.getString(nameIndex)
                        if (!name.isNullOrEmpty()) {
                            fileName = name
                        }
                    }
                }
            }

            if (fileName == "opened_document.pdf" && uri.lastPathSegment != null) {
                val segment = uri.lastPathSegment!!
                if (segment.contains(".")) {
                    fileName = segment
                }
            }

            // Sanitize file name
            val safeName = fileName.replace("[\\\\/:*?\"<>|]".toRegex(), "_")
            val tempFile = File(cacheDir, "zen_opened_$safeName")
            val inputStream = contentResolver.openInputStream(uri) ?: return null
            val outputStream = FileOutputStream(tempFile)
            inputStream.copyTo(outputStream)
            inputStream.close()
            outputStream.close()
            tempFile.absolutePath
        } catch (e: Exception) {
            null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getInitialPdfPath") {
                result.success(initialPdfPath)
            } else {
                result.notImplemented()
            }
        }
    }
}

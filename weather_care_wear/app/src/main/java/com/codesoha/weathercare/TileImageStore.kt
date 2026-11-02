package com.codesoha.weathercare

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.AtomicFile
import androidx.wear.protolayout.ResourceBuilders
import java.io.ByteArrayOutputStream
import java.io.File
import java.security.MessageDigest

/** 레이아웃과 나중에 도착하는 리소스 요청이 같은 그림을 사용하도록 버전별로 보관한다. */
internal class TileImageStore(context: Context) {
    private val directory = File(context.filesDir, "suite-tile-images")

    fun save(bitmap: Bitmap): String {
        val bytes = ByteArrayOutputStream().use { output ->
            check(bitmap.compress(Bitmap.CompressFormat.PNG, 100, output))
            output.toByteArray()
        }
        val version = "suite-" + MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }
        check(directory.isDirectory || directory.mkdirs())
        val file = File(directory, "$version.png")
        if (!file.exists()) {
            val atomic = AtomicFile(file)
            val output = atomic.startWrite()
            try { output.write(bytes); atomic.finishWrite(output) }
            catch (error: Throwable) { atomic.failWrite(output); throw error }
        }
        // 최신 32개는 유지하고, 오래된 요청도 하루 동안은 처리한다.
        directory.listFiles { candidate -> candidate.extension == "png" }
            ?.sortedByDescending { it.lastModified() }?.drop(32)
            ?.filter { it != file && it.lastModified() < System.currentTimeMillis() - 86_400_000 }
            ?.forEach { it.delete() }
        return version
    }

    fun load(version: String): ResourceBuilders.Resources {
        require(version.matches(Regex("suite-[0-9a-f]{64}")))
        val bytes = File(directory, "$version.png").readBytes()
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        check(bounds.outWidth > 0 && bounds.outHeight > 0)
        val image = ResourceBuilders.ImageResource.Builder().setInlineResource(ResourceBuilders.InlineImageResource.Builder()
            .setData(bytes).setWidthPx(bounds.outWidth).setHeightPx(bounds.outHeight).build()).build()
        return ResourceBuilders.Resources.Builder().setVersion(version).addIdToImageMapping(IMAGE_ID, image).build()
    }

    companion object { const val IMAGE_ID = "suite-weather" }
}

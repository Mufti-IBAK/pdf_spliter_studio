package com.slicepdf.studio.pdf_spliter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode

class MainActivity : FlutterActivity() {
    override fun getRenderMode(): RenderMode {
        // Use TextureView instead of SurfaceView so the Flutter rendering surface
        // remains attached and never turns blank when returning from the Android
        // system File Picker or Share sheets on OEM / Android Go devices.
        return RenderMode.texture
    }
}

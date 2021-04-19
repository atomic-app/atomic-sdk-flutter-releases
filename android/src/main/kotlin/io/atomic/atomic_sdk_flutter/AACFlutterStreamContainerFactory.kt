package io.atomic.atomic_sdk_flutter

import android.content.Context
import io.atomic.atomic_sdk_flutter.utils.toMap
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.JSONMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import org.json.JSONObject

/** Factory that generates Atomic stream containers for use in Flutter. */
class AACFlutterStreamContainerFactory(private val binaryMessenger: BinaryMessenger) :
    PlatformViewFactory(JSONMessageCodec.INSTANCE) {

  override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
    var params: Map<String, Any?> = (args as? JSONObject)?.toMap() ?: mapOf()
    return AACFlutterStreamContainer(context, params, viewId, binaryMessenger)
  }
}

package io.atomic.atomic_sdk_flutter.helpers

import com.atomic.actioncards.sdk.AACSessionDelegate

class AACFlutterSessionDelegate(private val token: String?) : AACSessionDelegate() {
  override fun getToken(completionHandler: (String?, Exception?) -> Unit) {
    completionHandler(token, null)
  }
}

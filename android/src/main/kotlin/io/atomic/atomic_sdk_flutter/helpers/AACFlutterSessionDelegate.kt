package io.atomic.atomic_sdk_flutter.helpers

import java.util.*

typealias SessionDelegateCallback = (String?) -> Unit

private class AACFlutterSessionDelegateResolutionRequest(val handler: SessionDelegateCallback) {
  val identifier = UUID.randomUUID().toString()
}

class AACFlutterSessionDelegate {
  private var sessionDelegateRequests = mutableMapOf<String, AACFlutterSessionDelegateResolutionRequest>()
  fun didReceiveAuthenticationToken(token: String, identifier: String) {
    val handler = sessionDelegateRequests[identifier]?.handler ?: throw RuntimeException("Request received for authentication token $identifier but no matching request was found.")
    handler(token)
    sessionDelegateRequests.remove(identifier)
  }

  fun didRequestNewAuthenticationToken(callback: SessionDelegateCallback): String {
    val request = AACFlutterSessionDelegateResolutionRequest(callback)
    sessionDelegateRequests[request.identifier] = request
    return request.identifier
  }
}
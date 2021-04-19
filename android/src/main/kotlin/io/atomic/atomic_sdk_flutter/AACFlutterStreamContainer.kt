package io.atomic.atomic_sdk_flutter

import android.content.Context
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.fragment.app.Fragment
import com.atomic.actioncards.sdk.AACSessionDelegate
import com.atomic.actioncards.sdk.AACStreamContainer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import com.atomic.actioncards.sdk.VotingOption
import io.flutter.plugin.platform.PlatformView
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.async
import java.util.*
import kotlinx.coroutines.*

internal class AACFlutterSessionDelegate(private val token: String?): AACSessionDelegate() {
  override fun getToken(completionHandler: (String?, Exception?) -> Unit) {
    completionHandler(token, null)
  }
}

internal class AACFlutterWrapperFragment: Fragment() {

  companion object {
    // View ID is required because Android doesn't assign an ID when the view is created programmatically
    var ID = 2843828
  }

  override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?,
      savedInstanceState: Bundle?): View? {
    var layout = FrameLayout(requireContext())
    var layoutparams = FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT,
        ViewGroup.LayoutParams.MATCH_PARENT)
    layout.layoutParams = layoutparams
    layout.id = ID++
    return layout
  }
}

/** Flutter view that wraps an Atomic stream container. */
internal class AACFlutterStreamContainer(
    private val context: Context,
    private val parameters: Map<String, Any?>,
    viewId: Int, binaryMessenger: BinaryMessenger) : PlatformView {

  private var flutterLogger: AACFlutterLogger = AACFlutterLogger()
  var fragment = AACFlutterWrapperFragment()

  private lateinit var container: AACStreamContainer
  private val channel: MethodChannel = MethodChannel(binaryMessenger,
      "io.atomic.sdk.streamContainer/${viewId}")

  override fun getView(): View {
    return fragment.requireView()
  }

  override fun dispose() {
    container.destroy(fragment.requireView().id)
  }

  init {
    initAACSDK()
  }

  private fun createFrameLayout(context: Context): FrameLayout {
    var layout = FrameLayout(context)
    var layoutparams = FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT,
        ViewGroup.LayoutParams.MATCH_PARENT)
    layout.layoutParams = layoutparams
    return layout
  }

  private fun initAACSDK() {
    val containerId = parameters["containerId"] as String
    val configuration = parameters["configuration"] as java.util.LinkedHashMap<*, *>
    val launchColors = configuration["launchColors"] as java.util.LinkedHashMap<*, *>

    val cardListRefreshInterval = try {
      configuration["pollingInterval"] as Int?
    } catch (e: java.lang.Exception) {
      null
    }

    val votingOption = try {
      configuration["cardVotingOptions"] as String?
    } catch (e: java.lang.Exception) {
      null
    }

    var manager = (context as AACFlutterActivity).supportFragmentManager
    manager.beginTransaction().add(fragment, "AACFlutterWrapperFragment").commitNow()

    var fm = fragment.childFragmentManager

    /**
     * Due to limitations in the Android SDK, we have to request the authentication token once
     * when creating the container, rather than requesting it on-demand.
     */
    CoroutineScope(Dispatchers.Main + NonCancellable).launch {
      val token = getAuthenticationToken()
      var delegate = AACFlutterSessionDelegate(token)
      container = AACStreamContainer.create(containerId, delegate, fm)

      cardListRefreshInterval?.let {
        // The Android SDK expresses the polling interval in milliseconds
        container.cardListRefreshInterval = it.toLong() * 1000
      }

      container.cardVotingOptions = when (votingOption) {
        "none" -> EnumSet.of(VotingOption.None)
        "useful" -> EnumSet.of(VotingOption.Useful)
        "notUseful" -> EnumSet.of(VotingOption.NotUseful)
        "both" -> EnumSet.of(VotingOption.Useful, VotingOption.NotUseful)
        else -> EnumSet.of(VotingOption.None)
      }

      // Launch Colors
      try {
        container.configuration.launchBackgroundColor = (launchColors["background"] as Long).toInt()
      } catch (e: Exception) {
        flutterLogger.error(e)
      }

      try {
        container.configuration.launchLoadingColor = (launchColors["loadingIndicator"] as Long).toInt()
      } catch (e: Exception) {
        flutterLogger.error(e)
      }

      try {
        container.configuration.launchButtonColor = (launchColors["button"] as Long).toInt()
      } catch (e: Exception) {
        flutterLogger.error(e)
      }

      try {
        container.configuration.launchTextColor = (launchColors["text"] as Long).toInt()
      } catch (e: Exception) {
        flutterLogger.error(e)
      }
    }

    // Following: https://stackoverflow.com/a/22312916/1476228
    view.viewTreeObserver?.addOnGlobalLayoutListener {
      container.start(fragment.requireView().id)
    }

  }

  private suspend fun getAuthenticationToken(): String? {
    val deferred = CompletableDeferred<String?>()
    channel.invokeMethod("requestAuthenticationToken", null,
        object : MethodChannel.Result {
          override fun notImplemented() {}

          override fun error(errorCode: String?, errorMessage: String?,
              errorDetails: Any?) {
            deferred.complete(null)
          }

          override fun success(result: Any?) {
            (result as? String)?.let {
              deferred.complete(it)
            } ?: deferred.complete(null)
          }
        })
    return deferred.await()
  }
}

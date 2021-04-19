package io.atomic.atomic_sdk_flutter.utils

import org.json.JSONArray
import org.json.JSONObject

/**
 * Extension function to support a JsonObject conversion into a Map
 * Following https://stackoverflow.com/a/64002903/1476228
 */
fun JSONObject.toMap(): Map<String, *> = keys().asSequence().associateWith {
  when (val value = this[it])
  {
    is JSONArray ->
    {
      val map = (0 until value.length()).associate { Pair(it.toString(), value[it]) }
      JSONObject(map).toMap().values.toList()
    }
    is JSONObject -> value.toMap()
    JSONObject.NULL -> null
    else            -> value
  }
}
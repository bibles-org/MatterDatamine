module postfx_fade_common shared
require ecs
require app
require game.events.events
require game.es.ecs_common
require DagorMath


def postfx_fade_print_log(text)
  print("[PostFx Fade] {text}")


let POSTFX_FADE_DEFAULT_LAYER = int(ecs_hash("default"))
let POSTFX_FADE_DEFAULT_COLOR = float4(0.02, 0.027, 0.02, 0.0)


def postfx_fade_ensure_color_layer(var postfx_fade_controller__layers : Object;
                                   layer_name_hash : int;
                                   default_value : float4;
                                   cb : block<(var color_layer : float4&) : void>)
  ensure_float4(postfx_fade_controller__layers, "{layer_name_hash}", default_value) <| $(var color_layer : float4&)
    cb |> invoke(color_layer)


def postfx_fade_ensure_color_layer(layer_name_hash : int;
                                   default_value : float4;
                                   cb : block<(var color_layer : float4&) : void>)
  find_query() <| $ [es] (var postfx_fade_controller__layers : Object)
    postfx_fade_ensure_color_layer(postfx_fade_controller__layers, layer_name_hash, default_value, cb)
    return true


def postfx_fade_remove_color_layer(layer_name_hash : int)
  find_query() <| $ [es] (var postfx_fade_controller__layers : Object)
    postfx_fade_controller__layers |> erase("{layer_name_hash}")
    return true


def postfx_fade_ensure_color_layer(layer_name_hash : int;
                                   cb : block<(var color_layer : float4&) : void>)
  postfx_fade_ensure_color_layer(layer_name_hash, POSTFX_FADE_DEFAULT_COLOR, cb)


def postfx_fade_set_color(var postfx_fade_controller__layers : Object;
                          layer_name_hash : int;
                          color : float4)
  postfx_fade_print_log("postfx_fade_set_color [{layer_name_hash}] color={color}")
  postfx_fade_ensure_color_layer(postfx_fade_controller__layers, layer_name_hash, POSTFX_FADE_DEFAULT_COLOR) <| $(var color_layer : float4&)
    color_layer = color


def postfx_fade_set_color(layer_name_hash : int;
                          color : float4)
  postfx_fade_print_log("postfx_fade_set_color [{layer_name_hash}] color={color}")
  postfx_fade_ensure_color_layer(layer_name_hash) <| $(var color_layer : float4&)
    color_layer = color


def postfx_fade_stop(layer_name_hash : int = POSTFX_FADE_DEFAULT_LAYER)
  postfx_fade_print_log("postfx_fade_stop [{layer_name_hash}]")
  find_query() <| $ [es] (eid aka postfx_fade_layer_tweening_eid : EntityId;
                          postfx_fade_layer_tweening__layerNameHash : int)
    if postfx_fade_layer_tweening__layerNameHash != layer_name_hash
      return false
    destroyEntity(postfx_fade_layer_tweening_eid)
    return true


def postfx_fade_start(from_color : float4;
                      to_color : float4;
                      time : float;
                      layer_name_hash : int = POSTFX_FADE_DEFAULT_LAYER)
  postfx_fade_print_log("postfx_fade_start [{layer_name_hash}] time={time} {from_color}->{to_color}")
  let curTime = get_sync_time()
  var found = false
  find_query() <| $ [es] (postfx_fade_layer_tweening__layerNameHash : int;
                          postfx_fade_layer_tweening__destroyed : bool;
                          var postfx_fade_layer_tweening__startAt : float&;
                          var postfx_fade_layer_tweening__finishAt : float&;
                          var postfx_fade_layer_tweening__colorFrom : float4&;
                          var postfx_fade_layer_tweening__colorTo : float4&)
    if postfx_fade_layer_tweening__layerNameHash != layer_name_hash
      return false
    if !postfx_fade_layer_tweening__destroyed
      postfx_fade_layer_tweening__startAt = curTime
      postfx_fade_layer_tweening__finishAt = postfx_fade_layer_tweening__startAt + time
      postfx_fade_layer_tweening__colorFrom = from_color
      postfx_fade_layer_tweening__colorTo = to_color
      found = true
    return true

  if !found
    createEntity("postfx_fade_layer_tweening") <| $ [es] (var init : ComponentsInitializer)
      init |> set("postfx_fade_layer_tweening__layerNameHash", layer_name_hash)
      init |> set("postfx_fade_layer_tweening__startAt", curTime)
      init |> set("postfx_fade_layer_tweening__finishAt", curTime + time)
      init |> set("postfx_fade_layer_tweening__colorFrom", from_color)
      init |> set("postfx_fade_layer_tweening__colorTo", to_color)


def postfx_fade_start(to_color : float4;
                      time : float;
                      layer_name_hash : int = POSTFX_FADE_DEFAULT_LAYER)
  postfx_fade_ensure_color_layer(layer_name_hash, float4(to_color.x, to_color.y, to_color.z, 0.0)) <| $(var color_layer : float4&)
    postfx_fade_start(color_layer, to_color, time, layer_name_hash)


def postfx_fade_immediate(color : float4;
                          layer_name_hash : int = POSTFX_FADE_DEFAULT_LAYER)
  postfx_fade_print_log("postfx_fadein_immediate [{layer_name_hash}] color={color}")
  postfx_fade_ensure_color_layer(layer_name_hash) <| $(var color_layer : float4&)
    color_layer = color
    postfx_fade_stop(layer_name_hash)


def postfx_fadein(to_color : float4;
                  time : float;
                  layer_name_hash : int = POSTFX_FADE_DEFAULT_LAYER)
  postfx_fade_start(to_color, time, layer_name_hash)


def postfx_fadein(time : float;
                  layer_name_hash : int = POSTFX_FADE_DEFAULT_LAYER)
  postfx_fade_print_log("postfx_fadein [{layer_name_hash}] time={time}")
  postfx_fade_ensure_color_layer(layer_name_hash) <| $(var color_layer : float4&)
    let toColor = float4(color_layer.x, color_layer.y, color_layer.z, 1.0)
    postfx_fade_start(color_layer, toColor, time, layer_name_hash)


def postfx_fadein_immediate(layer_name_hash : int = POSTFX_FADE_DEFAULT_LAYER)
  postfx_fade_print_log("postfx_fadein_immediate [{layer_name_hash}]")
  postfx_fade_ensure_color_layer(layer_name_hash) <| $(var color_layer : float4&)
    color_layer = float4(color_layer.x, color_layer.y, color_layer.z, 1.0)
    postfx_fade_stop(layer_name_hash)


def postfx_fadeout(time : float;
                   layer_name_hash : int = POSTFX_FADE_DEFAULT_LAYER)
  postfx_fade_print_log("postfx_fadeout [{layer_name_hash}] time={time}")
  postfx_fade_ensure_color_layer(layer_name_hash) <| $(var color_layer : float4&)
    let toColor = float4(color_layer.x, color_layer.y, color_layer.z, 0.0)
    postfx_fade_start(color_layer, toColor, time, layer_name_hash)


def postfx_fadeout_immediate(layer_name_hash : int = POSTFX_FADE_DEFAULT_LAYER)
  postfx_fade_print_log("postfx_fadeout_immediate [{layer_name_hash}]")
  postfx_fade_ensure_color_layer(layer_name_hash) <| $(var color_layer : float4&)
    color_layer = float4(color_layer.x, color_layer.y, color_layer.z, 0.0)
    postfx_fade_stop(layer_name_hash)


def get_postfx_fade_progress(layer_name_hash : int = POSTFX_FADE_DEFAULT_LAYER)
  var result = 0.0
  find_query() <| $ [es] (postfx_fade_layer_tweening__layerNameHash : int;
                          postfx_fade_layer_tweening__startAt : float;
                          postfx_fade_layer_tweening__endAt : float)
    if postfx_fade_layer_tweening__layerNameHash != layer_name_hash
      return false
    result = cvt(get_sync_time(), postfx_fade_layer_tweening__startAt, postfx_fade_layer_tweening__endAt, 0.0, 1.0)
    return true
  return result


def is_postfx_fadein_in_progress(layer_name_hash : int = POSTFX_FADE_DEFAULT_LAYER)
  var result = false
  find_query() <| $ [es] (postfx_fade_layer_tweening__layerNameHash : int;
                          postfx_fade_layer_tweening__colorTo : float4)
    if postfx_fade_layer_tweening__layerNameHash != layer_name_hash
      return false
    result = postfx_fade_layer_tweening__colorTo.w > 0.0
    return true
  return result


def get_endgame_postfx_fade_layer_hash()
  return int(ecs_hash("endgame"))

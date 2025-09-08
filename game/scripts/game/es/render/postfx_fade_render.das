require ecs
require ecs.safe
require game.events.events
require game.es.client.postfx_fade_common
require DagorMath
require DagorShaders


let
  screen_fade_value_colorVarId = get_shader_variable_id("screen_fade_value_color", true)


[es(tag=render, on_appear, track=postfx_fade_controller__layers)]
def postfx_fade_controller_track_progress(evt : Event;
                                          postfx_fade_controller__layers : Object)
  var finalColor : float4

  for layerColorIt, i in postfx_fade_controller__layers, iter_range(postfx_fade_controller__layers)
    let layerColor = layerColorIt.value ?? float4()

    if i == 0
      finalColor = layerColor
    else
      let alpha = lerp(finalColor.w, 1.0, layerColor.w)
      if alpha > 0.0
        let invAlpha = 1.0 / alpha
        finalColor.x = lerp(finalColor.x * finalColor.w, layerColor.x, layerColor.w) * invAlpha
        finalColor.y = lerp(finalColor.y * finalColor.w, layerColor.y, layerColor.w) * invAlpha
        finalColor.z = lerp(finalColor.z * finalColor.w, layerColor.z, layerColor.w) * invAlpha
      else
        finalColor.x = 0.0
        finalColor.y = 0.0
        finalColor.z = 0.0
      finalColor.w = alpha

  DagorShaders::set_color4(screen_fade_value_colorVarId, finalColor)
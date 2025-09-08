options no_aot
require ecs
require game.es.client.postfx_fade_common
require daslib/strings_boost
require DagorConsole
require DagorMath


[console_cmd(name="postfx.fadein")]
def postfx_fadein_cmd(time : float = 1.0;
                      instance_name : string = "default")
  postfx_fadein(time, int(ecs_hash(instance_name)))


[console_cmd(name="postfx.fadeout")]
def postfx_fadeout_cmd(time : float = 1.0;
                       instance_name : string = "default")
  postfx_fadeout(time, int(ecs_hash(instance_name)))


[console_cmd(name="postfx.fadeout_all")]
def postfx_fadeout_all_cmd(time : float = 1.0)
  find_query() <| $ [es] (var postfx_fade_controller__layers : Object)
    for layerData in postfx_fade_controller__layers
      postfx_fadeout(time, to_int(layerData.key))
    return true


[console_cmd(name="postfx.fade_print_all")]
def postfx_fade_print_all_cmd(time : float = 1.0)
  find_query() <| $ [es] (var postfx_fade_controller__layers : Object)
    for layerData in postfx_fade_controller__layers
      var nameData : string
      if layerData.key == string(POSTFX_FADE_DEFAULT_LAYER)
        nameData := " (default)"
      console_print("{layerData.key}{nameData} => {layerData.value}")
    return true


[console_cmd(name="postfx.fade_color")]
def postfx_fade_color_cmd(r : float;
                          g : float;
                          b : float;
                          a : float;
                          time : float = 1.0;
                          instance_name : string = "default")
  postfx_fade_start(float4(r, g, b, a), time, int(ecs_hash(instance_name)))


[console_cmd(name="postfx.noize")]
def postfx_noize_cmd(noize_factor : float = 1.0)
  let found = find_query() <| $ [es] (var postfx_noize_controller__factor : float&)
    postfx_noize_controller__factor = noize_factor
    return true

  if !found
    console_print("postfx_noize_controller is not found!")

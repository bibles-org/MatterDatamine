module light_common shared
require ecs
require game.es.ecs_common
require DagorSystem


def tween_light_brightness(eid : EntityId;
                           target_brightness : float;
                           time : float)
  let tweenStarted = query(eid) <| $ [es] (light__brightness : float;
                                           var light_brightness_transition__newBrightness : float?;
                                           var light_brightness_transition__prevBrightness : float?;
                                           var light_brightness_transition__time : float?;
                                           var light_brightness_transition__timer : float?)
    if (light_brightness_transition__newBrightness != null &&
        light_brightness_transition__prevBrightness != null &&
        light_brightness_transition__time != null)
      *light_brightness_transition__prevBrightness = light__brightness
      *light_brightness_transition__newBrightness = target_brightness
      *light_brightness_transition__time = time
      *light_brightness_transition__timer = 0.0
    else
      addSubTemplate(eid, "light_brightness_transition") <| $(init)
        init |> set("light_brightness_transition__newBrightness", target_brightness)
        init |> set("light_brightness_transition__prevBrightness", light__brightness)
        init |> set("light_brightness_transition__time", time)

  if !tweenStarted
    logerr("{get_entity_info(eid)} don't have light__brightness component!")
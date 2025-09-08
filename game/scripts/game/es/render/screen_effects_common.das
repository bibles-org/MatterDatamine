module screen_effects_common shared
require ecs


def is_camera_allow_effect()
  var cameraAllowEffect = false
  find_query() <| $ [es(REQUIRE_NOT=disableScreenEffects)] (camera__active : bool)
    cameraAllowEffect = camera__active
    return camera__active
  return cameraAllowEffect
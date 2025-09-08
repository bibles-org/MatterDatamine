options no_aot
require ecs
require DagorConsole


[console_cmd(name="camera.disable_effects")]
def camera_disable_effects_debug()
  find_query() <| $ [es] (eid : EntityId;
                          camera__active : bool;
                          disableScreenEffects : Tag const? = null)
    if !camera__active
      return false
    if disableScreenEffects == null
      addSubTemplate(eid, "disable_screen_effects")
    else
      removeSubTemplate(eid, "disable_screen_effects")
    return true
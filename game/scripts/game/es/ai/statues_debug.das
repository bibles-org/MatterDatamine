options no_aot
require ecs
require DagorConsole
require game.es.net_console_macro


[net_console_cmd(name="am.statues_vision_on")]
def console_statues_vision_on()
  find_query() <| $ [es(REQUIRE=stalkerStatuesIgnoreVision)] (eid : EntityId)
    destroyEntity(eid)
    return true
  query() <| $ [es] (var stalker_statue__checkVision : bool&)
    stalker_statue__checkVision = true


[net_console_cmd(name="am.statues_vision_off")]
def console_statues_vision_off()
  let visionIsOff = find_query() <| $ [es(REQUIRE=stalkerStatuesIgnoreVision)] ()
    return true
  if !visionIsOff
    createEntity("stalker_statues_ignore_vision")
  query() <| $ [es] (var stalker_statue__checkVision : bool&)
    stalker_statue__checkVision = false


[es(tag=(server, dev), on_appear)]
def disable_statue_vision_on_appear(evt : Event; var stalker_statue__checkVision : bool&)
  find_query() <| $ [es(REQUIRE=stalkerStatuesIgnoreVision)] ()
    stalker_statue__checkVision = false
    return true
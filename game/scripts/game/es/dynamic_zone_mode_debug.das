options no_aot
require ecs
require game.es.net_console_macro
require game.es.dynamic_zone_mode_common
require DagorConsole


[net_console_cmd(name="dynamic_zone.prepare_final_extraction")]
def dynamic_zone_prepare_final_extraction_cmd(dist = 3.0)
  query() <| $ [es] (var dynamic_zone_controller__state : int&)
    dynamic_zone_controller__state = int(DynamicZoneControllerState.EXTERMINATION)

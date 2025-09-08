options no_aot
require ecs
require DagorConsole
require game.es.net_console_macro


[net_console_cmd(name="player.ribbonsColor")]
def player_ribbonsColor(primaryIdx : int; secondaryIdx : int; @net_player player : EntityId)
  query(player) <| $ [es] (var player_ribbons__curColors : int2&)
    player_ribbons__curColors = int2(primaryIdx, secondaryIdx)

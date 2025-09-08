module stats_game_mode_common shared
require ecs
require DagorSystem

def get_modes()
  var modes : array<string>
  query() <| $ [es] (eid : EntityId; stats_game_mode__name : string)
    if stats_game_mode__name == ""
      logerr("<{getEntityTemplateName(eid)}> has empty stats_game_mode__name component, override it")
      return
    modes |> push(stats_game_mode__name)
  return <- modes

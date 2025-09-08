require app
require ecs
require DngNet
require DagorSystem
require DagorDataBlock
require game.utils.team
require game.es.level_common
require game.events.player_events
require game.events.events_game
require game.events.events
require game.es.player.player_connect_common


[es(REQUIRE=player)]
def player_team_selection_on_base(evt : EventOnPlayerConnected;
                                  eid aka this_player_eid : EntityId;
                                  var team aka this_player_team : int&;
                                  var player__teamEid aka this_player__teamEid : EntityId&)
  if !is_player_base()
    return

  find_query() <| $ [es] (am_teams__players : string)
    this_player__teamEid = create_new_base_team(am_teams__players)
    return true

  query(this_player__teamEid) <| $ [es] (team__id : int; var team__memberEids : EidList)
    team__memberEids |> push(this_player_eid)
    this_player_team = team__id

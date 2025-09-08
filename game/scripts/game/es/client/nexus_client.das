require app
require ecs
require DagorMath
require game.utils.team
require game.events.events_active_matter
require game.es.client.postfx_fade_common


[es(tag=gameClient, on_appear, track=is_local, REQUIRE=nexus_player)]
def enable_ui_on_nexus_start(evt : Event;
                             is_local : bool)
  if !is_local
    return
  broadcastEvent(CmdEnableUi())


[es(tag=gameClient, REQUIRE=player)]
def on_schedule_spawn_entity_for_player_in_nexus_mode_client(evt : CmdNexusStartSpawnSequence;
                                                             is_local : bool)
  if !is_local
    return

  query() <| $ [es] (nexus_spawn_controller__spawnSequenceFadeColor : E3DCOLOR)
    let time = evt.endAt - get_sync_time()
    if time > 0.0
      postfx_fadein(float4(Color4(nexus_spawn_controller__spawnSequenceFadeColor)), time)


[es(tag=gameClient, track=(team, is_local), on_appear, REQUIRE=(nexus_player, team, is_local))]
def nexus_give_players_ribbon_colors(evt : Event)
  let localPlayerTeam = get_local_player_team()
  find_query() <| $ [es] (ribbonNexusEnemyColor : int2;
                          ribbonNexusAllyColor : int2)
    query() <| $ [es] (team : int;
                       var player_ribbons__curColors : int2&)
      if team == TEAM_UNASSIGNED
        return

      if team == localPlayerTeam
        player_ribbons__curColors = ribbonNexusAllyColor
      else
        player_ribbons__curColors = ribbonNexusEnemyColor
    return true

require ecs
require jsonwriter
require net
require game.events.events_game
require game.events.events_active_matter
require game.events.events_game
require app
require ecs.soa_template
require game.es.stats_game_mode_common
require game.es.heatmap_common

[soa_es, es(on_event=EventSessionFinished, REQUIRE=heatmap)]
def send_heatmap_stat(evt : Event;
                      heatmapData : HeatmapData_SOA)
  for modeName in get_modes()
    send_json(heatmapData, modeName, "am_heatmap_stats")

// data collection------------------------------------------------------

def is_player(eid : EntityId)
  return eid != INVALID_ENTITY_ID && !has(eid, "playerIsBot")

def is_monster(eid : EntityId)
  return eid |> has("kill_tracking_tag")

def is_bot(eid : EntityId)
  return eid != INVALID_ENTITY_ID && has(eid, "playerIsBot")


[es]
def on_smth_killed(evt : EventAnyEntityDied)
  var offenderPos = float3(0.)
  query(evt.offender) <| $ [es] (transform : float3x4)
    offenderPos = transform[3]
  var victimPos = float3(0.)
  query(evt.victim) <| $ [es] (transform : float3x4)
    victimPos = transform[3]

  find_query() <| $ [soa_blk, es(REQUIRE=heatmap)] (var heatmapData : HeatmapData_SOA)
    // p -> p
    if is_player(evt.offenderPlayer) && is_player(evt.victimPlayer)
      heatmapData |> push() <| HeatmapData(
        heatmap_data__time = get_sync_time(),
        heatmap_data__position = offenderPos,
        heatmap_data__action = "player_killed_player"
      )
      heatmapData |> push() <| HeatmapData(
        heatmap_data__time = get_sync_time(),
        heatmap_data__position = victimPos,
        heatmap_data__action = "player_killed_by_player"
      )
    // p -> m
    if is_player(evt.offenderPlayer) && is_monster(evt.victim)
      heatmapData |> push() <| HeatmapData(
        heatmap_data__time = get_sync_time(),
        heatmap_data__position = offenderPos,
        heatmap_data__action = "player_killed_monster"
      )
    // m -> p
    if is_monster(evt.offender) && is_player(evt.victimPlayer)
      heatmapData |> push() <| HeatmapData(
        heatmap_data__time = get_sync_time(),
        heatmap_data__position = victimPos,
        heatmap_data__action = "player_killed_by_monster"
      )
    // ? -> m
    if is_monster(evt.victim)
      heatmapData |> push() <| HeatmapData(
        heatmap_data__time = get_sync_time(),
        heatmap_data__position = victimPos,
        heatmap_data__action = "monster_died"
      )
    return true


[es(on_appear, REQUIRE=heroForPlayer, REQUIRE_NOT=am_militant_bot)]
def on_spawn_point(evt : Event; transform : float3x4)
  find_query() <| $ [soa_blk, es(REQUIRE=heatmap)] (var heatmapData : HeatmapData_SOA)
    heatmapData |> push() <| HeatmapData(
      heatmap_data__time = get_sync_time(),
      heatmap_data__position = transform[3],
      heatmap_data__action = "spawn_position"
    )
    return true
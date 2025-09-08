require app
require ecs
require game.utils.spawn
require game.utils.team
require game.events.player_events
require game.events.events_game
require game.es.stat_bq_common


[es]
def spawn_es(evt : CmdSpawnEntityForPlayer;
             eid : EntityId;
             team : int;
             var scoring_player__firstSpawnTime : float&)
  if team == TEAM_UNASSIGNED
    print("[SPAWN] Cannot create player possessed entity for team {team}")
    return

  let teamEid = get_team_eid(team)
  print("[SPAWN] Team = {team}")

  if teamEid == INVALID_ENTITY_ID
    print("[SPAWN] Cannot create player possessed entity for team {team} because of teamEid is invalid")
    return

  spawn_soldier(team, eid)
  if scoring_player__firstSpawnTime <= 0.0
    scoring_player__firstSpawnTime = get_sync_time()


[es]
def spawn_at_transform_es(evt : CmdSpawnEntity;
                          eid : EntityId;
                          team : int;
                          var scoring_player__firstSpawnTime : float&)
  using() <| $(var spawnParams : Object)
    set(spawnParams, "transform", evt.tm)
    set(spawnParams, "team", team)
    spawn_soldier(team, eid, spawnParams)
  if scoring_player__firstSpawnTime <= 0.0
    scoring_player__firstSpawnTime = get_sync_time()


[es(tag=server)]
def schedule_spawn_entity_for_player(evt : CmdScheduleSpawnEntityForPlayer;
                                     eid aka player_eid : EntityId)
  start_delayed_entity_spawn_for_player(player_eid, evt.spawnAt)


[es(tag=server, no_order)]
def spawn_entity_for_player_at_time(act : UpdateStageInfoAct;
                                    eid aka spawn_entity_eid : EntityId;
                                    spawn_entity_for_player_at_time__player : EntityId;
                                    spawn_entity_for_player_at_time__spawnAt : float)
  if act.curTime >= spawn_entity_for_player_at_time__spawnAt
    sendEvent(spawn_entity_for_player_at_time__player, CmdSpawnEntityForPlayer())
    destroyEntity(spawn_entity_eid)
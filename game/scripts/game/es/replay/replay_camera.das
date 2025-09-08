require ecs
require ecs.safe
require app
require game.events.events
require game.events.events_game
require game.utils.hero
require DagorConsole
require DagorMath
require DagorSystem
require DngHuman
require Dacoll
require math
require math.base
require game.utils.team
require player
require game.events.events_active_matter
require DngCamera
require game.es.player_common

[es(tag=playingReplay, REQUIRE=(deadEntity, watchedByPlr), before=am_next_replay_target_es)]
def replay_human_death_cam_timer_es(evt : UpdateStageInfoAct;
                                    replay__deadCamTime : float;
                                    var replay__deadCamTimer : float&)
  replay__deadCamTimer += evt.dt
  if replay__deadCamTimer < replay__deadCamTime
    return

  // Reset timer with very big negative value, to bypass send event twice
  replay__deadCamTimer = -1e10
  sendEvent(get_cur_cam_entity(), NextReplayTarget(delta = 1))

[es(tag=playingReplay, on_event=EventEntityDestroyed, REQUIRE=watchedByPlr)]
def on_watched_player_destroyes_es(evt : Event)
  sendEvent(get_cur_cam_entity(), NextReplayTarget(delta = 1))


def private get_saved_possessed_entity()
  var possessedEntity = INVALID_ENTITY_ID
  query() <| $ [es] (replay__savedState : Object)
    let playerEid = EntityId(uint(replay__savedState.playerEid ?? int(uint(INVALID_ENTITY_ID))))
    query(playerEid) <| $ [es(REQUIRE=player)] (possessed : EntityId)
      query(possessed) <| $ [es(REQUIRE_NOT=deadEntity)] ()
        possessedEntity = playerEid
  return possessedEntity


[es(tag=playingReplay, no_order, REQUIRE=replayCamera)]
def update_is_camera_target_flag(evt : UpdateStageInfoAct;
                                 camera__target : EntityId;
                                 camera__active : bool)
  if camera__active
    query(camera__target) <| $[es] (var isCameraTarget : bool&)
      if !isCameraTarget
        isCameraTarget = true


[es(tag=playingReplay, no_order, REQUIRE=replayCamera)]
def catch_human_view(evt : UpdateStageInfoAct;
                     camera__target : EntityId;
                     camera__active : bool)
  if !camera__active || camera__target != INVALID_ENTITY_ID
    return

  let possessedEntity = get_saved_possessed_entity()
  if !!possessedEntity
    sendEvent(possessedEntity, SetReplayTarget())
    return

  find_query() <| $ [es(REQUIRE_NOT=playerIsBot)] (eid : EntityId; disconnected : bool; possessed : EntityId)
    if disconnected || possessed == INVALID_ENTITY_ID || has(possessed, "deadEntity")
      return false
    sendEvent(eid, SetReplayTarget())
    return true


def private replay_change_camera(camera_eid : EntityId; var tm : float3x4&; var cur_camera__target : EntityId&)
  let curCam = get_cur_cam_entity()
  if curCam == camera_eid
    return
  query(curCam) <| $ [es] (var camera__target : EntityId&; transform : float3x4)
    tm = transform
    set_scene_camera_entity(camera_eid)
    cur_camera__target = camera__target
    camera__target = INVALID_ENTITY_ID
    sendEvent(camera_eid, CmdSetCameraTarget(target = get_watched_entity()))

[es(tag=playingReplay, on_event=ReplaySetFpsCamera)]
def replay_fps_camera_es(evt : Event)
  find_query() <| $ [es(REQUIRE=replayCamera)] (eid : EntityId;
                                                var transform : float3x4&;
                                                var camera__target : EntityId&;
                                                isTpsView : bool = false)
    if isTpsView
      return false
    replay_change_camera(eid, transform, camera__target)
    return true

[es(tag=playingReplay, on_event=ReplaySetFreeTpsCamera)]
def replay_tps_free_camera_es(evt : Event)
  find_query() <| $ [es(REQUIRE=replay_camera__tpsFree)] (eid : EntityId;
                                                          var camera__target : EntityId&;
                                                          var transform : float3x4&)
    replay_change_camera(eid, transform, camera__target)
    return true

[es(tag=playingReplay, on_event=ReplaySetTpsCamera)]
def replay_tps_camera_es(evt : Event)
  find_query() <| $ [es(REQUIRE=replayCamera)] (eid : EntityId;
                                                var transform : float3x4&;
                                                var camera__target : EntityId&;
                                                isTpsView : bool = false)
    if !isTpsView
      return false
    replay_change_camera(eid, transform, camera__target)
    return true

[es(tag=playingReplay, on_event=ReplaySetOperatorCamera)]
def replay_set_operator_camera_es(evt : Event)
  find_query() <| $ [es(REQUIRE=replay_camera__operator)] (eid : EntityId;
                                                           var transform : float3x4&;
                                                           var camera__target : EntityId&)
    replay_change_camera(eid, transform, camera__target)
    return true

[es(tag=playingReplay, REQUIRE=replay_camera__track)]
def replay_track_camera_es(evt : ReplaySetTrackCamera;
                           eid : EntityId;
                           var camera__target : EntityId&;
                           var transform : float3x4&)
  replay_change_camera(eid, transform, camera__target)

[es(tag=playingReplay, on_event=ReplaySetCamera)]
def replay_set_camera_by_eid_es(evt : Event;
                                eid : EntityId;
                                var transform : float3x4&;
                                var camera__target : EntityId&)
  replay_change_camera(eid, transform, camera__target)

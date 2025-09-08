require app
require ecs
require game.events.events_game
require game.es.client.postfx_fade_common
require game.es.camera_common
require DngCamera
require DagorSystem
require DagorMath


[es(tag=gameClient)]
def player_spectator_enabled_client(evt : EnableSpectatorForPlayer;
                                    is_local : bool;
                                    possessed : EntityId)
  if !is_local
    return
  removeSubTemplate(possessed, "human_hero_components_local")


def enable_spectator_camera(target : EntityId;
                            possessed : EntityId;
                            team : int;
                            var activeCamEid : EntityId&;
                            var activeCamName : das_string&;
                            waitingForRespawn = false)
  if waitingForRespawn && (possessed |> get_bool("isAlive") ?? false)
    return false
  print("[Spectator] Enable spectator camera for camera entity {int(uint(activeCamEid))} target={target}")
  if possessed != INVALID_ENTITY_ID
    removeSubTemplate(possessed, "observed_local")
  let camTm = get_TMatrix(get_cur_cam_entity(), "transform")
  if camTm == null
    return false
  var spectatedTeam = team
  query(target) <| $ [es] (team : int)
    spectatedTeam = team
  let specCam : EntityId = enable_spectator_camera(*camTm, spectatedTeam, target)
  if activeCamEid != specCam
    destroyEntity(activeCamEid)
  activeCamEid = specCam
  activeCamName := ""
  return true


[es(tag=gameClient)]
def target_enable_spectator_camera(evt : EnableSpectatorForTarget; eid : EntityId)
  query(evt.player) <| $ [es] (possessed : EntityId;
                               team : int;
                               is_local : bool;
                               var activeCamEid : EntityId&;
                               var activeCamName : das_string&;
                               waitingForRespawn = false)
    if !is_local
      logerr("[Spectator] [EnableSpectatorForTarget] Trying to enable spectator camera not on local player <{evt.player}>")
      return
    enable_spectator_camera(eid, possessed, team, activeCamEid, activeCamName, waitingForRespawn)

[es(tag=gameClient)]
def player_enable_spectator_camera(evt : EnableSpectatorForPlayer;
                                   eid, possessed : EntityId;
                                   team : int;
                                   is_local : bool;
                                   var activeCamEid : EntityId&;
                                   var activeCamName : das_string&;
                                   waitingForRespawn = false)
  if !is_local
    logerr("[Spectator] [EnableSpectatorForPlayer] Trying to enable spectator camera not on local player <{eid}>")
    return
  enable_spectator_camera(evt.target, possessed, team, activeCamEid, activeCamName, waitingForRespawn)

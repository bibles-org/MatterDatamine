require ecs
require DagorSystem
require DngCamera
require game.events.events
require game.events.events_game
require game.es.camera_common


def player_switch_camera(player_eid : EntityId; target_eid : EntityId; activeCamEid : EntityId; idx : int = -1;
                         cam_names_eid : EntityId = INVALID_ENTITY_ID)
  query(target_eid) <| $ [es] (activeCamIdx : int; human__lockSwitchCamera : bool = false)
    if !human__lockSwitchCamera && activeCamEid == get_cur_cam_entity()
      possess_entity_camera(target_eid, (idx != -1) ? idx : (activeCamIdx + 1), player_eid, cam_names_eid)

[es(on_event=CmdSwitchCamera, tag=gameClient)]
def player_switch_camera_next(evt : Event; eid : EntityId; possessed : EntityId; activeCamEid : EntityId)
  if possessed |> has("bindedCamera")
    player_switch_camera(eid, possessed, activeCamEid)

[es(tag=gameClient)]
def player_switch_camera_by_index(evt : CmdSwitchCameraByIndex; eid : EntityId; possessed : EntityId; activeCamEid : EntityId)
  if possessed |> has("bindedCamera")
    player_switch_camera(eid, possessed, activeCamEid, evt.index)

[es(tag=gameClient)]
def player_switch_camera_by_entity(evt : CmdSwitchCameraByEntity; eid : EntityId; possessed : EntityId; activeCamEid : EntityId)
  if possessed |> has("bindedCamera")
    player_switch_camera(eid, possessed, activeCamEid, evt.index, evt.camNamesEid)

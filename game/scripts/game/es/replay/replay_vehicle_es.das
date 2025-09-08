require ecs
require game.events.events_game
require DagorMath
require CollRes
require game.es.vehicle.vehicle_seats_common
require vehicle
require DngWeapon
require DagorMathUtils
require DngHuman
require DngCamera
require game.events.events_active_matter


[es(tag=playingReplay, track=(camera__target, camera__active), REQUIRE=(camera__target, replayCamera), before=on_change_vehicle_camera_type_es)]
def replay_camera_set_bind_to_vehicle_es(evt : Event; camera__active : bool; var bindToVehicle : bool&; isTpsView : bool = false)
  if camera__active
    query() <| $ [es(REQUIRE=watchedByPlr)] (human_anim__vehicleSelected : EntityId)
      bindToVehicle = !!human_anim__vehicleSelected && !isTpsView && !!(get_Eid(human_anim__vehicleSelected, "cockpit__eid") ?? INVALID_ENTITY_ID) && !has(human_anim__vehicleSelected, "replay_camera__attachToHuman")
      sendEvent(human_anim__vehicleSelected, CmdUpdateCameraByVehicleType())

[es(tag=playingReplay, on_appear, track=human_anim__vehicleSelected, REQUIRE=watchedByPlr, before=on_change_vehicle_camera_type_es)]
def replay_human_camera_set_bind_to_vehicle_es(evt : Event; human_anim__vehicleSelected : EntityId)
  find_query() <| $ [es] (camera__active : bool; var bindToVehicle : bool&; isTpsView : bool = false)
    if camera__active
      bindToVehicle = !!human_anim__vehicleSelected && !isTpsView  && !!(get_Eid(human_anim__vehicleSelected, "cockpit__eid") ?? INVALID_ENTITY_ID) && !has(human_anim__vehicleSelected, "replay_camera__attachToHuman")
      sendEvent(human_anim__vehicleSelected, CmdUpdateCameraByVehicleType())
    return camera__active

[es(tag=playingReplay, on_appear, track=cockpit__eid, REQUIRE=vehicleWithWatched, REQUIRE_NOT=replay_camera__attachToHuman, before=on_change_vehicle_camera_type_es)]
def replay_human_camera_set_bind_to_vehicle_with_cockpit_es(evt : Event; eid : EntityId; cockpit__eid : EntityId)
  find_query() <| $ [es] (camera__active : bool; var bindToVehicle : bool&; isTpsView : bool = false)
    if camera__active
      bindToVehicle = !isTpsView && !!cockpit__eid
      sendEvent(eid, CmdUpdateCameraByVehicleType())
    return camera__active

[es(tag=playingReplay, on_appear, track=human_anim__vehicleSelected, REQUIRE=watchedByPlr, after=fix_camera_target_es)]
def replay_bind_camera_to_human_after_vehicle_es(evt : Event; eid : EntityId; human_anim__vehicleSelected : EntityId)
  if !!human_anim__vehicleSelected
    return
  find_query() <| $ [es] (camera__active : bool; var camera__target : EntityId&)
    if camera__active
      camera__target = eid
    return camera__active

[es(tag=playingReplay, REQUIRE=watchedByPlr, before=shooter_cam_update_tm_es,
  after=(human_fpv_cam_pos, animchar_cam_target_with_offset_es, animchar_cam_target_es))]
def replay_vehicle_set_tps_camera_look_at(evt : UpdateStageInfoAct;
                                          human_anim__vehicleSelected : EntityId;
                                          isTpsView : bool;
                                          var camera__look_at aka human__camera__look_at : DPoint3&)
  if !isTpsView
    return

  query(human_anim__vehicleSelected) <| $ [es] (transform : float3x4;
                                                collres : CollisionResource;
                                                var camera__look_at : DPoint3&)
    let box = transform * BBox3(collres.vFullBBox.bmin.xyz, collres.vFullBBox.bmax.xyz)
    let pos = box.center
    human__camera__look_at = DPoint3(pos)
    camera__look_at = DPoint3(pos)


[es(tag=playingReplay, REQUIRE=vehicleWithWatched, no_order)]
def replay_set_camera_dir_in_civil_vehicle_es(info : UpdateStageInfoAct; var camera__lookDir : float3&)
  query() <| $ [es(REQUIRE=watchedByPlr)] (human_net_phys : HumanActor)
    camera__lookDir = human_net_phys.phys.currentState.headDir


[es(tag=playingReplay, REQUIRE=watchedByPlr, on_appear, track=(bindedCamera, human_vehicle__occupiedSeatEid))]
def replay_set_tps_camera_in_vehicle_by_seat_es(evt : Event;
                                                human_vehicle__occupiedSeatEid : EntityId;
                                                isTpsView : bool;
                                                bindedCamera : EntityId)
  find_query() <| $ [es] (var replay__prevCam : EntityId&; var replay__curCam : EntityId&)
    if !human_vehicle__occupiedSeatEid
      if bindedCamera != replay__prevCam
        sendEvent(replay__prevCam, ReplaySetCamera())
        replay__prevCam = INVALID_ENTITY_ID
      return true

    query(human_vehicle__occupiedSeatEid) <| $ [es] (seats_order__canPlaceManually : bool)
      if !seats_order__canPlaceManually && !isTpsView
        replay__prevCam = bindedCamera
        find_query() <| $ [es(REQUIRE_NOT=replay_camera__tpsFree)] (eid : EntityId; isTpsView : bool)
          if isTpsView
            sendEvent(eid, ReplaySetCamera())
            replay__curCam = eid
          return isTpsView
      elif replay__curCam != bindedCamera
        replay__prevCam = INVALID_ENTITY_ID
      elif bindedCamera != replay__prevCam
        sendEvent(replay__prevCam, ReplaySetCamera())
        replay__prevCam = INVALID_ENTITY_ID
    return true

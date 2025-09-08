require ecs
require math.base
require DagorMath
require game.es.grav_zones_common
require DagorMathUtils
require game.events.events_active_matter
require AnimV20
require GeomNodeTree
require DagorSystem
require DagorConsole


let FIXED_DT = 1. / 60. // 60hz


[es(tag=playingReplay, after=camera_set_sync, before=before_camera_sync, REQUIRE=replay_camera__tpsFree)]
def replay_tps_free_camera_follow_es(info : UpdateStageInfoAct;
                                     camera__active : bool;
                                     isTpsView : bool;
                                     camera__target : EntityId;
                                     replay_camera__trackingEnabled : bool;
                                     var replay_camera__offset : float3&;
                                     var transform aka cam_transform : float3x4&;
                                     var camera__accuratePos : DPoint3&)
  if !isTpsView || !camera__active || !replay_camera__trackingEnabled
    return

  query(camera__target) <| $ [es] (transform : float3x4)
    let accurPos = float3(camera__accuratePos)
    if accurPos != cam_transform[3]
      replay_camera__offset += cam_transform[3] - accurPos
    let pos = transform[3] + replay_camera__offset
    cam_transform[3] = pos
    camera__accuratePos = DPoint3(cam_transform[3])


[es(after=camera_set_sync, before=before_camera_sync)]
def replay_tps_free_camera_movement_es(evt : UpdateStageInfoAct;
                                       replay_camera__trackingEnabled : bool;
                                       camera__active : bool;
                                       transform aka cam_transform : float3x4;
                                       camera__target : EntityId;
                                       var camera__accuratePos : DPoint3&;
                                       var replay_camera__offset : float3&)
  if !camera__active || replay_camera__trackingEnabled
    return

  camera__accuratePos = DPoint3(cam_transform[3])
  query(camera__target) <| $ [es] (transform : float3x4)
    replay_camera__offset = cam_transform[3] - transform[3]

[es(track=fovSettings, REQUIRE=replay_camera__tpsFree)]
def set_free_tps_camera_fov_es(evt : Event; fovSettings : float; var fov : float&)
  fov = fovSettings

[es(tag=playingReplay, track=camera__active, before=free_tps_camera_update_es)]
def free_tps_initial_rotation_es(evt : Event;
                                 camera__active : bool;
                                 transform : float3x4;
                                 var replay_camera__tpsInputAngle : float2&;
                                 var replay_camera__tpsCurAng : float2&)
  if !camera__active
    return
  let dir = transform[2]
  replay_camera__tpsInputAngle = float2(-atan2(dir.x, dir.z), safe_asin(dir.y))
  replay_camera__tpsCurAng = replay_camera__tpsInputAngle

[es(tag=playingReplay, no_order)]
def free_tps_camera_update_es(info : UpdateStageInfoAct;
                              camera__active : bool;
                              replay_camera__tpsInputAngle : float2;
                              replay_camera__tpsLerpFactor : float;
                              var transform : float3x4&;
                              var replay_camera__tpsCurAng : float2&)
  if !camera__active
    return

  let oldPosition = transform[3]
  replay_camera__tpsCurAng = lerp(replay_camera__tpsCurAng, replay_camera__tpsInputAngle, float2(FIXED_DT * replay_camera__tpsLerpFactor))

  let baseTm = get_grav_tm(oldPosition)
  var tmY, tmX = IDENT_TM
  rotyTM(replay_camera__tpsCurAng.x, tmY)
  rotxTM(replay_camera__tpsCurAng.y, tmX)
  transform = baseTm * tmY * tmX
  transform[3] = oldPosition


[es(tag=playingReplay)]
def replay_track_attach_to_weapon(evt : ReplayTrackAttachToWeapon;
                                  replay_camera__trackingEnabled : bool;
                                  transform aka camera_transform : float3x4;
                                  var replay_camera__trackWeaponEid : EntityId&;
                                  var replay_camera__trackWeaponNodeId : int&;
                                  var replay_camera__trackWeaponRelativeTm : float3x4&)
  query() <| $ [es(REQUIRE=watchedByPlr)] (eid aka soldier_eid : EntityId)
    query(soldier_eid) <| $ [es] (human_weap__currentGunEid : EntityId)
      query(human_weap__currentGunEid) <| $ [es] (animchar : AnimcharBaseComponent)
        let weaponName = getEntityTemplateName(human_weap__currentGunEid)
        var nodeTm : float3x4
        var nodeName = "bullet"
        replay_camera__trackWeaponNodeId = *animchar.nodeTree |> geomtree_findNodeIndex(nodeName)
        if replay_camera__trackWeaponNodeId < 0
          nodeName = "weaponRoot_2"
          replay_camera__trackWeaponNodeId = *animchar.nodeTree |> geomtree_findNodeIndex(nodeName)
        if replay_camera__trackWeaponNodeId < 0
          nodeName = "weaponRoot"
          replay_camera__trackWeaponNodeId = *animchar.nodeTree |> geomtree_findNodeIndex(nodeName)
        if replay_camera__trackWeaponNodeId < 0
          logerr("Cannot attach to a weapon '{weaponName}', node '{nodeName}' not found")
          return
        geomtree_getNodeWtmScalar(*animchar.nodeTree, replay_camera__trackWeaponNodeId, nodeTm)
        replay_camera__trackWeaponRelativeTm = inverse(nodeTm) * camera_transform
        replay_camera__trackWeaponEid = human_weap__currentGunEid
        if !replay_camera__trackingEnabled
          broadcastEvent(ReplayToggleFreeCamera())
        console_print("Camera attached to a weapon '{weaponName}' (node: '{nodeName}')")


[es(tag=playingReplay)]
def replay_track_detach_from_weapon(evt : ReplayTrackDetachFromWeapon;
                                    var replay_camera__trackWeaponEid : EntityId&;
                                    var replay_camera__trackWeaponNodeId : int&;
                                    var replay_camera__trackWeaponRelativeTm : float3x4&)
  replay_camera__trackWeaponEid = INVALID_ENTITY_ID
  replay_camera__trackWeaponNodeId = -1
  replay_camera__trackWeaponRelativeTm = IDENT_TM


[es(tag=playingReplay, after=replay_tps_free_camera_follow_es, REQUIRE=replay_camera__tpsFree)]
def replay_track_follow_weapon_node(info : UpdateStageInfoAct;
                                    isTpsView : bool;
                                    camera__active : bool;
                                    replay_camera__trackingEnabled : bool;
                                    replay_camera__trackWeaponEid : EntityId;
                                    replay_camera__trackWeaponNodeId : int;
                                    replay_camera__trackWeaponRelativeTm : float3x4;
                                    var transform : float3x4&;
                                    var camera__accuratePos : DPoint3&)
  if !isTpsView || !camera__active || !replay_camera__trackingEnabled || replay_camera__trackWeaponNodeId < 0
    return

  query(replay_camera__trackWeaponEid) <| $ [es] (animchar : AnimcharBaseComponent)
    var nodeTm : float3x4
    geomtree_getNodeWtmScalar(*animchar.nodeTree, replay_camera__trackWeaponNodeId, nodeTm)
    transform = nodeTm * replay_camera__trackWeaponRelativeTm
    camera__accuratePos = DPoint3(transform[3])
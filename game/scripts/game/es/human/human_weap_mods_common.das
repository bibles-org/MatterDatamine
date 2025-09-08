module human_weap_mods_common shared
require ecs
require DngHuman
require DagorMath
require AnimV20
require GeomNodeTree


def set_lookat_from_sight_node(cur_time : float;
                               human_net_phys : HumanActor;
                               node_name : string;
                               animchar : AnimcharBaseComponent;
                               human__aimTm : float3x4;
                               human_weap__recoilPunchPos : float;
                               gun_tm : float3x4;
                               bindedCamera : EntityId;
                               cam_shift_min : float;
                               cam_shift_max : float;
                               cam_fov_min : float;
                               cam_fov_max : float;
                               gunmod_eid : EntityId;
                               action__running : bool;
                               var camera__look_at : DPoint3&;
                               var gun_aim_offset : float2&;
                               var camera__lastValidGunAimPos : float3&)
  assume nodeTree = *animchar.nodeTree
  let opticsCamNode = nodeTree |> geomtree_findNodeIndex(node_name) // TODO: redo from get animchar and such stuff, to push it to proper data component
  if opticsCamNode < 0
    return

  let nodeDir = -DPoint3(gun_tm[2])
  let wposRelScalar = nodeTree |> geomtree_getNodeWposRel(opticsCamNode)
  let wtmOfs = nodeTree |> geomtree_getWtmOfs()
  var wpos = DPoint3(wposRelScalar) + DPoint3(wtmOfs)

  query(bindedCamera) <| $ [es] (fov : float;
                                 camera__active : bool)
    if !camera__active
      return

    let lookDir = normalize(human__aimTm[0])
    let shift = cvt(fov, cam_fov_min, cam_fov_max, cam_shift_min, cam_shift_max) - human_weap__recoilPunchPos
    let threshold = 0.5
    wpos += nodeDir * threshold - DPoint3(lookDir) * (shift + threshold)

  assume hphys = human_net_phys.phys
  let interpK = get_phys_interpk_clamped(hphys, cur_time)
  let aimPosition = lerp(hphys.previousState.aimPosition, hphys.currentState.aimPosition, interpK)
  let zoomPosition = lerp(hphys.previousState.zoomPosition, hphys.currentState.zoomPosition, interpK)
  let baseValue = has(gunmod_eid, "isCameraAlwaysOnScope") && !action__running ? 1.0 : 0.0
  let lerpFactor = lerp(0.0, max(zoomPosition, baseValue), aimPosition)

  if !human_net_phys.phys.currentState |> human_phys_state_can_aim()
    wpos = DPoint3(camera__lastValidGunAimPos) + DPoint3(wtmOfs)
  else
    camera__lastValidGunAimPos = float3(wpos) - wtmOfs

  camera__look_at = lerp(camera__look_at, wpos, lerpFactor)
  gun_aim_offset = lerp(gun_aim_offset, float2(0.0, 0.0), float2(lerpFactor))

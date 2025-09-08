module teleport_common shared
require ecs
require DngActor
require DngHuman
require DngPhysObj
require DagorSystem
require game.es.server_debug_common
require game.es.ecs_common
require DngNet
require DagorMath
require game.es.grav_zones_common


def teleport_eid_to(eid : EntityId; pos : float3; use_camera_pos : bool = false)
  if get_DAECS_EXTENSIVE_CHECKS() != 0
    validate_gameplay_position(pos) <| $()
      return <- "teleport_eid_to eid={get_entity_info(eid)}"

  var targetTm : float3x4
  let heroTm = get_TMatrix(eid, "transform")
  let hasCamera = find_query() <| $ [es] (camera__active : bool; transform : float3x4)
    if camera__active
      identity(targetTm)
      targetTm[0] = normalize(cross(float3(0.f, -1.f, 0.f), transform[0]))
      targetTm[2] = normalize(cross(transform[2], float3(0.f, 1.f, 0.f)))
      targetTm[3] = use_camera_pos ? transform[3] : pos
    return camera__active
  if !hasCamera && heroTm != null
    targetTm = *heroTm
    if !use_camera_pos
      targetTm[3] = pos
  elif !hasCamera
    logerr("Failed to get any transform")
    return
  teleport_phys_actor(eid, targetTm)


def teleport_or_request(eid : EntityId; pos : float3)
  if is_server()
    teleport_eid_to(eid, pos, false)
  else
    exec_server_cmd("phys.teleport {pos.x} {pos.y} {pos.z} :hero:")


def teleport_scaled_net_phys_actor(eid : EntityId; pos : float3)
  query(eid) <| $ [es] (var transform : float3x4;
                        var human_net_phys : HumanActor?;
                        var phys_obj_net_phys : PhysObjActor?;
                        scaled_net_phys__scale = 1.0)
    if get_DAECS_EXTENSIVE_CHECKS() != 0
      validate_gameplay_position(pos) <| $()
        return <- "teleport_scaled_net_phys_actor eid={get_entity_info(eid)} transform={transform}"

    let gravTm = get_grav_tm(pos)

    if human_net_phys != null
      (*human_net_phys).phys.currentState.location.P = DPoint3(pos)
    elif phys_obj_net_phys != null
      (*phys_obj_net_phys).phys.currentState.location.P = DPoint3(pos)
    else
      logerr("No net phys actor found during teleport of {get_entity_info(eid)}")

    transform[0] = gravTm[0] * scaled_net_phys__scale
    transform[1] = gravTm[1] * scaled_net_phys__scale
    transform[2] = gravTm[2] * scaled_net_phys__scale
    transform[3] = pos


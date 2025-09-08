module am_nphys_common shared
require ecs
require game.es.ecs_common
require pathfinder
require game.events.events_active_matter
require DngNet


def nphys_teleport_to_position(eid : EntityId;
                               pos : float3)
  var result = false
  query(eid) <| $ [es] (nphys_pushable__elevation : float = .0;
                        var transform aka my_transform : float3x4;
                        var navmesh_phys__prevPos : float3&;
                        var navmesh_phys__currentPos : float3&;
                        var navmesh_phys__currentPoly : int64&)
    var teleportPos = pos
    var teleportPoly = INVALID_POLY_REF
    project_to_nearest_navmesh_point(teleportPos, float3(0.75), teleportPoly)

    validate_gameplay_position(teleportPos) <| $()
      return <- "eid={get_entity_info(eid)}
  transform={my_transform}
  navmesh_phys__currentPos={navmesh_phys__currentPos}
  navmesh_phys__prevPos={navmesh_phys__prevPos}
  navmesh_phys__currentPoly={navmesh_phys__currentPoly}"

    my_transform[3] = teleportPos + my_transform[1] * nphys_pushable__elevation
    navmesh_phys__prevPos = teleportPos
    navmesh_phys__currentPos = teleportPos
    navmesh_phys__currentPoly = int64(teleportPoly)
    result = true
  return result


def nphys_teleport_to_tm(minion_eid : EntityId;
                         dest_tm : float3x4)
  query(minion_eid) <| $ [es] (var transform aka minion_transform : float3x4)
    send_net_event(minion_eid, EventNPhysTeleported(from = minion_transform, to = dest_tm))

    nphys_teleport_to_position(minion_eid, dest_tm[3])

    minion_transform[0] = dest_tm[0]
    minion_transform[1] = dest_tm[1]
    minion_transform[2] = dest_tm[2]
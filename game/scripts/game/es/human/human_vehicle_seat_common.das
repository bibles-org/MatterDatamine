module human_vehicle_seat_common shared
require ecs
require DagorMath
require DngHuman
require GeomNodeTree
require AnimV20
require CollRes


def get_seat_tm(seat_eid : EntityId;
                vehicle_animchar : AnimcharBaseComponent;
                vehicle_collres : CollisionResource;
                vehicle_transform : float3x4;
                var out_tm : float3x4)
  var res = false
  query(seat_eid) <| $ [es] (seats_attach_nodes__nodeId : int;
                             seats_attach_nodes__collNodeId : int;
                             seats_attach_nodes__ignoreAttachNodeRotation : bool;
                             seats_attach_nodes__nodeItm : float3x4;
                             seats_attach_nodes__attachTm : float3x4)
    if seats_attach_nodes__nodeId >= 0
      geomtree_getNodeWtmScalar(*vehicle_animchar.nodeTree, seats_attach_nodes__nodeId, out_tm)
    elif seats_attach_nodes__collNodeId >= 0
      collres_get_collision_node_tm(vehicle_collres, seats_attach_nodes__collNodeId,
                                    vehicle_transform, null, out_tm)
    else
      out_tm = vehicle_transform

    if seats_attach_nodes__ignoreAttachNodeRotation
      let nodePos = out_tm[3]
      out_tm = out_tm * seats_attach_nodes__nodeItm
      out_tm[3] = nodePos
    elif det(out_tm) < 0.0f
      orthonormalize(out_tm)

    out_tm = out_tm * seats_attach_nodes__attachTm
    res = true
  return res


def get_seat_tm(human_eid, vehicle_eid; var out_tm)
  var res = false
  query(vehicle_eid) <| $ [es] (vehicle_seats__seatEids : EidList;
                                animchar : AnimcharBaseComponent;
                                collres : CollisionResource;
                                transform : float3x4)
    var ownerSeatEid = INVALID_ENTITY_ID
    for seatEid in vehicle_seats__seatEids
      let ownerEid = get_Eid(seatEid, "seat__ownerEid") ?? INVALID_ENTITY_ID
      if ownerEid == human_eid
        ownerSeatEid = seatEid
        break
    res = get_seat_tm(ownerSeatEid, animchar, collres, transform, out_tm)
  return res


def update_transform_from_local_seat_tm(is_shooter : bool;
                                        human_anim__vehicleSelected : EntityId;
                                        human_weap__blockAiming : bool = false;
                                        human_net_phys : HumanActor const?;
                                        vehicle__localSeatTm : float3x4&;
                                        var transform aka human_transform : float3x4&)
  let isAiming = human_net_phys != null ? human_net_phys.phys.appliedCT |> is_control_bit_set(HumanPhysControlType.HCT_AIM) : false
  let shootingPassenger = !human_weap__blockAiming && isAiming
  if shootingPassenger == is_shooter
    query(human_anim__vehicleSelected) <| $ [es] (transform : float3x4)
      let seatWtm = transform * vehicle__localSeatTm
      if shootingPassenger
        let helperTm = vehicle__localSeatTm * transform
        let up = normalize(helperTm[1])
        let left = normalize(cross(human_transform[0], up))
        let forward = normalize(cross(up, left))
        human_transform[0] = forward
        human_transform[1] = up
        human_transform[2] = left
        human_transform[3] = seatWtm[3]
      else
        human_transform = seatWtm

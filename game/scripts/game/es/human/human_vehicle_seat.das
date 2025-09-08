require ecs
require math.base
require DagorMath
require PhysMat
require DngHuman
require DngDm
require Dacoll
require AnimV20
require CollRes
require game.es.collision_damage_common
require game.events.events_active_matter
require game.events.events_game
require game.events.events
require game.events.vehicle_events
require game.es.damage_systems.damage_model_common
require game.es.human.human_vehicle_seat_common


[es(before=before_animchar_update_sync)]
def human_vehicle_seats_es(info : ParallelUpdateFrameDelayed;
                           eid : EntityId;
                           isInVehicle : bool;
                           human_anim__vehicleSelected : EntityId;
                           var vehicle__localSeatTm : float3x4&;
                           var vehicle__globalSeatTm : float3x4&)
  if !isInVehicle
    return

  var nodeTm = IDENT_TM
  if !get_seat_tm(eid, human_anim__vehicleSelected, nodeTm)
    return
  query(human_anim__vehicleSelected) <| $ [es] (transform : float3x4)
    let inverseTm = inverse(transform)
    vehicle__localSeatTm = inverseTm * nodeTm
    vehicle__globalSeatTm = nodeTm

[es(before=human_phys_es)]
def human_vehicle_seats_update_phys_es(info : ParallelUpdateFrameDelayed;
                                       eid : EntityId;
                                       isInVehicle : bool;
                                       human_anim__vehicleSelected : EntityId;
                                       var human_net_phys : HumanActor&)
  if !isInVehicle
    return

  var nodeTm = IDENT_TM
  if !get_seat_tm(eid, human_anim__vehicleSelected, nodeTm)
    return
  human_net_phys.phys.currentState.bodyOrientDir = nodeTm[0].xz
  human_net_phys.phys.currentState.moveState = HUMoveState.EMS_STAND
  human_net_phys.phys.currentState.velocity = float3(0.0)
  human_net_phys.phys.currentState.location.P = DPoint3(nodeTm[3])
  human_net_phys.phys.currentState.walkNormal = nodeTm[1]

[es(track=isInVehicle)]
def human_phys_track_vehicle_seats_es(event : Event;
                                      isInVehicle : bool;
                                      var human_net_phys : HumanActor&;
                                      var disable_collision : bool&)
  human_phys_state_set_isAttached(human_net_phys.phys.currentState, isInVehicle)
  disable_collision = isInVehicle


[es(tag=server, before=before_animchar_update_sync, after=(human_locomotion_es, after_net_phys_sync))]
def human_vehicle_seats_non_shooter_pre_animchar_server(info : ParallelUpdateFrameDelayed;
                                                        isInVehicle : bool;
                                                        human_anim__vehicleSelected : EntityId;
                                                        human_weap__blockAiming : bool = false;
                                                        human_net_phys : HumanActor const?;
                                                        vehicle__localSeatTm : float3x4&;
                                                        var transform : float3x4&)
  if !isInVehicle
    return

  update_transform_from_local_seat_tm(/*is_shooter*/false, human_anim__vehicleSelected, human_weap__blockAiming,
                                      human_net_phys, vehicle__localSeatTm, transform)

[es(before=before_animchar_update_sync, after=after_net_phys_sync)]
def human_vehicle_seats_shooter_pre_animchar_es(info : ParallelUpdateFrameDelayed;
                                                isInVehicle : bool;
                                                human_anim__vehicleSelected : EntityId;
                                                human_weap__blockAiming : bool = false;
                                                human_net_phys : HumanActor const?;
                                                vehicle__localSeatTm : float3x4&;
                                                var transform : float3x4&)
  if !isInVehicle
    return

  update_transform_from_local_seat_tm(/*is_shooter*/true, human_anim__vehicleSelected, human_weap__blockAiming,
                                      human_net_phys, vehicle__localSeatTm, transform)


[es(on_appear, track=isPassenger)]
def human_vehicle_update_can_hold_weapon(evt : Event;
                                         isPassenger : bool;
                                         var human_vehicle__canHoldWeapon : bool&)
  human_vehicle__canHoldWeapon = isPassenger


[es(tag=server, on_appear)]
def init_trace_mat_id_for_open_vehicles(evt : Event;
                                        vehicle_seats__traceMatName : string;
                                        var vehicle_seats__traceMatId : int&)
  vehicle_seats__traceMatId = get_material_id(vehicle_seats__traceMatName)


[es(tag=server)]
def kick_passengers_from_open_vehicles(evt : CmdPostPhysUpdate;
                                       animchar : AnimcharBaseComponent;
                                       collres aka vehicle_collres : CollisionResource;
                                       transform aka vehicle_transform : float3x4;
                                       net_phys__currentStateVelocity : float3;
                                       vehicle_seats__humanHeight : float;
                                       vehicle_seats__traceMatId : int;
                                       vehicle_seats__seatEids : EidList)
  for seatEid in vehicle_seats__seatEids
    query(seatEid) <| $ [es] (seat__ownerEid, seat__vehicleEid : EntityId)
      if seat__ownerEid != INVALID_ENTITY_ID
        var tm : float3x4
        if get_seat_tm(seatEid, animchar, vehicle_collres, vehicle_transform, tm)
          var norm : float3
          var pmid = -1
          var riDesc = RendInstDesc()
          var t = vehicle_seats__humanHeight
          if traceray_normalized(tm[3], tm[1], t, pmid, norm, ETF_ALL, riDesc, vehicle_seats__traceMatId)
            query(seat__ownerEid) <| $ [es] (collision_damage__threshold : float;
                                             collision_damage__velDeltaMult : float;
                                             collision_damage__velDeltaPower : float;
                                             collres aka human_collres : CollisionResource;
                                             transform aka human_transform : float3x4;
                                             human_damage_model__parts : Object)
              let dmg = calc_collision_damage(length(net_phys__currentStateVelocity), collision_damage__threshold,
                                      collision_damage__velDeltaMult, collision_damage__velDeltaPower)
              let dmgPos = tm[3] + tm[1] * vehicle_seats__humanHeight * 2.0 //top most. Being upside down moves passanger up in the car.
              var bestNodeId = -1
              var bestDstSq = FLT_MAX
              var tmpTm : float3x4
              for_each_part_in_damage_model(human_damage_model__parts) <| $(bodypart : BodyPartV2)
                if length(bodypart.nodeIds) > 0
                  collres_get_collision_node_tm(human_collres, bodypart.nodeIds[0], human_transform, animchar.nodeTree, tmpTm)
                  let dstSq = distance_sq(tmpTm[3], dmgPos)
                  if dstSq < bestDstSq
                    bestDstSq = dstSq
                    bestNodeId = bodypart.nodeIds[0]
                return true
              if bestNodeId != -1
                human_damage_model_damage_entity(seat__ownerEid, seat__ownerEid, dmg, bestNodeId, DamageType.DM_COLLISION)
            sendEventImmediate(seat__vehicleEid, CmdKickFromVehicle(eid = seat__ownerEid))
            sendEvent(seat__ownerEid, CmdPushPhys(vel = -net_phys__currentStateVelocity, push_immunity = 0.f))
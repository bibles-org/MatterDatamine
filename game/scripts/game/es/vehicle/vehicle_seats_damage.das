require ecs
require vehicle
require math
require math.base
require game.events.events
require game.events.events_active_matter
require game.es.dm_common
require dm
require DagorSystem


def calc_collision_part_damage(deltaSpd : float;
                               threshold : float;
                               velDeltaMult : float;
                               velDeltaPower : float)
  return pow(deltaSpd - threshold, velDeltaPower) * velDeltaMult


[es(after=after_net_phys_sync, before=vehicle_acceleration_es)]
def vehicle_seats_collision_damage_es(info : ParallelUpdateFrameDelayed;
                                      eid : EntityId;
                                      vehicle_seats__seatEids : EidList;
                                      net_phys__atTick : int;
                                      net_phys__currentStateVelocity : float3;
                                      net_phys__previousStateVelocity : float3;
                                      vehicle_acceleration__tick : int;
                                      transform : float3x4;
                                      vehicle_seat_damage__minVelocity : float;
                                      vehicle_seat_damage__velocityMult : float;
                                      vehicle_seat_damage__maxDmgPercent : float;
                                      collision_damage__body__threshold : float = 2.5;
                                      collision_damage__body__velDeltaMult : float = 1.0;
                                      collision_damage__body__velDeltaPower : float = 1.0;
                                      collision_damage__transmission__threshold : float = 2.5;
                                      collision_damage__transmission__velDeltaMult : float = 0.55;
                                      collision_damage__transmission__velDeltaPower : float = 1.0;
                                      collision_damage__engine__threshold : float = 2.5;
                                      collision_damage__engine__velDeltaMult : float = 0.55;
                                      collision_damage__engine__velDeltaPower : float = 1.0;
                                      damage_model : DamageModel const?)
  if net_phys__atTick == vehicle_acceleration__tick
    return
  let prevVelocity = net_phys__previousStateVelocity
  let curVelocity = net_phys__currentStateVelocity
  let deltaVel = curVelocity - prevVelocity
  let deltaSpdSq = length_sq(deltaVel)


  if deltaSpdSq >= square(vehicle_seat_damage__minVelocity)
    // Damage to passengers
    for seatEid in vehicle_seats__seatEids
      let ownerEid = get_Eid(seatEid, "seat__ownerEid") ?? INVALID_ENTITY_ID
      if ownerEid == INVALID_ENTITY_ID
        continue
      sendEvent(ownerEid, EventOnCollision(vel = deltaVel * vehicle_seat_damage__velocityMult,
                                            pvel = prevVelocity, pos = transform[3], offender = eid,
                                            cvel = curVelocity, dt = info.dt,
                                            damage = vehicle_seat_damage__maxDmgPercent))

  // Damage to the vehicle
  if damage_model != null
    // Body
    if deltaSpdSq >= square(collision_damage__body__threshold)
      let damageValue = calc_collision_part_damage(sqrt(deltaSpdSq), collision_damage__body__threshold,
                                                    collision_damage__body__velDeltaMult,
                                                    collision_damage__body__velDeltaPower)
      deal_damage_to_body(eid, eid, damageValue)

    // Transmission
    if deltaSpdSq >= square(collision_damage__transmission__threshold)
      let damageValue = calc_collision_part_damage(sqrt(deltaSpdSq), collision_damage__transmission__threshold,
                                                    collision_damage__transmission__velDeltaMult,
                                                    collision_damage__transmission__velDeltaPower)
      deal_damage_to_transmission(eid, eid, damageValue)

    // Engine
    if deltaSpdSq >= square(collision_damage__engine__threshold)
      let damageValue = calc_collision_part_damage(sqrt(deltaSpdSq), collision_damage__engine__threshold,
                                                    collision_damage__engine__velDeltaMult,
                                                    collision_damage__engine__velDeltaPower)
      deal_damage_to_engine(eid, eid, damageValue)

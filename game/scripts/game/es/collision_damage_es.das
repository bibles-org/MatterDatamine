require ecs
require DagorMath
require DngDm
require app
require game.es.vehicle.vehicle_seats_common
require game.events.events
require game.events.events_game
require game.es.damage_systems.damage_model_common
require game.es.collision_damage_common
require DngHuman
require game.es.dm_common
require game.utils.team
require vehicle
require game.utils.team
require math.base
require HumanPhys

let MIN_DAMAGE_ANGLE_COS = 0.866025f /* cos(PI / 6.) */


[es(tag=server)]
def nphys_collision_damage_vehicle(evt : EventOnCollision;
                                   eid : EntityId;
                                   collision_damage__threshold : float;
                                   collision_damage__velDeltaMult : float;
                                   collision_damage__velDeltaPower : float;
                                   collision_damage__pushThreshold : float;
                                   collision_damage__pushVelDeltaMult : float;
                                   collision_damage__pushVelDeltaPower : float;
                                   hitpoints__hp : float;
                                   collision_damage__lastVehicleImmunity : float = 1.0;
                                   collision_damage__inVehicleDamageMult : float;
                                   navmesh_phys__currentWalkVelocity : float3;
                                   vehicle__lastEid : EntityId const? = null;
                                   vehicle__lastTime : float = 0.f;
                                   isInVehicle : bool = false)
  apply_vehicle_collision_dmg(evt,
                              eid,
                              collision_damage__threshold,
                              collision_damage__velDeltaMult,
                              collision_damage__velDeltaPower,
                              collision_damage__pushThreshold,
                              collision_damage__pushVelDeltaMult,
                              collision_damage__pushVelDeltaPower,
                              hitpoints__hp,
                              collision_damage__lastVehicleImmunity,
                              collision_damage__inVehicleDamageMult,
                              navmesh_phys__currentWalkVelocity,
                              1.0,
                              vehicle__lastEid,
                              vehicle__lastTime,
                              isInVehicle)

[es(tag=server)]
def collision_damage_vehicle(evt : EventOnCollision;
                             eid : EntityId;
                             collision_damage__threshold : float;
                             collision_damage__velDeltaMult : float;
                             collision_damage__velDeltaPower : float;
                             collision_damage__pushThreshold : float;
                             collision_damage__pushVelDeltaMult : float;
                             collision_damage__pushVelDeltaPower : float;
                             hitpoints__hp : float const?;
                             human_damage_model__sumHpAllBodyParts : float const?;
                             collision_damage__lastVehicleImmunity : float;
                             collision_damage__inVehicleDamageMult : float;
                             collision_damage__crawlMult : float;
                             collision_damage__downedMult : float;
                             human_net_phys : HumanActor;
                             vehicle__lastEid : EntityId const? = null;
                             vehicle__lastTime : float = 0.f;
                             isInVehicle : bool = false)
  var hp = 0.0
  if human_damage_model__sumHpAllBodyParts != null
    hp = *human_damage_model__sumHpAllBodyParts
  elif hitpoints__hp != null
    hp = *hitpoints__hp
  else
    return

  var poseDmgMult = 1.0
  if human_net_phys.phys.currentState.isCrawl
    poseDmgMult *= collision_damage__crawlMult
  elif human_phys_state_get_is_downed(human_net_phys.phys.currentState)
    poseDmgMult *= collision_damage__downedMult

  apply_vehicle_collision_dmg(evt,
                              eid,
                              collision_damage__threshold,
                              collision_damage__velDeltaMult,
                              collision_damage__velDeltaPower,
                              collision_damage__pushThreshold,
                              collision_damage__pushVelDeltaMult,
                              collision_damage__pushVelDeltaPower,
                              hp,
                              collision_damage__lastVehicleImmunity,
                              collision_damage__inVehicleDamageMult,
                              human_net_phys.phys.currentState.standingVelocity,
                              poseDmgMult,
                              vehicle__lastEid,
                              vehicle__lastTime,
                              isInVehicle)


def get_vehicle_collision_victim_mass(eid : EntityId)
  var mass = 70.0
  query(eid) <| $ [es] (nphys__mass : float const?;
                        human_net_phys : HumanActor const?)
    if nphys__mass != null
      mass = *nphys__mass
    elif human_net_phys != null
      mass = human_net_phys.phys.mass

  return mass


def apply_vehicle_collision_dmg(evt : EventOnCollision;
                                eid : EntityId;
                                collision_damage__threshold : float;
                                collision_damage__velDeltaMult : float;
                                collision_damage__velDeltaPower : float;
                                collision_damage__pushThreshold : float;
                                collision_damage__pushVelDeltaMult : float;
                                collision_damage__pushVelDeltaPower : float;
                                current_hp : float;
                                collision_damage__lastVehicleImmunity : float;
                                collision_damage__inVehicleDamageMult : float;
                                standing_velocity : float3;
                                pose_damage_mult : float;
                                vehicle__lastEid : EntityId const? = null;
                                vehicle__lastTime : float = 0.f;
                                isInVehicle : bool = false)
  if !(has(evt.offender, "vehicle") && (get_bool(evt.offender, "collision_damage__canBeOffender") ?? false))
    return

  let offenderVel = evt.cvel
  let offenderSpd = length(offenderVel)
  if !isInVehicle && offenderSpd < collision_damage__threshold && offenderSpd < collision_damage__pushThreshold
    return
  let offender = evt.offender
  if !isInVehicle && vehicle__lastEid != null && *vehicle__lastEid == offender && vehicle__lastTime + collision_damage__lastVehicleImmunity > get_sync_time()
    return

  let dv = evt.vel
  let deltaSpd = length(dv)
  var dmg = calc_collision_damage(deltaSpd, collision_damage__threshold,
                                        collision_damage__velDeltaMult, collision_damage__velDeltaPower)
  if dmg <= 0.f
    let standingVelDiff = offenderVel - standing_velocity
    let threshold = 0.4f
    if length_sq(standingVelDiff) > square(threshold)
      let dt = evt.dt
      dmg = dt * calc_collision_damage(offenderSpd, collision_damage__pushThreshold,
                                      collision_damage__pushVelDeltaMult, collision_damage__pushVelDeltaPower)
  let driver = offender != INVALID_ENTITY_ID ? get_vehicle_driver(offender) : INVALID_ENTITY_ID
  if isInVehicle
    dmg *= collision_damage__inVehicleDamageMult
  elif driver != INVALID_ENTITY_ID
    // Not in vehicle offender driver
    // this means a vehicle runs over us, if we're in crawl or downed state apply
    // additional damage, this should kill a lot faster.
    dmg *= pose_damage_mult
  let maxDmgPercent = evt.damage
  if maxDmgPercent >= 0.0f
    dmg = min(dmg, current_hp * maxDmgPercent)
  if dmg <= 0.f
    return

  let pos = evt.pos
  query(offender) <| $ [es] (transform : float3x4; collision_damage__forwardDamageToHumanMult : float)
    let dirToHuman = pos - transform[3]
    let forward = transform[0]
    if dot(forward, dirToHuman) > MIN_DAMAGE_ANGLE_COS
      dmg *= collision_damage__forwardDamageToHumanMult

  damage_entity(eid, offender, DamageDesc(DamageType.DM_COLLISION, dmg, pos, -dv))

  // Vehicle ram damage
  query(offender) <| $ [es(REQUIRE=damage_model)] (vehicle_net_phys : VehiclePhysActor;
                                                   transform aka vehicle_transform : float3x4;
                                                   collision_damage__ram__kineticEnergyDmgMult : float = 0.00015;
                                                   collision_damage__ram__speedThreshold : float;
                                                   collision_damage__ram__bodyDamageMult : float = 0.9;
                                                   collision_damage__ram__transmissionDamageMult : float = 0.1;
                                                   collision_damage__ram__engineDamageMult : float = 0.075)
    let speed = dot(float3(vehicle_net_phys.phys.currentState.velocity), vehicle_transform[0])
    if speed >= collision_damage__ram__speedThreshold
      let victimMass = get_vehicle_collision_victim_mass(eid)
      let vehicleMass = vehicle_net_phys.phys.mass.mass

      let speedAfterCollision = ((vehicleMass - victimMass) * speed) / (victimMass + vehicleMass)
      let kineticEnergyInitial = 0.5 * vehicleMass * square(speed)
      let kineticEnergyFinal = 0.5 * vehicleMass * square(speedAfterCollision)
      let damageToVehicle = max(0.0, (kineticEnergyInitial - kineticEnergyFinal) * collision_damage__ram__kineticEnergyDmgMult)

      deal_damage_to_transmission(offender, offender, damageToVehicle * collision_damage__ram__transmissionDamageMult)
      deal_damage_to_body(offender, offender, damageToVehicle * collision_damage__ram__bodyDamageMult)
      deal_damage_to_engine(offender, offender, damageToVehicle * collision_damage__ram__engineDamageMult)


[es(tag=server, REQUIRE=collision_damage__threshold)]
def collision_damage(evt : CmdCollisionDamage;
                     eid : EntityId)
  let dmg = evt.damage
  if dmg <= 0.f
    return
  let pos = evt.pos
  let offender = evt.offender
  damage_entity(eid, offender, DamageDesc(DamageType.DM_COLLISION, dmg, pos))
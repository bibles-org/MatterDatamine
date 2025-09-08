require ecs
require app
require DngNet
require game.utils.team
require game.events.events
require game.events.events_game
require game.events.vehicle_events
require vehicle
require game.es.trigger_phys_push_common
require game.es.riextra_common
require DagorMath
require DngDm
require DngHuman
require DngPhysObj
require DngShip
require DagorSystem
require PhysObj
require RendInst
require math.base
require daslib/array_boost



[es(tag=server, on_appear)]
def push_around_es(evt : Event;
                   eid : EntityId;
                   transform : float3x4;
                   push_around__radius : float;
                   push_around__speed : float;
                   push_around__distancePower : float;
                   push_around__distancePowerScaleLimits : float2;
                   push_around__pitch : float;
                   push_around__enemyEffectTemplate : das_string const?;
                   push_around__vehicleEnergyScale : float;
                   push_around__vehiclePointOffset : float3;
                   game_effect__attachedTo : EntityId = INVALID_ENTITY_ID;
                   push_around__enemyDamage : float = 0.0;
                   push_around__enemyEffectTemplateTtl : float = 2.0;
                   push_around__immunityAmount : float = 2.0;
                   push_around__hitTagPowerMult : float = 0.5;
                   push_around__aiDistancePowerMult : float = 2.0)
  push_around(transform, push_around__radius, push_around__speed,
              push_around__distancePower, push_around__distancePowerScaleLimits,
              push_around__pitch, push_around__enemyEffectTemplate,
              push_around__vehicleEnergyScale, push_around__vehiclePointOffset,
              push_around__enemyEffectTemplateTtl, push_around__enemyDamage,
              push_around__immunityAmount, push_around__hitTagPowerMult,
              push_around__aiDistancePowerMult,
              (game_effect__attachedTo != INVALID_ENTITY_ID) ? game_effect__attachedTo : eid)
  destroyEntity(eid)


[es(tag=server)]
def trigger_phys_destroy_ri_es(evt : EventFirstContact;
                               eid : EntityId;
                               transform : float3x4;
                               destroy_ri_on_contact__radius : float;
                               destroy_ri_on_contact__damage : float;
                               destroy_ri_on_contact__offset : float3;
                               team : int = int(TEAM_UNASSIGNED))

  let pos = transform[3] + destroy_ri_on_contact__offset
  let dmgNearFar = float2(destroy_ri_on_contact__damage, 0.0)
  damage_ri_in_sphere(pos,
                      destroy_ri_on_contact__radius,
                      dmgNearFar,
                      get_sync_time(), !is_true_net_server(),
                      $(riex_handle : riex_handle_t){ riex_set_offender(riex_handle, eid); },
                      $(riex_handle : riex_handle_t){ return riex_should_damage(eid, team, riex_handle); })


[es(tag=gameClient)]
def first_contact_camera_shake_es(evt : EventFirstContact;
                                  transform : float3x4;
                                  first_contact_push__radius : float;
                                  first_contact_push__cameraShakePower : float = 0.2)
  broadcastEvent(CmdShakeCamera(position = transform[3],
                                  max_distance = first_contact_push__radius,
                                  wish_shake = first_contact_push__cameraShakePower,
                                  smooth = 1.0))


[es]
def human_phys_push_es(evt : CmdPushPhys;
                       eid : EntityId;
                       var human_net_phys : HumanActor)
  let pushVel = evt.vel
  let pushIgnoreAmount = evt.push_immunity
  let pushSpd = length(pushVel)
  var pushDir = pushVel * safeinv(pushSpd)
  let dirToNormalDot = dot(pushDir, human_net_phys.phys.currentState.walkNormal)
  if dirToNormalDot < 0.0
    pushDir = pushDir - 2.0 * dirToNormalDot * human_net_phys.phys.currentState.walkNormal
  let curProj = dot(human_net_phys.phys.currentState.velocity, pushDir)
  if curProj < pushSpd
    let deltaVel = pushDir * (pushSpd - max(curProj, 0.0))

    if get_DAECS_EXTENSIVE_CHECKS() != 0 && is_nan(deltaVel)
      logerr("[PUSH] Delta velocity is NaN!
deltaVel={deltaVel}
pushDir={pushDir}
pushSpd={pushSpd}
curProj={curProj}")
      return

    human_net_phys.phys.currentState.velocity += deltaVel
    human_net_phys.phys.currentState.isInAirHistory = uint8(int(human_net_phys.phys.currentState.isInAirHistory) | 15)
    human_net_phys.phys.currentState.deltaVelIgnoreAmount += pushIgnoreAmount
    let knockBackTimer = 0.6 // TODO: move value to human_net_phys.phys and add something like phys.knockback() function which do just this?
    human_net_phys.phys.currentState.knockBackTimer = knockBackTimer
    human_net_phys.phys |> human_phys_wakeUp()
    human_net_phys.phys |> human_phys_rescheduleAuthorityApprovedSend()
    sendEvent(eid, CmdDetachAttachedGun())


[es]
def physobj_push_es(evt : CmdPushPhys;
                    var phys_obj_net_phys : PhysObjActor)
  let pushVel = evt.vel
  let pushSpd = length(pushVel)
  let pushDir = pushVel * safeinv(pushSpd)
  let curProj = dot(phys_obj_net_phys.phys.currentState.velocity, pushDir)
  phys_obj_net_phys.phys.currentState.velocity += pushDir * (pushSpd - max(curProj, 0.0))
  phys_obj_net_phys.phys |> wakeUp()
  phys_obj_net_phys.phys |> phys_obj_rescheduleAuthorityApprovedSend()


[es]
def vehicle_phys_push_es(evt : CmdVehiclePushPhys;
                         var vehicle_net_phys : VehiclePhysActor)
  if !empty(vehicle_net_phys.phys.explosionDamageImpulses)
    return

  let energyScaledDir = evt.energyScaledDir
  let arm = evt.arm
  let duration = evt.duration
  let mass = vehicle_net_phys.phys.getMass
  let impulse = energyScaledDir * sqrt(mass)
  let endTime = double(get_sync_time() + duration)

  vehicle_net_phys.phys.explosionDamageImpulses |> emplace(
    VehiclePhysExplosionDamageImpulse(endTime = endTime,
                                        impulse = impulse,
                                        arm = arm))
  vehicle_net_phys.phys |> wakeUp()


[es]
def ship_phys_push_es(evt : CmdVehiclePushPhys;
                      transform : float3x4;
                      var ship_net_phys : ShipActor;
                      var auto_anchor__nextAnchorTime : float?)
  if !empty(ship_net_phys.phys.explosionDamageImpulses)
    return

  let energyScaledDir = evt.energyScaledDir
  let arm = evt.arm
  let duration = evt.duration
  ship_net_phys.phys |> ship_phys_set_anchor(false)
  let itm = inverse(transform)
  let mass = ship_net_phys.phys.getMass
  let dir = rotate(itm, (energyScaledDir * sqrt(mass)))
  let impulse = dir * ship_net_phys.phys.timeStep
  let endTime = double(get_sync_time() + duration)

  ship_net_phys.phys.explosionDamageImpulses |> emplace(
    ShipPhysExplosionDamageImpulse(endTime = endTime,
                                     impulse = impulse,
                                     arm = (itm * arm)))
  ship_net_phys.phys |> ship_phys_wake_up()

  if auto_anchor__nextAnchorTime != null
    *auto_anchor__nextAnchorTime = 0.0
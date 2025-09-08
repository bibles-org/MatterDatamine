require ecs
require ecs.common
require DagorRandom
require DagorMath
require DagorSystem
require math.base
require math.random
require DngHuman
require DngDm
require DngNet
require HumanPhys
require game.events.inventory_events
require game.events.events_game
require game.events.events_active_matter


def is_valid_weapon(human_weap__currentGunSlot : int)
  return human_weap__currentGunSlot >= 0 && human_weap__currentGunSlot < int(HUWeaponSlots.EWS_MELEE)

[es(tag=server, no_order)]
def metal_heat_update(act : ParallelUpdateFrameDelayed; eid, game_effect__attachedTo : EntityId;
                      metal_heat__punchChance, metal_heat__shootChance : float2;
                      metal_heat__dropGunChance, metal_heat__damageChance : float2;
                      metal_heat__burningChance, metal_heat__damagePower : float2;
                      metal_heat__punchTime, metal_heat__punchStrength : float2;
                      metal_heat__affectProgressCooldownSpeed : float;
                      anomaly_effect__ownerAnomalyEid : EntityId;
                      metal_heat__nextUpdateInterval = 0.05;
                      var metal_heat__nextUpdateAt : float&;
                      var metal_heat__affectProgress : float&;
                      var metal_heat__reqShoot, metal_heat__reqDropGun : bool&)
  if act.curTime < metal_heat__nextUpdateAt
    return
  metal_heat__nextUpdateAt = act.curTime + metal_heat__nextUpdateInterval
  metal_heat__affectProgress = saturate(metal_heat__affectProgress - act.dt * metal_heat__affectProgressCooldownSpeed)
  let found = query(anomaly_effect__ownerAnomalyEid) <| $ [es] (box_anomaly__targetEids : EidList; metal_heat__affectPower : float)
    if has_value(box_anomaly__targetEids, game_effect__attachedTo)
      metal_heat__affectProgress = metal_heat__affectPower
  if !found
    logerr("{eid}: {getEntityTemplateName(eid)} owner {anomaly_effect__ownerAnomalyEid} without metal_heat__affectPower/box_anomaly__targetEids component")
  if metal_heat__affectProgress <= 0.
    return
  if gfrnd() < lerp(metal_heat__burningChance.x, metal_heat__burningChance.y, metal_heat__affectProgress)
    query(game_effect__attachedTo) <| $ [es] (burning__maxForce : float; var burning__isBurning : bool&;
                                              var burning__offender : EntityId&; var burning__force : float&)
      burning__isBurning = true
      burning__force = burning__maxForce
      burning__offender = eid
  query(game_effect__attachedTo) <| $ [es] (transform : float3x4; human_weap__currentGunSlot : int; var human_aim_punch__queuedEvents : Point3List)
    if gfrnd() < lerp(metal_heat__damageChance.x, metal_heat__damageChance.y, metal_heat__affectProgress)
      let damage = rnd_float(metal_heat__damagePower)
      let ddesc = DamageDesc(DamageType.DM_FIRE, damage, transform[3])
      damage_entity(game_effect__attachedTo, eid, ddesc)

    if !is_valid_weapon(human_weap__currentGunSlot)
      return
    if gfrnd() < lerp(metal_heat__punchChance.x, metal_heat__punchChance.y, metal_heat__affectProgress)
      let time = lerp(metal_heat__punchTime.x, metal_heat__punchTime.y, metal_heat__affectProgress)

      let dir = TWOPI * gfrnd()
      let strength = lerp(metal_heat__punchStrength.x, metal_heat__punchStrength.y, metal_heat__affectProgress)
      human_aim_punch__queuedEvents |> push(float3(act.curTime + time, cos(dir) * strength, sin(dir) * strength))
      metal_heat__reqShoot = gfrnd() < lerp(metal_heat__shootChance.x, metal_heat__shootChance.y, metal_heat__affectProgress)
      metal_heat__reqDropGun = gfrnd() < lerp(metal_heat__dropGunChance.x, metal_heat__dropGunChance.y, metal_heat__affectProgress)


[es(tag=gameClient, no_order)]
def metal_heat_client_update(act : ParallelUpdateFrameDelayed; game_effect__attachedTo : EntityId;
                             var metal_heat__reqShoot, metal_heat__reqDropGun : bool&)
  if metal_heat__reqShoot || metal_heat__reqDropGun
    query(game_effect__attachedTo) <| $ [es] (human_weap__currentGunSlot : int; var human_net_phys : HumanActor)
      human_net_phys.phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_SHOOT, metal_heat__reqShoot)
      metal_heat__reqShoot = false
      if metal_heat__reqDropGun && is_valid_weapon(human_weap__currentGunSlot)
        send_net_event(game_effect__attachedTo, CmdMoveWeaponToInventory(
          slotId = human_weap__currentGunSlot, toInventoryEid = INVALID_ENTITY_ID))
        metal_heat__reqDropGun = false


[es(tag=server, no_order)]
def metal_heat_trap_update(act : ParallelUpdateFrameDelayed;
                           box_anomaly__targetEids : EidList;
                           metal_heat__affectCooldownSpeed, metal_heat__affectBoostSpeed : float;
                           var metal_heat__affectPower : float&)
  if length(box_anomaly__targetEids) == 0
    metal_heat__affectPower = saturate(metal_heat__affectPower - act.dt * metal_heat__affectCooldownSpeed)
  else
    metal_heat__affectPower = saturate(metal_heat__affectPower + act.dt * metal_heat__affectBoostSpeed)
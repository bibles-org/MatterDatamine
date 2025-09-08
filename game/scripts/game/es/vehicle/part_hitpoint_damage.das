require ecs
require math.base
require dm
require DngDm
require game.es.vehicle.vehicle_seats_common
require game.events.vehicle_events
require game.utils.team
require DagorMath
require DagorSystem
require game.events.events_game


def transfer_damage_to_hitpoints(part_id : int; damage : float; damage_type : int; offender : EntityId; eid : EntityId; damage_model : DamageModel;
                                 hit_pos : float3 = float3(); hit_dir : float3 = float3(); shell_id : int = -1; gun_props_id : int = -1)
  let dd = DamageDesc(DamageType(damage_type), damage, hit_pos, hit_dir, float3(), shell_id, gun_props_id, get_collision_node_id(damage_model.dmData, part_id), 0.0)
  apply_damage(eid, offender, dd)


[es(tag=server, REQUIRE=hitpoints)]
def transfer_damage_to_hitpoints_on_part_damage(evt : EventOnPartDamaged;
                                                eid : EntityId;
                                                damage_model : DamageModel;
                                                isInVehicleHidden : bool;
                                                team : int = TEAM_UNASSIGNED)
  if isInVehicleHidden
    return
  let partId = evt.partId
  let damage = evt.damage
  let damageType = evt.damageTypeId
  assume hitData = evt.hitData
  let offenderTeam = get_int(hitData.offender, "team") ?? TEAM_UNASSIGNED
  if !is_friendly_fire_allowed() && hitData.offender != eid && is_teams_friendly(team, offenderTeam)
    return

  transfer_damage_to_hitpoints(partId, damage, damageType, hitData.offender, eid, damage_model, hitData.pos, hitData.dir, int(hitData.shellId), int(hitData.gunPropsId))

[es(tag=server, REQUIRE=hitpoints)]
def transfer_damage_to_hitpoints_on_volumetric_damage(evt : EventOnVolumetricDamage;
                                                      eid : EntityId;
                                                      damage_model : DamageModel;
                                                      isInVehicleHidden : bool;
                                                      team : int = TEAM_UNASSIGNED)
  if isInVehicleHidden
    return

  let offenderTeam = get_int(evt.offender, "team") ?? TEAM_UNASSIGNED
  if !is_friendly_fire_allowed() && evt.offender != eid && is_teams_friendly(team, offenderTeam)
    return

  for item in evt.damagedParts
    let part = get_ecs_object(item)
    if part == null
      logerr("Received EventOnVolumetricDamage with null in damagedParts")
      continue
    let partId = get_int(part, "partId")
    let damage = get_float(part, "damage")
    if partId == null || damage == null
      logerr("Received EventOnVolumetricDamage with broken object in damagedParts (partId: {partId}, damage: {damage})")
      continue

    transfer_damage_to_hitpoints(*partId, *damage, evt.damageTypeId, evt.offender, eid, damage_model)
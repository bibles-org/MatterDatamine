require ecs
require app
require DngDm
require DngNet
require game.utils.team
require game.events.events
require game.events.events_game
require danetlibs.dm.dm_events
require game.es.hit_result_common
require game.es.vehicle.vehicle_seats_common
require game.es.entity_mods_common
require game.es.hitpoints_damage_common


[es(tag=server, on_appear)]
def cellular_hitpoints_init(evt : Event;
                            cellular_hitpoints__maxCellHp : float;
                            var cellular_hitpoints__currentCellHp : float&)
  if cellular_hitpoints__currentCellHp <= 0.0
    cellular_hitpoints__currentCellHp = cellular_hitpoints__maxCellHp


[es]
def cellular_hitpoints_apply_damage(evt : CmdApplyDamage;
                                    eid : EntityId;
                                    cellular_hitpoints__maxCellHp : float;
                                    cellular_hitpoints__maxCells : int;
                                    var cellular_hitpoints__damagedCells : int&;
                                    var cellular_hitpoints__currentCellHp : float&;
                                    var killer : EntityId?;
                                    possessedByPlr aka victim_possessedByPlr = INVALID_ENTITY_ID;
                                    hitpoints__dmgMult : float = 1.;
                                    team : int = TEAM_UNASSIGNED;
                                    entity_mod_values : Object const?)
  if evt.deltaHp < 0.
    return

  let victim = eid
  var offender = evt.offender
  let deltaHp = calculate_modified_damage_delta(evt, victim == evt.offender ? 1.0 : hitpoints__dmgMult, entity_mod_values)

  let wasDead = cellular_hitpoints__damagedCells == cellular_hitpoints__maxCells
  cellular_hitpoints__currentCellHp -= deltaHp
  if cellular_hitpoints__currentCellHp <= 0.0
    cellular_hitpoints__damagedCells = min(cellular_hitpoints__damagedCells + 1, cellular_hitpoints__maxCells)
    cellular_hitpoints__currentCellHp = cellular_hitpoints__maxCellHp

  var hitr : HitResult
  if wasDead
    hitr = HitResult.HIT_RES_NONE
  elif cellular_hitpoints__damagedCells != cellular_hitpoints__maxCells
    hitr = HitResult.HIT_RES_NORMAL
  else
    hitr = HitResult.HIT_RES_KILLED

    if killer != null
      *killer = offender

    var offenderPlayer = INVALID_ENTITY_ID
    query(offender) <| $ [es] (possessedByPlr : EntityId)
      offenderPlayer = possessedByPlr
    if offenderPlayer == INVALID_ENTITY_ID
      let maxInertialKillTime = 4.
      let driver = get_last_vehicle_driver_possessed_by_player(offender, maxInertialKillTime)
      if driver != INVALID_ENTITY_ID
        offender = driver
      query(offender) <| $ [es] (possessedByPlr : EntityId)
        offenderPlayer = possessedByPlr

    var offenderTeam = TEAM_UNASSIGNED
    query(offender) <| $ [es] (team aka hero_team = TEAM_UNASSIGNED)
      offenderTeam = hero_team
      if offenderTeam == TEAM_UNASSIGNED
        query(offenderPlayer) <| $ [es] (team aka player_team = TEAM_UNASSIGNED)
          offenderTeam = player_team

    send_net_event(eid, EventEntityDied(
      victim = eid, offender = offender,
      damageType = int(evt.damageType), gunPropsId = int(evt.gunPropsId), shellId = int(evt.shellId),
      collNodeId = int(evt.collNodeId), victimTeam = team, offenderTeam = offenderTeam))
    print("[cellular_hitpoints] cellular_hitpoints_apply_damage: entity died, victim={eid}, offender={offender}")
    broadcast_net_event(EventAnyEntityDied(
      victim = eid, offender = offender, offenderPlayer = offenderPlayer,
      victimPlayer = victim_possessedByPlr, damageType = int(evt.damageType), gunPropsId = int(evt.gunPropsId), shellId = int(evt.shellId),
      collNodeId = int(evt.collNodeId), victimTeam = team, offenderTeam = offenderTeam))

  sendEvent(eid, EventOnDamaged(
    offender = offender,
    damageType = evt.damageType,
    deltaHp = evt.deltaHp,
    hitPos = evt.hitPos,
    hitDir = evt.hitDir
  ))

  broadcastEvent(EventOnEntityHit(
    victim = victim,
    offender = offender,
    hitResult = int(hitr),
    damageType = evt.damageType,
    shellId = evt.shellId,
    gunPropsId = evt.gunPropsId,
    actionPropsId = evt.actionPropsId,
    collNodeId = evt.collNodeId,
    deltaHp = evt.deltaHp,
    blockingDeltaHp = evt.blockingDeltaHp,
    stoppingPower = evt.stoppingPower,
    hitPos = evt.hitPos,
    hitDir = evt.hitDir,
    hitNorm = evt.hitNorm,
    dmgMult = evt.dmgMult,
    armorMult = evt.armorMult,
    armorPenetration = evt.armorPenetration,
    shatterCount = evt.shatterCount
  ))


[es(tag=server, REQUIRE=cellular_hitpoints__maxCells)]
def cellular_hitpoints_kill(evt : CmdKill;
                            eid : EntityId;
                            transform : float3x4;
                            cellular_hitpoints__maxCellHp : float;
                            cellular_hitpoints__maxCells : int;
                            var cellular_hitpoints__damagedCells : int&)
  cellular_hitpoints__damagedCells = cellular_hitpoints__maxCells - 1
  let deltaHp = cellular_hitpoints__maxCellHp + evt.deathHpDamage
  let damageDesc = DamageDesc(DamageType(int(evt.damageType)), deltaHp, transform[3])
  apply_damage(eid, evt.offender, damageDesc)

require ecs
require ecs.safe
require ecs.common
require game.es.hit_result_common
require CollRes
require game.events.events
require math.base
require DagorMath
require DagorRandom
require DngDm
require game.es.damage_systems.damage_model_common
require game.events.events_active_matter
require game.events.events_game
require danetlibs.dm.dm_events
require app
require game.utils.team
require game.es.vehicle.vehicle_seats_common
require game.es.pain_common
require game.es.entity_mods_common
require game.es.hitpoints_damage_common
require game.es.concussion_common
require game.es.confusion_common
require strings


[es(tag=server, on_appear)]
def human_damage_model_init(evt : Event;
                            collres : CollisionResource;
                            var human_damage_model__parts : Object;
                            var human_damage_model__sumMaxHpAllBodyParts : float&)
  for part in human_damage_model__parts
    var obj = getRW_ecs_object(part.value)
    if obj == null
      continue
    let list = get_ecs_StringList(obj, "list")
    var nodeIds = getRW_ecs_IntList(obj, "nodeIds")
    if list == null || nodeIds == null
      continue
    for nodeName in *list
      let idx = collres_get_node_index_by_name(collres, string(nodeName))
      push(*nodeIds, idx)
    human_damage_model__sumMaxHpAllBodyParts += obj?.maxHp ?? 0f


[es(tag=server)]
def damage_model_on_entity_hit(evt : EventOnEntityHit)
  query(evt.victim) <| $ [es(REQUIRE_NOT=(deadEntity, hitpoints__hp))] (entity_mod_values : Object; var human_damage_model__parts : Object)
    var totalParts : array<BodyPart>
    var partsForDamage : array<BodyPart>
    make_array_of_body_parts(human_damage_model__parts, totalParts)
    // If a specific part of the body should receive damage (projectile, melee, etc.), we look only for it
    let isSpecificNode = evt.collNodeId != -1
    if isSpecificNode
      for part in totalParts
        if has_value(*part.nodesIds, evt.collNodeId)
          partsForDamage |> emplace(part)
          break
    else
      reserve(partsForDamage, MAX_BODY_PARTS)
      for part in totalParts
        if evt.damageType == int(DamageType.DM_COLLISION)
          if part.collisionImpact
            partsForDamage |> emplace(part)
        elif evt.damageType == int(DamageType.DM_EXPLOSION)
          if part.explosionImpact
            partsForDamage |> emplace(part)
        elif evt.damageType == int(DamageType.DM_HOLD_BREATH)
          if part.breathImpact
            partsForDamage |> emplace(part)
        elif evt.damageType == int(DamageType.DM_BARBWIRE) || evt.damageType == int(DamageType.DM_GAS)
          if part.barbwireImpact
            partsForDamage |> emplace(part)
        else
          partsForDamage |> emplace(part)
    human_damage_model_damage_parts(evt.victim, evt.deltaHp, evt.damageType, entity_mod_values, human_damage_model__parts, partsForDamage)


[es(tag=server, REQUIRE_NOT=hitpoints__hp)]
def damage_model_apply_damage(evt : CmdApplyDamage;
                              eid : EntityId;
                              isAlive : bool;
                              var death_desc__damageType : int&;
                              var death_desc__gunPropsId : int&;
                              var death_desc__shellId : int&;
                              var death_desc__collNodeId : int&;
                              var death_desc__victimTeam : int&;
                              var death_desc__offenderTeam : int&;
                              var hitpoints__lastOffender : EntityId&;
                              var hitpoints__lastOffenderPlayer : EntityId&;
                              var hitpoints__lastVictimPlayer : EntityId&;
                              var hitpoints__lastHitNodeId : int&;
                              var hitpoints__lastOffenderTime : float&;
                              var hitpoints__timeFromLastDamage : float?;
                              hitpoints__clearOffenderTimer : float = 30.;
                              human_damage_model__dmgMult : float = 1.;
                              team : int = TEAM_UNASSIGNED;
                              heroForPlayer : Tag const?;
                              playerIsBot : Tag const?;
                              entity_mod_values : Object const?)

  if evt.deltaHp < 0.
    return

  let victim = eid
  var offender = evt.offender

  var offenderPlayer = get_Eid(offender, "possessedByPlr") ?? INVALID_ENTITY_ID
  var lastOffenderTeam = death_desc__offenderTeam
  let offenderTeam = get_int(offender, "team") ?? get_int(offenderPlayer, "team") ?? TEAM_UNASSIGNED
  if !offenderPlayer
    let maxInertialKillTime = 4.
    let driver = get_last_vehicle_driver_possessed_by_player(offender, maxInertialKillTime)
    if !!driver
      offender = driver
      offenderPlayer = get_Eid(offender, "possessedByPlr") ?? INVALID_ENTITY_ID

  let deltaHp = calculate_modified_damage_delta(evt, human_damage_model__dmgMult, entity_mod_values)

  let hitr = isAlive ? HitResult.HIT_RES_NORMAL : HitResult.HIT_RES_NONE

  if heroForPlayer != null && playerIsBot == null
    query(eid) <| $ [es] (transform : float3x4; human_damage_model__sumMaxHpAllBodyParts, human_damage_model__sumHpAllBodyParts : float)
      var dmgtype : DamageType
      for dtype in each_enum(dmgtype)
        if int(dtype) == evt.damageType
          dmgtype = dtype
          break
      let logStr = build_string() <| $(str)
        str |> write("[Apply Damage]")
        str |> write("\toffender:<{offender}>({getEntityTemplateName(offender)}) player<{offenderPlayer}>\n")
        str |> write("\t<{eid}> HP: {human_damage_model__sumHpAllBodyParts} / {human_damage_model__sumMaxHpAllBodyParts}, deltaHp: {deltaHp} ({evt.deltaHp})\n")
        str |> write("\tdamageType:{dmgtype}({evt.damageType}), collNodeId:{evt.collNodeId}, gunPropsId:{evt.gunPropsId}, shellId:{evt.shellId}\n")
        str |> write("\tpos:[{transform[3]}] hitPos:[{evt.hitPos}]\n")
      print(logStr)

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
    deltaHp = deltaHp,
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

  let isLastOffenderPlayer = hitpoints__lastOffenderPlayer != INVALID_ENTITY_ID && hitpoints__lastOffender != victim
  let isNewOffenderPlayer = !!offenderPlayer && offender != victim
  let isLastOffenderTimeIsUp = (hitpoints__lastOffenderTime < 0. ||
                                get_sync_time() - hitpoints__lastOffenderTime > hitpoints__clearOffenderTimer)

  if hitpoints__timeFromLastDamage != null
    *hitpoints__timeFromLastDamage = 0.
  if !isLastOffenderPlayer || isNewOffenderPlayer || isLastOffenderTimeIsUp
    hitpoints__lastOffenderTime = get_sync_time()
    hitpoints__lastOffender = offender
    lastOffenderTeam = offenderTeam

    let victimPlayerEid = get_Eid(victim, "possessedByPlr") ?? INVALID_ENTITY_ID
    if !!victimPlayerEid
      hitpoints__lastVictimPlayer = victimPlayerEid

    hitpoints__lastOffenderPlayer = offenderPlayer
  hitpoints__lastHitNodeId = int(evt.collNodeId)

  death_desc__damageType = int(evt.damageType)
  death_desc__gunPropsId = int(evt.gunPropsId)
  death_desc__shellId = int(evt.shellId)
  death_desc__collNodeId = int(evt.collNodeId)
  death_desc__victimTeam = team
  death_desc__offenderTeam = lastOffenderTeam


[es(tag=server, on_appear, track=human_damage_model__parts, after=human_damage_model_init)]
def damage_model_calculate_hp_of_all_body_parts(evt : Event;
                                                human_damage_model__parts : Object;
                                                var human_damage_model__sumHpAllBodyParts : float&)
  human_damage_model__sumHpAllBodyParts = human_damage_model_get_total_hp(human_damage_model__parts)


[es(REQUIRE=human_damage_model__parts)]
def damage_model_hp_death_es(evt : EventEntityDied;
                             var isAlive : bool&)
  isAlive = false


[es(tag=server, on_disappear, on_event=EventEntityDied)]
def destroy_damage_model_effects_on_hero_died(evt : Event;
                                              eid aka human_eid : EntityId)
  query() <| $ [es(REQUIRE=damageModelEffect)] (eid, game_effect__attachedTo : EntityId)
    if game_effect__attachedTo == human_eid
      destroyEntity(eid)


[es(tag=server, on_disappear, REQUIRE=damageModelEffect)]
def stop_damage_model_effect_on_disappearing(evt : Event;
                                             eid : EntityId;
                                             game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (@shared_comp human_damage_model__effects : Array;
                                            human_damage_model__parts : Object)
    var effects : array<BodyPartEffect>
    make_array_of_effects(human_damage_model__effects, human_damage_model__parts, effects)
    let templateName = getEntityTemplateName(eid)
    for effect in effects
      if effect.effectTemplate == templateName
        human_damage_model_stop_effect(game_effect__attachedTo, effect, false)
        return


[es(tag=server, on_appear, REQUIRE=human_damage_model__parts)]
def hitpoints_percent_on_appear(evt : Event;
                                eid : EntityId;
                                hitpoints_percent_on_appear : float)
  human_damage_model_set_hp_in_percent(eid, hitpoints_percent_on_appear)


[es(tag=server, on_appear, REQUIRE=infinite_ammo_on_appear)]
def infinite_ammo_on_appear(evt : Event;
                            eid : EntityId)
  createEntity("infinite_ammo_effect") <| $(init)
    set(init, "game_effect__attachedTo", eid)


[es]
def make_pain_on_damage(evt : EventDamageModelApplyDamage;
                        eid : EntityId;
                        human_damage_model__painDmgMult : float)
  let progress = saturate(evt.notBlockedDamage * human_damage_model__painDmgMult)
  add_pain_progress(eid, progress)


[es(tag=server, REQUIRE=hitpoints)]
def hitpoints_damage_model_kill_es(evt : CmdKill;
                                   eid : EntityId;
                                   transform : float3x4;
                                   human_damage_model__sumHpAllBodyParts : float)
  let deltaHp = human_damage_model__sumHpAllBodyParts + evt.deathHpDamage
  let damageDesc = DamageDesc(DamageType(int(evt.damageType)), deltaHp, transform[3])
  apply_damage(eid, evt.offender, damageDesc)


[es(tag=server)]
def human_damage_model_melee_attack_to_hands_aim_punch(evt : CmdApplyDamage;
                                                       human_damage_model__parts : Object;
                                                       var human_aim_punch__queuedEvents : Point3List;
                                                       var human_aim_punch__curPower : float&;
                                                       var human_aim_punch__lastPunchTime : float&)
  query(evt.offender) <| $ [es] (melee_attack_to_hands_aim_punch__strength : float)
    if evt.damageType == int(DamageType.DM_MELEE) || evt.damageType == int(DamageType.DM_BACKSTAB)
      assume strength = melee_attack_to_hands_aim_punch__strength

      var isHand = false

      for part in [human_damage_model__parts.left_hand ?as Object,
                   human_damage_model__parts.right_hand ?as Object]
        if part != null
          let nodeIds = get_ecs_IntList(part, "nodeIds")
          if nodeIds != null && *nodeIds |> find_index(evt.collNodeId) != -1
            isHand = true
            break

      if isHand
        let dir = TWOPI * gfrnd()
        let punchTime = get_sync_time() + 1e-1
        human_aim_punch__queuedEvents |> clear()
        human_aim_punch__queuedEvents |> push(float3(punchTime, cos(dir) * strength, sin(dir) * strength))
        human_aim_punch__curPower = max(human_aim_punch__curPower, strength)
        human_aim_punch__lastPunchTime = punchTime


[es(tag=server)]
def human_damage_model_melee_attack_to_head_concussion(evt : CmdApplyDamage;
                                                       eid aka victim_eid : EntityId;
                                                       human_damage_model__parts : Object)
  query(evt.offender) <| $ [es] (melee_attack_to_head_concussion__template : string;
                                 melee_attack_to_head_confusion__duration : float = 0.0;
                                 melee_attack_to_head_confusion__intensity : float = 1.0;
                                 melee_attack_to_head_confusion__speed : float = 0.2;
                                 melee_attack_to_head__extraDamage : float = 0.0)
    if evt.damageType == int(DamageType.DM_MELEE) || evt.damageType == int(DamageType.DM_BACKSTAB)

      let head = (human_damage_model__parts.head ?as Object)
      if head != null
        let nodeIds = get_ecs_IntList(head, "nodeIds")
        if nodeIds != null && *nodeIds |> find_index(evt.collNodeId) != -1
          enable_concussion_affect(victim_eid, melee_attack_to_head_concussion__template)

          if melee_attack_to_head_confusion__duration > 0.0
            enable_confusion_affect(victim_eid, melee_attack_to_head_confusion__duration,
                                                melee_attack_to_head_confusion__intensity,
                                                melee_attack_to_head_confusion__speed,
                                                false) // We can create entity async only in MT

          if melee_attack_to_head__extraDamage > 0.0
            let extraDamage = melee_attack_to_head__extraDamage * evt.deltaHp
            let dmType = DamageType DM_UNKNOWN // To avoid recursion
            let dmDesc = DamageDesc(dmType, extraDamage, evt.hitPos, evt.hitDir, float3(), evt.shellId, evt.gunPropsId)
            damage_entity(victim_eid, evt.offender, dmDesc)
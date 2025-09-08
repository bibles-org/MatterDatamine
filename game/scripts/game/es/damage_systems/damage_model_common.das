module damage_model_common shared

require ecs
require ecs.safe
require DagorSystem
require game.utils.team
require game.events.events_game
require game.events.events_active_matter
require DngNet
require DngDm
require DagorRandom
require game.es.entity_mods_common


let MAX_BODY_PARTS = 6


struct BodyPartEffectPart
  chance      : float
  minHp       : float
  hp          : float
  whenInjured : bool
  isInjured   : bool


struct BodyPartEffect
  effectTemplate       : string
  isSequential         : bool
  bodyParts            : array<BodyPartEffectPart>


struct BodyPart
  id                     : string
  hp                     : float?
  maxHp                  : float
  isInjured              : bool?
  removeInjuryHp         : float
  name                   : string
  nodesIds               : IntList const?
  breathImpact           : bool
  explosionImpact        : bool
  collisionImpact        : bool
  barbwireImpact         : bool
  distributionDamageMult : float
  adjacentPartsIds       : StringList const?
  adjacentParts          : array<Object?>
  protection             : FloatList const?


struct BodyPartV2
  name : string
  nodeIds : array<int>
  barbwireImpact : bool
  hp : float
  maxHp : float


def human_damage_model_start_effect(human_eid : EntityId; effect : BodyPartEffect)
  let templ = getTemplateByName(effect.effectTemplate)
  if templ == null
    logerr("failed to determine the effect <{effect.effectTemplate}> of the dead body part")
    return
  query(human_eid) <| $ [es] (var human_damage_model__appliedEffects : StringList)
    // if we already have this effect - do not start it again
    if has_value(human_damage_model__appliedEffects, effect.effectTemplate)
      return
    push(human_damage_model__appliedEffects, effect.effectTemplate)
    createEntity(effect.effectTemplate) <| $(var init)
      set(init, "game_effect__attachedTo", human_eid)


def human_damage_model_stop_effect(human_eid : EntityId;
                                   effect : BodyPartEffect;
                                   destroy_entity = true)
  query(human_eid) <| $ [es] (var human_damage_model__appliedEffects : StringList)
    // remove an effect from the list of active effects
    let index = find_index_if(each(human_damage_model__appliedEffects)) <| $(value)
      return string(value) == effect.effectTemplate
    if index != -1
      erase(human_damage_model__appliedEffects, index)
    if destroy_entity
      find_query() <| $ [es(REQUIRE=damageModelEffect)] (eid, game_effect__attachedTo : EntityId)
        if game_effect__attachedTo == human_eid
          if getEntityTemplateName(eid) == effect.effectTemplate
            destroyEntity(eid)
            return true
        return false


def make_object_of_body_part(part_id : string;
                             var child : ChildComponent?;
                             var all_parts : Object) : BodyPart
  var obj = getRW_ecs_object(child)
  if obj == null
    logerr("failed to get the object of the body part")
    return <- BodyPart()
  return <- make_object_of_body_part(part_id, *obj, all_parts)


def make_object_of_body_part(part_id : string;
                             var obj : Object;
                             var all_parts : Object) : BodyPart
  let nameStrPtr = get_ecs_string(obj, "name")
  let nameStr = nameStrPtr != null ? string(*nameStrPtr) : ""
  var hpPtr = getRW_float(obj, "hp")
  if hpPtr == null
    logerr("failed to get hp of the body part <{obj.name}>")
  var isInjuredPtr = getRW_bool(obj, "isInjured")
  if isInjuredPtr == null
    logerr("failed to get isInjured of the body part <{obj.name}>")
  var nodeIdsPtr = getRW_ecs_IntList(obj, "nodeIds")
  if nodeIdsPtr == null
    logerr("failed to get nodeIds of the body part <{obj.name}>")
  var adjacentPartsArray : array<Object?>
  let adjacentParts = get_ecs_StringList(obj, "adjacentParts")
  if adjacentParts != null
    for adjacentPart in *adjacentParts
      var adjacentPartObj = getRW_ecs_object(all_parts, string(adjacentPart))
      if adjacentPartObj == null
        logerr("failed to find the adjacent part <{adjacentPart}> for the body part <{nameStr}>")
        continue
      adjacentPartsArray |> push(adjacentPartObj)
  let protectionPtr = getRW_ecs_FloatList(obj, "protection")
  return <- BodyPart(
    id = part_id,
    hp = hpPtr,
    isInjured = isInjuredPtr,
    removeInjuryHp = obj.removeInjuryHp ?? 0f,
    maxHp = obj.maxHp ?? 0f,
    nodesIds = nodeIdsPtr,
    name = nameStr,
    breathImpact = obj.breathImpact ?? true,
    explosionImpact = obj.explosionImpact ?? true,
    collisionImpact = obj.collisionImpact ?? true,
    barbwireImpact = obj.barbwireImpact ?? true,
    distributionDamageMult = obj.distributionDamageMult ?? 1f,
    adjacentPartsIds = adjacentParts,
    adjacentParts <- adjacentPartsArray,
    protection = protectionPtr
  )


def make_object_of_body_part(obj : Object) : BodyPartV2
  var nodeIds : array<int>
  let nodeIdsList = get_ecs_IntList(obj, "nodeIds")
  if nodeIdsList != null
    for nodeId in *nodeIdsList
      nodeIds |> push(nodeId)
  return <- BodyPartV2(
    name = obj.name ?? "",
    nodeIds <- nodeIds,
    barbwireImpact = obj.barbwireImpact ?? true,
    hp = obj.hp ?? 0.0,
    maxHp = obj.maxHp ?? 0.0
  )


def make_array_of_body_parts(var parts_obj : Object; var out : array<BodyPart>)
  reserve(out, MAX_BODY_PARTS)
  for part in parts_obj
    var obj = getRW_ecs_object(part.value)
    if obj == null
      continue
    emplace(out, make_object_of_body_part(part.key, *obj, parts_obj))


def for_each_part_in_damage_model(damage_model : Object; processing_block : block<(BodyPartV2) : bool>)
  for damagePart in damage_model
    let damagePartDataObject = get_ecs_object(damagePart.value)
    if damagePartDataObject == null
      continue
    if !processing_block |> invoke(make_object_of_body_part(*damagePartDataObject))
      break


def human_damage_model_set_hp_in_percent(hero_eid : EntityId; percent : float)
  query(hero_eid) <| $ [es] (human_damage_model__parts : Object)
    for_each_part_in_damage_model(human_damage_model__parts) <| $(bodypart : BodyPartV2)
      let newHp = bodypart.maxHp * percent
      human_damage_model_set_part_hp(hero_eid, bodypart.name, newHp)
      return true


def human_damage_model_get_total_hp(damage_model : Object) : float
  var totalHp = 0.0
  for_each_part_in_damage_model(damage_model) <| $(bodypart : BodyPartV2)
    totalHp += max(0f, bodypart.hp)
    return true
  return totalHp


def human_damage_model_add_part_hp(hero_eid : EntityId; bodypart_name : string; hitpoints : float)
  query(hero_eid) <| $ [es] (var human_damage_model__parts : Object)
    var bodypartObj = human_damage_model__parts[bodypart_name] ?as Object
    if bodypartObj == null
      return
    let hp = max(0.0, (*bodypartObj).hp ?? 0.0)
    let maxHp = (*bodypartObj).maxHp ?? 0.0
    let removeInjuryHp = (*bodypartObj).removeInjuryHp ?? 0.0
    let newHp = min(hp + hitpoints, maxHp)
    *bodypartObj |> set("hp", newHp)
    if newHp <= 0.0
      *bodypartObj |> set("isInjured", true)
    elif newHp >= removeInjuryHp
      *bodypartObj |> set("isInjured", false)

  human_damage_model_recalc_effects(hero_eid, true)


def human_damage_model_set_part_hp(hero_eid : EntityId;
                                   bodypart_name : string;
                                   hitpoints : float)
  query(hero_eid) <| $ [es] (var human_damage_model__parts : Object)
    var bodypartObj = human_damage_model__parts[bodypart_name] ?as Object
    if bodypartObj == null
      return
    let removeInjuryHp = (*bodypartObj).removeInjuryHp ?? 0.0
    *bodypartObj |> set("hp", hitpoints)
    if hitpoints <= 0.0
      *bodypartObj |> set("isInjured", true)
    elif hitpoints >= removeInjuryHp
      *bodypartObj |> set("isInjured", false)

  human_damage_model_recalc_effects(hero_eid)


def human_damage_model_set_part_hp(hero_eid : EntityId; hitpoints : float; var part : BodyPart)
  let prevHp = *part.hp
  *part.hp = hitpoints

  if hitpoints <= 0f
    *part.isInjured = true
  elif hitpoints >= part.removeInjuryHp
    *part.isInjured = false

  if prevHp != hitpoints
    human_damage_model_recalc_effects(hero_eid)

def make_array_of_effects(effects : Array; all_parts : Object; var out : array<BodyPartEffect>)
  out |> clear()
  for effect in effects
    let obj = get_ecs_object(effect)
    if obj == null
      continue
    var bodyParts : array<BodyPartEffectPart>
    let effectTemplate = obj?.effectTemplate ?? ""
    let sequential = obj?.sequential ?? false
    let parts = get_ecs_object(obj, "parts")
    if parts != null
      for part in *parts
        let partObj = get_ecs_object(part.value)
        if partObj == null
          continue
        let partMinHp = partObj?.minHp ?? 0f
        let partWhenInjured = partObj?.whenInjured ?? false
        let partApplyEffectChance = partObj?.chance ?? 1f
        let factPartObj = get_ecs_object(all_parts, part.key)
        if factPartObj == null
          logerr("failed to find the body part <{part.key}> for the effect <{effectTemplate}>")
          continue
        let factPartHp = factPartObj?.hp ?? 0f
        let factPartIsInjured = factPartObj?.isInjured ?? false
        bodyParts |> push(BodyPartEffectPart(
                            minHp = partMinHp,
                            hp = factPartHp,
                            whenInjured = partWhenInjured,
                            isInjured = factPartIsInjured,
                            chance = partApplyEffectChance))
    out |> emplace(BodyPartEffect(
                     effectTemplate = effectTemplate,
                     isSequential = sequential,
                     bodyParts <- bodyParts))


def private can_stop_this_effect(effect : BodyPartEffect) : bool
  if effect.isSequential
    for part in effect.bodyParts
      if (part.whenInjured && !part.isInjured) || (!part.whenInjured && part.hp > part.minHp)
        return true
    return false

  for part in effect.bodyParts
    if (part.whenInjured && part.isInjured) || (!part.whenInjured && part.hp <= part.minHp)
      return false
  return true

def private can_start_this_effect(effect : BodyPartEffect) : bool
  if effect.isSequential
    for part in effect.bodyParts
      if (part.whenInjured && !part.isInjured) || (!part.whenInjured && part.hp > part.minHp)
        return false
    return true

  for part in effect.bodyParts
    if (part.whenInjured && part.isInjured) || (!part.whenInjured && part.hp <= part.minHp)
      if gfrnd() > part.chance
        continue
      return true
  return false


def human_damage_model_recalc_effects(eid : EntityId; skip_starting_effects = false)
  query(eid) <| $ [es] (@shared_comp human_damage_model__effects : Array; human_damage_model__parts : Object)
    var effects : array<BodyPartEffect>
    make_array_of_effects(human_damage_model__effects, human_damage_model__parts, effects)
    for effect in effects
      if !skip_starting_effects && can_start_this_effect(effect)
        human_damage_model_start_effect(eid, effect)
      if can_stop_this_effect(effect)
        human_damage_model_stop_effect(eid, effect)


def human_damage_model_kill_entity(eid : EntityId;
                                   death_desc__damageType : int;
                                   death_desc__gunPropsId : int;
                                   death_desc__shellId : int;
                                   death_desc__collNodeId : int;
                                   death_desc__victimTeam : int;
                                   death_desc__offenderTeam : int;
                                   var hitpoints__lastOffender : EntityId&;
                                   var hitpoints__lastOffenderPlayer : EntityId&;
                                   hitpoints__lastVictimPlayer : EntityId;
                                   lastCriticalOffender : EntityId)
  let criticalOffenderTeam = get_int(lastCriticalOffender, "team") ?? TEAM_UNASSIGNED
  let lastOffenderTeam = get_int(hitpoints__lastOffender, "team") ?? TEAM_UNASSIGNED
  if is_teams_friendly(criticalOffenderTeam, lastOffenderTeam)
    let criticalOffender = get_Eid(lastCriticalOffender, "possessed") ?? INVALID_ENTITY_ID
    if criticalOffender != INVALID_ENTITY_ID
      hitpoints__lastOffender = criticalOffender
      hitpoints__lastOffenderPlayer = lastCriticalOffender

  setOptional(eid, "killer", hitpoints__lastOffender)
  send_net_event(eid, EventEntityDied(
    victim = eid, offender = hitpoints__lastOffender,
    damageType = death_desc__damageType, gunPropsId = death_desc__gunPropsId, shellId = death_desc__shellId,
    collNodeId = death_desc__collNodeId, victimTeam = death_desc__victimTeam, offenderTeam = death_desc__offenderTeam))
  print("[human_damage_model_kill_entity] entity died, victim={eid}, offender={hitpoints__lastOffender}")
  broadcast_net_event(EventAnyEntityDied(
    victim = eid, offender = hitpoints__lastOffender, offenderPlayer = hitpoints__lastOffenderPlayer,
    victimPlayer = hitpoints__lastVictimPlayer, damageType = death_desc__damageType, gunPropsId = death_desc__gunPropsId, shellId = death_desc__shellId,
    collNodeId = death_desc__collNodeId, victimTeam = death_desc__victimTeam, offenderTeam = death_desc__offenderTeam))


def human_damage_model_damage_entity(victim_eid : EntityId;
                                     offender_eid : EntityId;
                                     damage : float;
                                     body_part : BodyPart;
                                     dmg_type : DamageType = DamageType.DM_MELEE)
  if body_part.nodesIds != null && length(*body_part.nodesIds) > 0
    var ddesc = DamageDesc(dmg_type, damage, float3())
    ddesc.collNodeId = int16((*body_part.nodesIds)[0])
    damage_entity(victim_eid, offender_eid, ddesc)


def human_damage_model_damage_entity(victim_eid : EntityId;
                                     offender_eid : EntityId;
                                     damage : float;
                                     nodeId : int;
                                     dmg_type : DamageType = DamageType.DM_MELEE)
  var ddesc = DamageDesc(dmg_type, damage, float3())
  ddesc.collNodeId = int16(nodeId)
  damage_entity(victim_eid, offender_eid, ddesc)


def human_damage_model_damage_parts(victim_eid : EntityId;
                                    damage : float;
                                    damage_type : int;
                                    victim_entity_mod_values : Object;
                                    var total_parts : Object;
                                    var parts : array<BodyPart>)
  if empty(parts)
    return
  var totalNotBlockedDamage = 0f
  let damagePerPart = damage / float(length(parts))
  for part in parts
    var calculatedDamage = damagePerPart
    if part.protection != null && damage_type < length(*part.protection)
      let protectionKoef = saturate((*part.protection)[damage_type])
      var heroProtectionKoef = 1.f
      let isProjectile = damage_type == int(DamageType.DM_PROJECTILE)
      let isMelee = damage_type == int(DamageType.DM_MELEE)
      heroProtectionKoef = (isProjectile ? get_mod_value("bulletProtectionMult", victim_entity_mod_values, 1.0) :
                            isMelee ? get_mod_value("meleeProtectionMult", victim_entity_mod_values, 1.0) : 1.0)
      let blockedDamage = protectionKoef * calculatedDamage
      calculatedDamage = max(0.0, calculatedDamage - blockedDamage) / heroProtectionKoef
      sendEventImmediate(
        victim_eid,
        EventDamageModelPartDamageBlocked(
          partName = part.id,
          damageType = damage_type,
          fullDamage = calculatedDamage,
          blockedDamage = blockedDamage))
    let residualDamage = max(0f, *part.hp) - calculatedDamage
    human_damage_model_set_part_hp(victim_eid, *part.hp - calculatedDamage, part)
    totalNotBlockedDamage += calculatedDamage
    if residualDamage < 0f && part.adjacentPartsIds != null && !empty(part.adjacentParts)
      let secondaryDamagePerPart = abs(residualDamage) * part.distributionDamageMult / float(length(part.adjacentParts))
      for adjPartId, adjPartObj in *part.adjacentPartsIds, part.adjacentParts
        var adjPart <- make_object_of_body_part(string(adjPartId), *adjPartObj, total_parts)
        human_damage_model_set_part_hp(victim_eid, *adjPart.hp - secondaryDamagePerPart, adjPart)
  send_net_event(victim_eid, EventDamageModelApplyDamage(totalDamage = damage, notBlockedDamage = totalNotBlockedDamage))


def get_most_damaged_part(human_damage_model__parts : Object) : string
  var result = ""
  var mostDamagedPartValue = 1.0
  for_each_part_in_damage_model(human_damage_model__parts) <| $(bodypart : BodyPartV2)
    let damagedPartValue = bodypart.hp / bodypart.maxHp
    if damagedPartValue < mostDamagedPartValue
      mostDamagedPartValue = damagedPartValue
      result = bodypart.name
    return true
  return result


def get_damaged_parts_count(human_damage_model__parts : Object) : int
  var result = 0
  for_each_part_in_damage_model(human_damage_model__parts) <| $(bodypart : BodyPartV2)
    result += bodypart.hp < bodypart.maxHp ? 1 : 0
    return true
  return result

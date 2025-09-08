options always_export_initializer = true

require ecs
require ecs.common
require DngNet
require DagorDataBlock
require BehNodes
require DngWalkerai
require app
require strings
require math.base
require inventory
require walkerai
require HumanPhys
require DngHuman
require game.es.ai.walker_nodes_common
require game.events.events_game
require game.events.events_active_matter
require pathfinder
require DagorSystem
require game.es.damage_systems.damage_model_healing_common
require game.es.inventory_weapon_mod_common


[beh_node(name="ensureWeaponSlot")]
class ensureWeaponSlot : BehNodeAdapter
  desiredSlot : HUWeaponSlots = HUWeaponSlots.EWS_UNARMED

  def override loadFromBlk(var data : DataBlock) : void
    let slotName = data |> datablock_getStr("slotName", "")
    if empty(slotName)
      error("ensureWeaponSlot: slotName is not set!")
      return

    let slotParam = owner.blackBoard |> get_or_create(slotName, -1)
    let slotValue = owner.blackBoard |> datablock_getInt(slotParam)
    if slotValue < 0
      error("ensureWeaponSlot: slotValue is not set for name \"{slotName}\"!")
      return
    desiredSlot = HUWeaponSlots(slotValue)

  def override init() : void
    let ownerEid = beh_tree_eid(owner)
    query(ownerEid) <| $ [es] (human_net_phys : HumanActor)
      if human_net_phys.phys.currentState.weapEquipState.curSlot == desiredSlot
        return
      // Immediate event is needed to ensure that during update() nextSlot is already set
      sendEventImmediate(ownerEid, HumanWeapSetCurrentGun(slot = uint8(desiredSlot)))

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    let ownerEid = beh_tree_eid(owner)
    query(ownerEid) <| $ [es] (human_net_phys : HumanActor)
      assume weapEquipState = human_net_phys.phys.currentState.weapEquipState
      assume waitingForWeaponSwitch = weapEquipState.nextSlot == desiredSlot && weapEquipState.curSlot != desiredSlot
      assume finishedWeaponSwitch = weapEquipState.curSlot == desiredSlot

      if waitingForWeaponSwitch
        res = EBehResult.ER_RUNNING
        return

      if finishedWeaponSwitch
        res = EBehResult.ER_SUCCESS
        return

    return res


[beh_node(name="shouldHeal")]
class NeedHealing : BehNodeAdapter
  def override update(dt : float) : EBehResult
    assume ownerEid = beh_tree_eid(owner)
    return verify_healing_attempt(ownerEid) ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="useMedkit")]
class UseMedkit : BehNodeAdapter
  healingRequestSent : bool = false
  timeLeft : float = 0.0

  def override init() : void
    healingRequestSent = false
    timeLeft = 0.0

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)

    if !healingRequestSent
      let healItem = get_most_needed_heal_item(eid)
      sendEvent(healItem, TryUseItem(userEid = eid))
      healingRequestSent = true
      timeLeft = 0.2 // To add some leeway for event to arrive and be processed
    else
      query(eid) <| $ [es] (human_inventory__entityToUse : EntityId; human_inventory__entityUseEnd : float)
        if has(human_inventory__entityToUse, "item__healTemplateName")
          timeLeft = human_inventory__entityUseEnd - get_sync_time()

    timeLeft -= dt
    return timeLeft > 0f ? EBehResult.ER_RUNNING : EBehResult.ER_SUCCESS


[beh_node(name="isInBlindness")]
class IsInBlindness : BehNodeAdapter
  blindnessTimeEndParam : int = -1
  earlyReleaseTime : float = 0.5

  def override loadFromBlk(var data : DataBlock) : void
    blindnessTimeEndParam = owner.blackBoard |> get_or_create("blindness.timeEnd", 0f)
    earlyReleaseTime = data |> datablock_getReal("earlyReleaseTime", earlyReleaseTime)

  def override update(dt : float) : EBehResult
    let timeEnd = owner.blackBoard |> datablock_getReal(blindnessTimeEndParam) - earlyReleaseTime
    return timeEnd > get_sync_time() ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="findNearestPointInsideZone")]
class FindNearestPointInsideZone : BehNodeAdapter
  margin : float = 4.0
  posParam : int = -1
  maxProjectionRadius : float = 5.0

  def override loadFromBlk(var data : DataBlock) : void
    margin = data |> datablock_getReal("margin", margin)
    maxProjectionRadius = data |> datablock_getReal("maxProjectionRadius", maxProjectionRadius)
    let posParamName = data |> datablock_getStr("posParam", "")
    if !empty(posParamName)
      posParam = owner.blackBoard |> get_or_create(posParamName, float3(0))
    else
      logerr("FindNearestPointInsideZone: required parameter posParam is not set!")

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    var success = true
    query(agentEid) <| $ [es] (transform aka agent_transform : float3x4)
      // this works when there's only one zone entity on the map
      find_query() <| $ [es] (transform aka zone_transform : float3x4;
                              sphere_zone__radius : float)
        let lengthToCenter = length(zone_transform[3] - agent_transform[3])
        let radiusWithMargin = sphere_zone__radius - margin
        if lengthToCenter < radiusWithMargin
          // use isAgentInsideZone before using this node
          owner.blackBoard |> set(posParam, agent_transform[3])
        else
          let toCenterDir = (zone_transform[3] - agent_transform[3]) / lengthToCenter
          var wishPos = agent_transform[3] + toCenterDir * (lengthToCenter - radiusWithMargin)
          // try several times to find reachable point in navmesh
          var projectionRadius = 1.0
          while !project_to_nearest_navmesh_point(wishPos, projectionRadius)
            projectionRadius += 1.0
            wishPos += toCenterDir
            if projectionRadius > maxProjectionRadius
              success = false
              break
          owner.blackBoard |> set(posParam, wishPos)
        return true
    return success ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="inBlindness")]
class InBlindness : BehNodeAdapter
  blindnessTimeEndParam : int = -1
  earlyReleaseTime : float = 0.5
  isStarted : bool = false

  def override loadFromBlk(var data : DataBlock) : void
    blindnessTimeEndParam = owner.blackBoard |> get_or_create("blindness.timeEnd", 0f)
    earlyReleaseTime = data |> datablock_getReal("earlyReleaseTime", earlyReleaseTime)

  def override init()
    isStarted = false

  def override update(dt : float) : EBehResult
    let timeEnd = owner.blackBoard |> datablock_getReal(blindnessTimeEndParam) - earlyReleaseTime
    if timeEnd > get_sync_time()
      if !isStarted
        isStarted = true
        query(beh_tree_eid(owner)) <| $ [es] (var human_net_phys : HumanActor&)
          human_net_phys.phys.producedCT |> human_control_state_set_walk_speed(0f)
      return EBehResult.ER_RUNNING
    return EBehResult.ER_SUCCESS


[beh_node(name="extinguish")]
class Extinguish : BehNodeAdapter

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    let eid = beh_tree_eid(owner)
    query(eid) <| $ [es] (burning__isPuttingOut = true; burning__isBurning = false)
      if burning__isBurning && !burning__isPuttingOut
        send_net_event(eid, CmdPutOutFireStart())
      res = burning__isBurning ? EBehResult.ER_RUNNING : EBehResult.ER_SUCCESS

    return res


def find_best_grenade_ammo_item_id(itemContainer : EidList; grenadeTypesList : StringList) : int
  var bestItemId = INVALID_ITEM_ID
  var bestItemIdPriority = -1
  if empty(grenadeTypesList)
    return bestItemId
  var found = false
  for itemEid in itemContainer
    query(itemEid) <| $ [es] (item__grenadeType : string; item__id : int)
      let idx = find_index(grenadeTypesList, item__grenadeType)
      if idx != -1
        let foundItemIdPriority = idx
        if bestItemIdPriority == -1 || foundItemIdPriority < bestItemIdPriority
          bestItemIdPriority = foundItemIdPriority
          bestItemId = item__id
        if foundItemIdPriority == 0
          found = true
          return
    if found
      break
  return bestItemId

[beh_node(name="chooseBestWeapon")]
class ChooseBestWeapon : BehNodeAdapter
  targetParam : int = -1
  selectWeapon : bool = true
  defaultCombatDist : float = 20.0
  allowMelee : bool = false

  def override loadFromBlk(var data : DataBlock) : void
    let targetParamName = data |> datablock_getStr("targetParam", "")
    if !empty(targetParamName)
      targetParam = owner.blackBoard |> get_or_create(targetParamName, 0)
    selectWeapon = data |> datablock_getBool("selectWeapon", selectWeapon)
    defaultCombatDist = data |> datablock_getReal("defaultCombatDist", defaultCombatDist)
    allowMelee = data |> datablock_getBool("allowMelee", allowMelee)

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    let agentEid = beh_tree_eid(owner)
    query(agentEid) <| $ [es] (human_unarmed__active = false;
                               transform : float3x4;
                               human_weap__gunEids : EidList;
                               var human_net_phys : HumanActor&)
      if human_unarmed__active
        return

      var vehicleTarget = false
      var distToTargetSq = square(defaultCombatDist)
      let targetUnitId = targetParam >= 0 ? owner.blackBoard |> datablock_getInt(targetParam) : 0
      query(EntityId(uint(targetUnitId))) <| $ [es] (ai_target : Target;
                                                     agent_dangers__tag : string = "")
        vehicleTarget = agent_dangers__tag == "vehicle"
        distToTargetSq = length_sq(ai_target.targetPos - transform[3])

      if vehicleTarget
        var foundGrenade = false
        query(agentEid) <| $ [es] (itemContainer : EidList; @shared_comp beh_tree__antitankGrenades : StringList)
          let grenadeItemId = find_best_grenade_ammo_item_id(itemContainer, beh_tree__antitankGrenades)
          if grenadeItemId != INVALID_ITEM_ID
            if selectWeapon
              sendEvent(agentEid, CmdSetWishGrenadeType(slot_id = int(HUWeaponSlots.EWS_GRENADE), item_id = grenadeItemId, try_take = false, wish_item = INVALID_ENTITY_ID))
            foundGrenade = true
        res = foundGrenade ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED
        return

      var bestWeapon = -1
      var bestFiringRange = -1.0
      var hasReloadingGun = false
      for i, gunEid in range(int(HUWeaponSlots.EWS_MELEE)), human_weap__gunEids
        if gunEid == INVALID_ENTITY_ID
          continue
        var firingRange = float2()
        var gunAmmo = 0
        query(gunEid) <| $ [es] (combatFiringRange : float2; weapon_mods__delayedMoveState : int = -1; gun__totalAmmo : int = 0; gun__ammo : int = 0)
          firingRange = combatFiringRange
          gunAmmo = gun__totalAmmo + gun__ammo
          hasReloadingGun = weapon_mods__delayedMoveState > int(ModDelayedMoveState.WAIT)
        if hasReloadingGun
          return //Don't break mod installation or else it will be dropped
        if gunAmmo <= 0
          continue
        if (square(firingRange.y) < distToTargetSq && bestWeapon != -1) || firingRange.x < bestFiringRange
          continue
        bestFiringRange = firingRange.x
        bestWeapon = i

      if selectWeapon
        if bestWeapon >= 0
          set_chosen_weapon(human_net_phys.phys.producedCT, HUWeaponSlots(bestWeapon))
          res = EBehResult.ER_SUCCESS
        elif allowMelee
          set_chosen_weapon(human_net_phys.phys.producedCT, HUWeaponSlots.EWS_MELEE)
          res = EBehResult.ER_SUCCESS
    return res


[beh_node(name="checkTargetEcs")]
class CheckTargetEcs : BehNodeAdapter
  targetParam : string
  @hidden targetParamHash : uint
  ignoreDead : bool = true
  ignoreHidden : bool = true
  ignoreDowned : bool = false

  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("targetParam", targetParam, targetParamHash, thisNode)
    ignoreDead = data |> datablock_getBool("ignoreDead", ignoreDead)
    ignoreHidden = data |> datablock_getBool("ignoreHidden", ignoreHidden)
    ignoreDowned = data |> datablock_getBool("ignoreDowned", ignoreDowned)

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    let eid = beh_tree_eid(owner)
    let targetParamRef = eid |> get_Eid(targetParam, targetParamHash)
    if targetParamRef != null
      query(*targetParamRef) <| $ [es] (ai_target : Target)
        if (!ignoreDead || ai_target.isAlive) && (!ignoreHidden || !ai_target.isHidden) && (!ignoreDowned || !ai_target.isDowned)
          result = EBehResult.ER_SUCCESS
    return result


[beh_node(name="dangerCount")]
class DangerCount : BehNodeAdapter
  posParam : int = -1
  radiusParam : int = -1
  searchRadius : float = -1.0f
  includeDangerTag : string
  excludeDangerTag : string
  includeEcsTag : string
  @hidden includeEcsTagHash : uint
  excludeEcsTag : string
  @hidden excludeEcsTagHash : uint
  countParam : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    let posParamName = data |> datablock_getStr("posParam", "")
    if !empty(posParamName)
      posParam = owner.blackBoard |> get_or_create(posParamName, 0)
    let radiusParamName = data |> datablock_getStr("radiusParamName", "")
    if !empty(radiusParamName)
      radiusParam = owner.blackBoard |> get_or_create(radiusParamName, 0)
    searchRadius = data |> datablock_getReal("radius", searchRadius)

    includeDangerTag = data |> datablock_getStr("includeDangerTag", "")
    excludeDangerTag = data |> datablock_getStr("excludeDangerTag", "")
    includeEcsTag = data |> datablock_getStr("includeEcsTag", "")
    includeEcsTagHash = includeEcsTag != "" ? ecs_hash(includeEcsTag) : 0u
    excludeEcsTag = data |> datablock_getStr("excludeEcsTag", "")
    excludeEcsTagHash = excludeEcsTag != "" ? ecs_hash(excludeEcsTag) : 0u

    let countParamName = data |> datablock_getStr("countParam", "")
    if !empty(countParamName)
      countParam = owner.blackBoard |> get_or_create(countParamName, 0)

  def override update(dt : float) : EBehResult
    var count = 0
    let agentEid = beh_tree_eid(owner)
    searchRadius = radiusParam >= 0 ? owner.blackBoard |> datablock_getReal(radiusParam) : searchRadius
    query(agentEid) <| $ [es] (transform aka agent_transform : float3x4;
                               agent_dangers : AgentDangers)
      let pos = posParam >= 0 ? owner.blackBoard |> datablock_getPoint3(posParam) : agent_transform[3]
      for danger in agent_dangers.dangers
        query(danger.eid) <| $ [es] (transform aka target_transform : float3x4;
                                     agent_dangers__tag : string = "")
          let checkDist = !(searchRadius > 0.0f && length(pos - target_transform[3]) > searchRadius)
          let checkIncludeDangerTag = includeDangerTag == "" || agent_dangers__tag == includeDangerTag
          let checkExcludeDangerTag = excludeDangerTag == "" || agent_dangers__tag != excludeDangerTag
          let checkIncludeEcsTag = includeEcsTag == "" || has(danger.eid, includeEcsTag, includeEcsTagHash)
          let checkExcludeEcsTag = excludeEcsTag == "" || !has(danger.eid, excludeEcsTag, excludeEcsTagHash)
          if (checkDist &&
              checkIncludeDangerTag && checkExcludeDangerTag &&
              checkIncludeEcsTag && checkExcludeEcsTag)
            count += 1

    owner.blackBoard |> set(countParam, count)
    return EBehResult.ER_SUCCESS


[beh_node(name="targetIsSleeping")]
class TargetIsSleeping : BehNodeAdapter
  targetParam : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    let targetParamName = data |> datablock_getStr("targetParam", "")
    if !empty(targetParamName)
      targetParam = owner.blackBoard |> get_or_create(targetParamName, 0)

  def override update(dt : float) : EBehResult
    let targetUnitId = targetParam >= 0 ? owner.blackBoard |> datablock_getInt(targetParam) : 0
    if EntityId(uint(targetUnitId)) |> has("sleeping_monster")
      return EBehResult.ER_SUCCESS
    return EBehResult.ER_FAILED


[beh_node(name="findDangerByEcsTag")]
class FindDangerByEcsTag : BehNodeAdapter
  targetParam : string
  @hidden targetParamHash : uint
  tag : string
  @hidden tagHash : uint
  radiusParam : int = -1
  outDangerParam : int = -1
  outSeeTimeParam : int = -1
  minDanger : float = -1.0
  canBeInVehicle : bool = true

  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("targetParam", targetParam, targetParamHash, thisNode)
    canBeInVehicle = data |> datablock_getBool("canBeInVehicle", canBeInVehicle)
    minDanger = data |> datablock_getReal("minDanger", minDanger)
    tag = data |> datablock_getStr("tag", tag)

    let radiusParamName = data |> datablock_getStr("radiusParam", "")
    if !empty(radiusParamName)
      radiusParam = owner.blackBoard |> get_or_create(radiusParamName, 0)

    let outDangerParamName = data |> datablock_getStr("outDangerParam", "")
    if !empty(outDangerParamName)
      outDangerParam = owner.blackBoard |> get_or_create(outDangerParamName, 0)

    let outSeeTimeParamName = data |> datablock_getStr("outSeeTimeParam", "")
    if !empty(outSeeTimeParamName)
      outSeeTimeParam = owner.blackBoard |> get_or_create(outSeeTimeParamName, 0)

    tag = data |> datablock_getStr("tag", "")
    tagHash = !empty(tag) ? ecs_hash(tag) : 0u


  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    let eid = beh_tree_eid(owner)
    query(eid) <| $ [es] (agent_dangers : AgentDangers; transform : float3x4; agent_dangers__standShootPos : float3 const?)
      if length(agent_dangers.dangers) == 0
        return
      let searchRadius = radiusParam >= 0 ? (owner.blackBoard |> datablock_getReal(radiusParam)) : -1.0
      let shootPos = agent_dangers__standShootPos != null ? *agent_dangers__standShootPos : transform[3]
      var bestScore = minDanger
      var bestSeeTime = -1.0
      var bestDanger = INVALID_ENTITY_ID
      for danger in agent_dangers.dangers
        if danger.eid == eid
          continue
        query(danger.eid) <| $ [es] (ai_target : Target)
          if ai_target.isHidden || !ai_target.isAlive || (!canBeInVehicle && (ai_target.useVehicle > 0u))
            return
          if !has(danger.eid, tag, tagHash)
            return
          if searchRadius >= .0 && distance(shootPos, ai_target.targetPos) > searchRadius
            return

          if danger.dangerMeter > bestScore
            bestDanger = danger.eid
            bestScore = danger.dangerMeter
            bestSeeTime = danger.inFrustumTime

      if bestDanger == INVALID_ENTITY_ID
        return
      var eidComp = getRW_Eid(eid, targetParam, targetParamHash)
      if eidComp == null
        logerr("<{eid}>({getEntityTemplateName(eid)}) has no {targetParam}. Although it used to have it.")
        return
      if outSeeTimeParam >= 0
        let targetEid = get_Eid(eid, targetParam, targetParamHash) ?? INVALID_ENTITY_ID
        if targetEid != bestDanger
          owner.blackBoard |> set(outSeeTimeParam, bestSeeTime)
      *eidComp = bestDanger

      if outDangerParam >= 0
        owner.blackBoard |> set(outDangerParam, bestScore)
      result = EBehResult.ER_SUCCESS
    return result


[beh_node(name="traceAgentDangers")]
class TraceAgentDangers : BehNodeAdapter
  forceRetrace : bool = false

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    sendEventImmediate(eid, CmdTraceAgentDangers(forceRetrace = forceRetrace))
    return EBehResult.ER_SUCCESS
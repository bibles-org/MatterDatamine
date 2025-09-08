options always_export_initializer = true
require ecs
require ecs.common
require app
require strings
require BehNodes
require game.es.action_common
require walkerai
require DngWalkerai
require DngDm
require DngNet
require DagorDataBlock
require DagorConsole
require DagorRandom
require DagorSystem
require DagorDebug3D
require game.es.ai.walker_common
require debug.logerr_once
require CollisionTraces
require DngHuman
require game.utils.team
require Grid
require GridCollision
require game.es.inventory_common
require game.es.inventory_item_common
require game.es.inventory_weapon_common
require game.events.events_active_matter
require ecs.safe
require math.base
require game.es.item_equip_common
require game.es.inventory_enums_common
require NavmeshMapping
require pathfinder
require game.es.level_common
require math.random
require CollRes


[beh_node(name="log")]
class Log : BehNodeAdapter
  msg : string = "msg"

  def override loadFromBlk(var data : DataBlock) : void
    msg = datablock_getStr(data, "msg", msg)

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    print("{eid}: {msg}")
    return EBehResult.ER_SUCCESS

[beh_node(name="visualLog")]
class VisualLog : Log

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    print("{eid}: {msg}")
    visual_log("{eid}: {msg}")
    return EBehResult.ER_SUCCESS

[beh_node(name="logerr")]
class Logerr : Log

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    print("{eid}: {msg}")
    logerr("{eid}: {msg}")
    return EBehResult.ER_SUCCESS


[beh_node(name="drawDebugPillar")]
class DrawDebugPillar : Log

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    query(eid) <| $ [es] (transform : float3x4)
      let color = E3DCOLOR(0xffffffff)
      draw_debug_sphere_buffered(transform[3], 1.0, color, 1000)
      draw_debug_line_buffered(transform[3], transform[3] + float3(0, 100, 0), color, 1000)
    return EBehResult.ER_SUCCESS


[beh_node(name="setTime")]
class SetTime : BehNodeAdapter
  toParam : string
  @hidden toParamHash : uint

  def override loadFromBlk(var data : DataBlock) : void
    data |> load_ecs_param("to", toParam, toParamHash)

  def override update(dt : float) : EBehResult
    var v = getRW_float(beh_tree_eid(owner), toParam, toParamHash)
    if v != null
      *v = get_sync_time()
      return EBehResult.ER_SUCCESS
    return EBehResult.ER_FAILED


[beh_node(name="hasTimePassed")]
class HasTimePassed : BehNodeAdapter
  fromParam : string
  @hidden fromParamHash : uint
  durationParam : string
  @hidden durationParamHash : uint

  def override loadFromBlk(var data : DataBlock) : void
    data |> load_ecs_param("from", fromParam, fromParamHash)
    data |> load_ecs_param("duration", durationParam, durationParamHash)

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    let from = get_float(eid, fromParam, fromParamHash) ?? .0
    let duration = get_float(eid, durationParam, durationParamHash) ?? .0
    return from + duration < get_sync_time() ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="destroyEntity")]
class DestroyEntity : BehNodeAdapter

  def override update(dt : float) : EBehResult
    destroyEntity(beh_tree_eid(owner))
    return EBehResult.ER_SUCCESS

[beh_node(name="runAction")]
class RunAction : BehNodeAdapter
  action : string = "stand_melee"

  def override loadFromBlk(var data : DataBlock)
    action = data |> datablock_getStr("action", action)

  def override update(dt : float) : EBehResult
    let res = EBehResult.ER_SUCCESS
    let eid = beh_tree_eid(owner)
    run_action(eid, action)
    return res

[beh_node(name="interruptActions")]
class InterruptActions : BehNodeAdapter
  def override update(dt : float) : EBehResult
    interrupt_actions(beh_tree_eid(owner))
    return EBehResult.ER_SUCCESS

[beh_node(name="failedChance")]
class FailedChance : BehNodeAdapter
  chance : float = 0f
  chanceParam : string
  @hidden chanceParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    chance = data |> datablock_getReal("chance", chance)
    data |> load_optional_ecs_param("chanceParam", chanceParam, chanceParamHash)

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    let currentChance = chanceParamHash != 0u ? get_float(eid, chanceParam, chanceParamHash) ?? chance : chance
    return gfrnd() < currentChance ? EBehResult.ER_FAILED : EBehResult.ER_SUCCESS


[beh_node(name="successChance")]
class SuccessChance : BehNodeAdapter
  chance : float = 0f
  chanceParam : string
  @hidden chanceParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    chance = data |> datablock_getReal("chance", chance)
    data |> load_optional_ecs_param("chanceParam", chanceParam, chanceParamHash)

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    let currentChance = chanceParamHash != 0u ? get_float(eid, chanceParam, chanceParamHash) ?? chance : chance
    return gfrnd() < currentChance ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

[beh_node(name="debugBlink")]
class DebugBlink : BehNodeAdapter
  duration : int = 1000
  color : E3DCOLOR = E3DCOLOR(0xffffffff)
  posParam : string
  eidParam : string
  @hidden posParamHash : uint
  @hidden eidParamHash : uint

  def override loadFromBlk(var data : DataBlock) : void
    duration = data |> datablock_getInt("duration", duration)
    color = data |> datablock_getE3dcolor("color", color)
    data |> load_optional_ecs_param("posParam", posParam, posParamHash)
    data |> load_optional_ecs_param("eidParam", eidParam, eidParamHash)

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    var pos : float3
    if posParamHash != 0u
      pos = get_Point3(eid, posParam, posParamHash) ?? float3()
    elif eidParamHash != 0u
      let targetEid = get_Eid(eid, eidParam, eidParamHash) ?? INVALID_ENTITY_ID
      query(targetEid) <| $ [es] (transform : float3x4)
        pos = transform[3]
    else
      query(eid) <| $ [es] (transform : float3x4)
        pos = transform[3]
    draw_debug_sphere_buffered(pos, 1, color, duration)
    return EBehResult.ER_SUCCESS


[beh_node(name="isDoor")]
class IsDoor : BehNodeAdapter
  targetParam : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    let param = datablock_getStr(data, "param", "")
    if !empty(param)
      targetParam = owner.blackBoard |> get_or_create(param, targetParam)

  def override update(dt : float) : EBehResult
    let eid = owner.blackBoard |> datablock_getInt(targetParam)
    var result = EBehResult.ER_FAILED
    query(EntityId(uint(eid))) <| $ [es] (isDoor : bool)
      if isDoor
        result = EBehResult.ER_SUCCESS
    return result


[beh_node(name="applyGameAffect")]
class ApplyGameAffect : BehNodeAdapter
  targetParam : string
  @hidden targetParamHash : uint
  affectParam : string
  @hidden affectParamHash : uint
  templateName : string
  delay : float2
  duration : float2

  currentTime : float
  currentDuration : float

  def override loadFromBlk(var data : DataBlock)
    templateName = data |> datablock_getStr("templateName", templateName)
    if empty(templateName)
      logerr("applyGameAffect: templateName is empty. {data |> datablock_resolveFilename(false)}")
    delay = data |> datablock_getPoint2("delay", delay)
    duration = data |> datablock_getPoint2("duration", duration)
    data |> load_optional_ecs_param("targetParam", targetParam, targetParamHash)
    data |> load_optional_ecs_param("affectParam", affectParam, affectParamHash)

  def override init()
    currentTime = -rnd_float(delay.x, delay.y)
    currentDuration = rnd_float(duration.x, duration.y)

  def override update(dt : float) : EBehResult
    if currentTime <= 0. && currentTime + dt > 0.
      let agentEid = beh_tree_eid(owner)
      let targetEid = targetParamHash == 0u ? agentEid : agentEid |> get_Eid(targetParam, targetParamHash) ?? INVALID_ENTITY_ID
      if targetEid != INVALID_ENTITY_ID
        let affectEid = createEntity(templateName) <| $(ini)
          ini |> set("game_effect__attachedTo", targetEid)
          ini |> set("game_effect__ownerEid", agentEid)
          ini |> set("game_effect__affectUniqueKeyName", "{agentEid}")
        if affectParamHash != 0u
          var affectEidRef = getRW_Eid(agentEid, affectParam, affectParamHash)
          if affectEidRef != null
            *affectEidRef = affectEid

    currentTime += dt
    return currentTime < currentDuration ? EBehResult.ER_RUNNING : EBehResult.ER_SUCCESS


[beh_node(name="destroyGameAffect")]
class DestroyGameAffect : BehNodeAdapter
  affectParam : string
  @hidden affectParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("affectParam", affectParam, affectParamHash, thisNode)

  def override update(dt : float) : EBehResult
    let ownerEid = beh_tree_eid(owner)
    var affectEidRef = ownerEid |> getRW_Eid(affectParam, affectParamHash)
    if affectEidRef != null
      destroyEntity(*affectEidRef)
      *affectEidRef = INVALID_ENTITY_ID
    return EBehResult.ER_SUCCESS


[beh_node(name="copyEntityPos")]
class CopyEntityPos : BehNodeAdapter
  posParam : string
  @hidden posParamHash : uint
  eidParam : string
  @hidden eidParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("pos", posParam, posParamHash)
    data |> load_ecs_param("eid", eidParam, eidParamHash)

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    let eid = beh_tree_eid(owner)
    let targetEid = get_Eid(eid, eidParam, eidParamHash) ?? INVALID_ENTITY_ID
    query(targetEid) <| $ [es] (transform : float3x4)
      var posRef = getRW_Point3(eid, posParam, posParamHash)
      if posRef != null
        *posRef = transform[3]
        result = EBehResult.ER_SUCCESS
    return result


[beh_node(name="copyPoint3")]
class copyPoint3 : BehNodeAdapter
  fromParam : string
  @hidden fromParamHash : uint
  toParam : string
  @hidden toParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("from", fromParam, fromParamHash)
    data |> load_ecs_param("to", toParam, toParamHash)

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    let eid = beh_tree_eid(owner)
    let from = get_Point3(eid, fromParam, fromParamHash)
    var to = getRW_Point3(eid, toParam, toParamHash)
    if from != null && to != null
      *to = *from
      result = EBehResult.ER_SUCCESS
    return result


[beh_node(name="limitPerPeriod")]
class LimitPerPeriod : BehNodeAdapter
  period : float = 1.0
  maxCount : int = 1
  //These values are in BB so that the same limit could be applied in multiple places
  resetParam : int
  countParam : int

  def override loadFromBlk(var data : DataBlock) : void
    maxCount = data |> datablock_getInt("maxCount", maxCount)
    period = data |> datablock_getReal("period", period)
    let tag = data |> datablock_getStr("tag", "")
    if !empty(tag)
      resetParam = owner.blackBoard |> get_or_create("_{tag}-reset", 0.0)
      countParam = owner.blackBoard |> get_or_create("_{tag}-count", 0)
    else
      logerr("'tag' must be provided in node 'limitPerPeriod'. Agent: {getEntityTemplateName(beh_tree_eid(owner))}")


  def override update(dt : float) : EBehResult
    var count = owner.blackBoard |> datablock_getInt(countParam)
    if count >= maxCount
      let nextResetAt = owner.blackBoard |> datablock_getReal(resetParam)
      let time = get_sync_time()
      if nextResetAt < time
        owner.blackBoard |> set(resetParam, time + period)
        count = 0
      else
        return EBehResult.ER_FAILED
    count++
    owner.blackBoard |> set(countParam, count)
    return EBehResult.ER_SUCCESS


[beh_node(name="addTemplate")]
class AddTemplate : BehNodeAdapter
  templName : string
  remote : bool = true

  def override loadFromBlk(var data : DataBlock) : void
    templName = datablock_getStr(data, "name", templName)
    remote = datablock_getBool(data, "remote", remote)

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    if remote
      remote_add_sub_template(eid, templName)
    else
      addSubTemplate(eid, templName)
    return EBehResult.ER_SUCCESS


[beh_node(name="removeTemplate")]
class RemoveTemplate : BehNodeAdapter
  templName : string
  remote : bool = true

  def override loadFromBlk(var data : DataBlock) : void
    templName = datablock_getStr(data, "name", templName)
    remote = datablock_getBool(data, "remote", remote)

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    if remote
      remote_remove_sub_template(eid, templName)
    else
      removeSubTemplate(eid, templName)
    return EBehResult.ER_SUCCESS


[beh_node(name="findAimTargetInGrid")]
class FindAimTargetInGrid : BehNodeAdapter
  blackboardParam : int
  traceLength : float
  traceRadius : float
  gridHash : uint

  def override loadFromBlk(var data : DataBlock)
    traceLength = data |> datablock_getReal("traceLength", 10.0)
    traceRadius = data |> datablock_getReal("traceRadius", 0.3)
    gridHash = ecs_hash(data |> datablock_getStr("gridTag", "humans"))
    blackboardParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "blackboardParamName", "aimTarget"), int(uint(INVALID_ENTITY_ID)))

  def override update(dt : float) : EBehResult
    var aimEntity = INVALID_ENTITY_ID
    let eid = beh_tree_eid(owner)
    query(eid) <| $ [es] (human_net_phys : HumanActor; human__aimTm : float3x4)
      var position = float3(human_net_phys.phys.currentState.location.P)
      let gunDir = human_net_phys.phys.currentState.gunDir
      position = human__aimTm[3]
      using() <| $(var intersections : IntersectedEntities)
        var t = traceLength
        trace_entities_in_grid_by_capsule(gridHash, position, gunDir, t, traceRadius, eid, intersections, SortIntersections.YES)
        if length(intersections) == 0
          return
        aimEntity = intersections[0].eid
    owner.blackBoard |> set(blackboardParam, int(uint(aimEntity)))
    return aimEntity != INVALID_ENTITY_ID ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="isEntityFriendly")]
class IsEntityFriendly : BehNodeAdapter
  blackboardParam : int

  def override loadFromBlk(var data : DataBlock)
    blackboardParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "blackboardParamName", ""), int(uint(INVALID_ENTITY_ID)))

  def override update(dt : float) : EBehResult
    let eid = EntityId(uint(owner.blackBoard |> datablock_getInt(blackboardParam)))
    var friendly = false
    query(beh_tree_eid(owner)) <| $ [es] (team aka owner_team : int;
                                          personal_enemies__enemies : EidList const?)
      query(eid) <| $ [es] (team aka target_team : int)
        friendly = is_teams_friendly(target_team, owner_team) && !is_personal_enemy(personal_enemies__enemies, eid)
    return friendly ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="doesEntityHaveComponent")]
class doesEntityHaveComponent : BehNodeAdapter
  blackboardParam : int
  componentName : string
  componentNameHash : uint

  def override loadFromBlk(var data : DataBlock)
    blackboardParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "entityParam", ""), int(uint(INVALID_ENTITY_ID)))
    componentName = datablock_getStr(data, "componentName", "")
    componentNameHash = ecs_hash(componentName)

  def override update(dt : float) : EBehResult
    let eid = EntityId(uint(owner.blackBoard |> datablock_getInt(blackboardParam)))
    return has(eid, componentName, componentNameHash) ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="takeItemFromInventory")]
class TakeItemFromInventory : BehNodeAdapter
  targetInventoryParam : int

  def override loadFromBlk(var data : DataBlock)
    targetInventoryParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "inventoryParam", ""), int(uint(INVALID_ENTITY_ID)))

  def override update(dt : float) : EBehResult
    let inventoryEid = EntityId(uint(owner.blackBoard |> datablock_getInt(targetInventoryParam)))
    var success = true
    let isContainer = query(inventoryEid) <| $ [es] (itemContainer : EidList)
      if empty(itemContainer)
        success = false
        return
      assume item = itemContainer[0]
      let initialLength = length(itemContainer)
      move_item_to_inventory_container(item, inventoryEid, beh_tree_eid(owner))
      let afterLength = length(itemContainer)
      if initialLength == afterLength // failed to move item
        success = false
    success = success && isContainer
    return success ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="isInventoryEmpty")]
class IsInventoryEmpty : BehNodeAdapter
  targetInventoryParam : int

  def override loadFromBlk(var data : DataBlock)
    targetInventoryParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "inventoryParam", ""), int(uint(INVALID_ENTITY_ID)))

  def override update(dt : float) : EBehResult
    let inventoryEid = EntityId(uint(owner.blackBoard |> datablock_getInt(targetInventoryParam)))
    var isEmpty = false
    query(inventoryEid) <| $ [es] (itemContainer : EidList)
      isEmpty = empty(itemContainer)
    return isEmpty ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


def should_extract_item(item : EntityId; importantAmmoHolders : array<int>) : bool
  var shouldExtract = true
  query(item) <| $ [es] (item__healTemplateName : das_string const?;
                         ammo_holder__id : int const?)
    shouldExtract = item__healTemplateName != null
    if !shouldExtract
      return
    if ammo_holder__id != null
      if has_value(importantAmmoHolders, *ammo_holder__id)
        shouldExtract = false
        return
  return shouldExtract


def get_important_ammo_holders(human_weap__gunEids : EidList) : array<int>
  var importantAmmoHolders : array<int>
  for gunEid in human_weap__gunEids
    query(gunEid) <| $ [es] (gun__ammoHolderIds : IntList)
      for holder in gun__ammoHolderIds
        push(importantAmmoHolders, holder)
  return <- importantAmmoHolders


[beh_node(name="shouldExtractLoot")]
class ShouldExtractLoot : BehNodeAdapter
  minLootAmount : int = 10

  def override loadFromBlk(var data : DataBlock)
    minLootAmount = data |> datablock_getInt("minLootAmount", minLootAmount)

  def override update(dt : float) : EBehResult
    let militantEid = beh_tree_eid(owner)
    var shouldExtract = false
    query(militantEid) <| $ [es] (itemContainer : EidList; human_weap__gunEids : EidList)
      var numItemsToExtract = 0
      let importantAmmoHolders <- get_important_ammo_holders(human_weap__gunEids)
      for item in itemContainer
        if should_extract_item(item, importantAmmoHolders)
          ++numItemsToExtract
      shouldExtract = numItemsToExtract >= minLootAmount
    return shouldExtract ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="equipWeaponsFromInventory")]
class EquipWeaponsFromInventory : BehNodeAdapter
  def override update(dt : float)
    let militantEid = beh_tree_eid(owner)
    var didEquip = false
    query(militantEid) <| $ [es] (human_weap__gunEids : EidList; var itemContainer : EidList)
      var availableSlots : array<int>
      for i, gunEid in range(int(HUWeaponSlots.EWS_NUM)), human_weap__gunEids
        if gunEid == INVALID_ENTITY_ID
          push(availableSlots, i)
          continue
        query(gunEid) <| $ [es] (gun__ammo : int)
          if gun__ammo == 0
            push(availableSlots, i)
      for item in itemContainer
        var isGun = false
        var hasAmmo = false
        var isSlotCompatible = false
        query(item) <| $ [es] (gun__ammoHolderIds : IntList; item__weaponSlots : StringList)
          isGun = true
          for slotName in item__weaponSlots
            let slotIdx = int(HUWeaponSlots(string(slotName)))
            if has_value(availableSlots, slotIdx)
              isSlotCompatible = true
              break
          for it in itemContainer
            query(it) <| $ [es] (ammo_holder__id : int)
              hasAmmo = has_value(gun__ammoHolderIds, ammo_holder__id)
        if isGun && hasAmmo && isSlotCompatible
          pickup_gun(militantEid, item, -1)
          didEquip = true

    return didEquip ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="isMeleeEquipped")]
class IsMeleeEquipped : BehNodeAdapter
  def override update(dt : float) : EBehResult
    let militantEid = beh_tree_eid(owner)
    var isMeleeEquipped = false
    query(militantEid) <| $ [es] (human_net_phys : HumanActor)
      isMeleeEquipped = human_net_phys.phys.currentState.weapEquipState.curSlot == HUWeaponSlots.EWS_MELEE
    return isMeleeEquipped ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="findClosestEntityWithComponent")]
class FindClosestEntityWithComponent : BehNodeAdapter
  componentNameHash : uint
  componentName : string
  outParam : int

  def override loadFromBlk(var data : DataBlock)
    componentName = datablock_getStr(data, "componentName", "")
    componentNameHash = ecs_hash(componentName)
    outParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outParamName", ""), int(uint(INVALID_ENTITY_ID)))

  def override update(dt : float) : EBehResult
    var closestEntity = INVALID_ENTITY_ID
    var closestDistSq = FLT_MAX
    let militantEid = beh_tree_eid(owner)
    query(militantEid) <| $ [es] (transform aka militant_transform : float3x4)
      query() <| $ [es] (eid : EntityId; transform aka entity_transform : float3x4)
        if !has(eid, componentName, componentNameHash)
          return
        let distSq = distance_sq(militant_transform[3], entity_transform[3])
        if distSq < closestDistSq
          closestEntity = eid
          closestDistSq = distSq
    owner.blackBoard |> set(outParam, int(uint(closestEntity)))
    return closestEntity != INVALID_ENTITY_ID ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="findRandomEntityWithComponent")]
class FindRandomEntityWithComponent : BehNodeAdapter
  componentNameHash : uint
  componentName : string
  outParam : int

  def override loadFromBlk(var data : DataBlock)
    componentName = datablock_getStr(data, "componentName", "")
    componentNameHash = ecs_hash(componentName)
    outParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "outParamName", ""), int(uint(INVALID_ENTITY_ID)))

  def override update(dt : float) : EBehResult
    var candidates : array<EntityId>
    query() <| $ [es] (eid : EntityId)
      if !has(eid, componentName, componentNameHash)
        return
      push(candidates, eid)
    if empty(candidates)
      return EBehResult.ER_FAILED
    let index = rnd_int(0, length(candidates) - 1)
    owner.blackBoard |> set(outParam, int(uint(candidates[index])))
    return EBehResult.ER_SUCCESS


[beh_node(name="copyEcsIntFromEntity")]
class CopyEcsIntFromEntity : BehNodeAdapter
  eidParam : int
  ecsName : string
  ecsNameHash : uint
  blackBoardParam : int

  def override loadFromBlk(var data : DataBlock)
    let eidParamName = datablock_getStr(data, "entityParam", "")
    eidParam = owner.blackBoard |> get_or_create(eidParamName, int(uint(INVALID_ENTITY_ID)))

    ecsName = datablock_getStr(data, "ecsName", "")
    ecsNameHash = ecs_hash(ecsName)
    let blackBoardParamName = datablock_getStr(data, "blackBoardName", "")
    blackBoardParam = owner.blackBoard |> get_or_create(blackBoardParamName, 0)

  def override update(dt : float) : EBehResult
    let eid = EntityId(uint(owner.blackBoard |> datablock_getInt(eidParam)))
    let val = get_int(eid, ecsName, ecsNameHash)
    if val != null
      owner.blackBoard |> set(blackBoardParam, *val)
      return EBehResult.ER_SUCCESS
    return EBehResult.ER_FAILED


[beh_node(name="setEcsPoint3FromBb")]
class SetEcsPoint3FromBb : BehNodeAdapter
  bbParam : int
  ecsName : string
  ecsNameHash : uint

  def override loadFromBlk(var data : DataBlock)
    let bbName = datablock_getStr(data, "from", "")
    bbParam = owner.blackBoard |> get_or_create(bbName, 0)
    ecsName = datablock_getStr(data, "to", "")
    ecsNameHash = ecs_hash(ecsName)

  def override update(dt : float) : EBehResult
    let positionValue = owner.blackBoard |> datablock_getPoint3(bbParam)
    set(beh_tree_eid(owner), ecsName, ecsNameHash, positionValue)
    return EBehResult.ER_SUCCESS


[beh_node(name="getAgentPosition")]
class GetAgentPosition : BehNodeAdapter
  toParam : int

  def override loadFromBlk(var data : DataBlock)
    let paramName = datablock_getStr(data, "to", "")
    toParam = owner.blackBoard |> get_or_create(paramName, float3(0.0))

  def override update(dt : float) : EBehResult
    query(beh_tree_eid(owner)) <| $ [es] (transform : float3x4)
      owner.blackBoard |> set(toParam, transform[3])
    return EBehResult.ER_SUCCESS


[beh_node(name="addEidToList")]
class AddEidToList : BehNodeAdapter
  eidEcsName : string
  eidEcsNameHash : uint
  listEcsName : string
  listEcsNameHash : uint

  def override loadFromBlk(var data : DataBlock)
    eidEcsName = datablock_getStr(data, "eid", "")
    eidEcsNameHash = ecs_hash(eidEcsName)
    listEcsName = datablock_getStr(data, "list", "")
    listEcsNameHash = ecs_hash(listEcsName)

  def override update(dt : float) : EBehResult
    let ownerEid = beh_tree_eid(owner)
    let eidVal = get_Eid(ownerEid, eidEcsName, eidEcsNameHash)
    var listVal = getRW_ecs_EidList(ownerEid, listEcsName, listEcsNameHash)
    if eidVal != null && listVal != null
      *listVal |> push(*eidVal)
      return EBehResult.ER_SUCCESS
    return EBehResult.ER_FAILED


[beh_node(name="doesEntityExist")]
class DoesEntityExist : BehNodeAdapter
  targetParam : string

  @hidden targetParamHash : uint
  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("targetEcsComponent", targetParam, targetParamHash)

  def override update(dt : float) : EBehResult
    let eidRef = beh_tree_eid(owner) |> get_Eid(targetParam, targetParamHash)
    if eidRef == null
      return EBehResult.ER_FAILED
    return doesEntityExist(*eidRef) ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="findRandomPosInsideZone")]
class FindWanderPosInsideZone : BehNodeAdapter
  posParam : int
  minDistanceFromZoneBorder : float
  mustBeOnNavmesh : bool
  mustBeAccessible : bool
  maxAttempts : int
  @hidden outParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    let posParamName = datablock_getStr(data, "posParam", "")
    if posParamName == ""
      error("findRandomPosInsideZone: no posParam specified")
      return
    posParam = owner.blackBoard |> get_or_create(posParamName, float3(0.0))
    minDistanceFromZoneBorder = datablock_getReal(data, "minDistanceFromZoneBorder", 20.0)
    mustBeOnNavmesh = datablock_getBool(data, "mustBeOnNavmesh", true)
    mustBeAccessible = datablock_getBool(data, "mustBeAccessible", true)
    maxAttempts = datablock_getInt(data, "maxAttempts", 3)


  def override update(dt : float) : EBehResult
    var attemptsLeft = maxAttempts
    var success = false
    var resultPos : float3

    var zonePos = float3(0.0)
    var zoneRad = 0.0
    var foundZone = false

    foundZone = find_query() <| $ [es] (moving_zone__targetPos : float3; moving_zone__targetRadius : float)
      zonePos = moving_zone__targetPos
      zoneRad = moving_zone__targetRadius
      return true

    if !foundZone
      return EBehResult.ER_FAILED

    while attemptsLeft > 0
      attemptsLeft -= 1

      let offset2D = rnd_point_on_disk(max(0.0, zoneRad - minDistanceFromZoneBorder))
      var pos = zonePos + float3(offset2D.x, 0.0, offset2D.y)
      pos = navmesh_map_position(pos)

      var poly : dtPolyRef
      if !project_to_nearest_navmesh_point(pos, float3(10.0), poly) && mustBeOnNavmesh
        continue
      if mustBeAccessible && !is_polygon_accessible(poly)
        continue
      resultPos = pos
      success = true
      break

    if !success
      return EBehResult.ER_FAILED

    owner.blackBoard |> set(posParam, resultPos)
    return EBehResult.ER_SUCCESS


[beh_node(name="canResurrect")]
class CanResurrect : BehNodeAdapter
  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (possessedByPlr : EntityId)
      query(possessedByPlr) <| $ [es] (active_matter_bot_player__freeResurrections : int)
        if active_matter_bot_player__freeResurrections > 0
          result = EBehResult.ER_SUCCESS
    return result


[beh_node(name="findDeadTeammate")]
class FindDeadTeammate : BehNodeAdapter
  outParam : int
  findClosest : bool

  def override loadFromBlk(var data : DataBlock) : void
    let unitParamName = datablock_getStr(data, "saveToParam", "")
    findClosest = datablock_getBool(data, "findClosest", false)
    if unitParamName == ""
      error("findDeadTeammate: no saveToParam specified")
      return
    outParam = owner.blackBoard |> get_or_create(unitParamName, int(uint(INVALID_ENTITY_ID)))

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    var ownerTeam = TEAM_UNASSIGNED
    let ownerEid = beh_tree_eid(owner)
    var thisPlayer = INVALID_ENTITY_ID
    var ownerPosition : float3
    query(ownerEid) <| $ [es] (team : int; possessedByPlr : EntityId; transform : float3x4)
      ownerTeam = team
      thisPlayer = possessedByPlr
      ownerPosition = transform[3]

    if ownerTeam == TEAM_UNASSIGNED
      error("findDeadTeammate: owner team unknown")
      return res

    var closestDistance = FLT_MAX
    find_query() <| $ [es(REQUIRE=player)] (team : int; possessed : EntityId; eid aka other_player_eid : EntityId)
      if team != ownerTeam || other_player_eid == thisPlayer
        return false
      query(possessed) <| $ [es(REQUIRE=deadEntity)] (transform : float3x4)
        var isCloser = false
        if findClosest
          let distance_sq = distance_sq(ownerPosition, transform[3])
          if distance_sq < closestDistance
            closestDistance = distance_sq
            isCloser = true

        if !findClosest || isCloser
          res = EBehResult.ER_SUCCESS
          owner.blackBoard |> set(outParam, int(uint(possessed)))
      if res == EBehResult.ER_SUCCESS && !findClosest
        return true

      return false

    return res


def find_cortical_vault_for_player(itemContainer : EidList; player : EntityId)
  var result = INVALID_ENTITY_ID
  for item in itemContainer
    query(item) <| $ [es(REQUIRE=cortical_vault)] (playerItemOwner : EntityId)
      if player != playerItemOwner
        return
      result = item
    if result != INVALID_ENTITY_ID
      break
  return result


[beh_node(name="takeItemFromContainer")]
class TakeItemFromContainer : BehNodeAdapter
  fromContainerParam : int = -1
  itemParam : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    let unitParamName = datablock_getStr(data, "from", "")
    if unitParamName == ""
      error("takeItemFromContainer: no \"from\" param specified")
      return
    fromContainerParam = owner.blackBoard |> get_or_create(unitParamName, int(uint(INVALID_ENTITY_ID)))

    let itemParamName = datablock_getStr(data, "item", "")
    if itemParamName == ""
      error("takeItemFromContainer: no \"item\" param specified")
      return
    itemParam = owner.blackBoard |> get_or_create(itemParamName, int(uint(INVALID_ENTITY_ID)))


  def override update(dt : float) : EBehResult
    let container = EntityId(uint(owner.blackBoard |> datablock_getInt(fromContainerParam)))
    let item = EntityId(uint(owner.blackBoard |> datablock_getInt(itemParam)))

    var result = EBehResult.ER_FAILED
    query(container) <| $ [es] (itemContainer : EidList)
      let idx = find_index(itemContainer, item)
      if idx < 0
        return

      let ownerEid = beh_tree_eid(owner)
      move_item_to_inventory_container(item, ownerEid, ownerEid)
      result = EBehResult.ER_SUCCESS

    return result


[beh_node(name="checkHaveCorticalVaultForHero")]
class CheckHaveCorticalVaultForHero : BehNodeAdapter
  targetParam : int

  def override loadFromBlk(var data : DataBlock) : void
    let targetParamName = datablock_getStr(data, "targetUnitParam", "")
    if targetParamName == ""
      error("checkHaveCorticalVaultForHero: no targetUnitParam specified")
      return
    targetParam = owner.blackBoard |> get_or_create(targetParamName, int(uint(INVALID_ENTITY_ID)))

  def override update(dt : float) : EBehResult
    let ownerEid = beh_tree_eid(owner)
    let targetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(targetParam)))
    var success = false
    query(targetEid) <| $ [es] (possessedByPlr : EntityId)
      query(ownerEid) <| $ [es] (itemContainer : EidList)
        let vault = find_cortical_vault_for_player(itemContainer, possessedByPlr)
        success = vault != INVALID_ENTITY_ID
    return success ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="resurrectAlly")]
class ResurrectAlly : BehNodeAdapter
  targetAlly : int
  started : bool
  vaultEid : EntityId

  def override loadFromBlk(var data : DataBlock) : void
    let targetParamName = datablock_getStr(data, "targetUnitParam", "")
    if targetParamName == ""
      error("resurrectAlly: no targetUnitParam specified")
      return
    targetAlly = owner.blackBoard |> get_or_create(targetParamName, int(uint(INVALID_ENTITY_ID)))

  def override init() : void
    started = false

  def override update(dt : float) : EBehResult
    let ownerEid = beh_tree_eid(owner)
    if !started
      vaultEid = INVALID_ENTITY_ID
      let targetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(targetAlly)))
      if targetEid == INVALID_ENTITY_ID
        return EBehResult.ER_FAILED
      query(targetEid) <| $ [es] (possessedByPlr : EntityId)
        query(ownerEid) <| $ [es] (itemContainer : EidList)
          vaultEid = find_cortical_vault_for_player(itemContainer, possessedByPlr)

      if vaultEid == INVALID_ENTITY_ID
        return EBehResult.ER_FAILED
      send_net_event(ownerEid, RequestUseCorticalVault(itemEid = vaultEid, targetEid = ownerEid, atTime = get_sync_time()))
      started = true
      return EBehResult.ER_RUNNING
    else
      var result = EBehResult.ER_SUCCESS
      query(ownerEid) <| $ [es] (human_inventory__entityToUse : EntityId)
        if human_inventory__entityToUse == vaultEid
          result = EBehResult.ER_RUNNING
      return result


[beh_node(name="findSquadLeader")]
class FindSquadLeader : BehNodeAdapter
  outParam : int

  def override loadFromBlk(var data : DataBlock) : void
    let unitParamName = datablock_getStr(data, "saveToParam", "")
    if unitParamName == ""
      error("findSquadLeader: no saveToParam specified")
      return
    outParam = owner.blackBoard |> get_or_create(unitParamName, int(uint(INVALID_ENTITY_ID)))

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    var ownerTeam = TEAM_UNASSIGNED
    let ownerEid = beh_tree_eid(owner)
    var isLeader = false
    query(ownerEid) <| $ [es] (team : int; bot_squad_leader : Tag const?)
      isLeader = bot_squad_leader != null
      ownerTeam = team

    if isLeader
      return res

    if ownerTeam == TEAM_UNASSIGNED
      error("findSquadLeader: owner team unknown")
      return res

    find_query() <| $ [es(REQUIRE=bot_squad_leader, REQUIRE_NOT=deadEntity)] (eid : EntityId; team : int)
      if team != ownerTeam || eid == ownerEid
        return false

      owner.blackBoard |> set(outParam, int(uint(eid)))
      res = EBehResult.ER_SUCCESS
      return true
    return res


[beh_node(name="checkDistanceToEntityBbox")]
class CheckDistanceToEntityBbox : BehNodeAdapter
  entityParam : int
  distance : float

  def override loadFromBlk(var data : DataBlock) : void
    let unitParamName = datablock_getStr(data, "target", "")
    if unitParamName == ""
      error("checkDistanceToEntityBbox: no \"target\" specified")
      return

    distance = datablock_getReal(data, "distance", -1.0)
    if distance < 0.0
      error("checkDistanceToEntityBbox: no \"distance\" specified")
      return
    entityParam = owner.blackBoard |> get_or_create(unitParamName, int(uint(INVALID_ENTITY_ID)))

  def override update(dt : float) : EBehResult
    if distance < 0.0 || entityParam < 0
      return EBehResult.ER_FAILED

    let target = EntityId(uint(owner.blackBoard |> datablock_getInt(entityParam)))
    let ownerEid = beh_tree_eid(owner)
    var res = EBehResult.ER_FAILED
    query(ownerEid) <| $ [es] (transform aka owner_transform : float3x4)
      query(target) <| $ [es] (ri_extra__bboxMax : float3 const?;
                               ri_extra__bboxMin : float3 const?;
                               collres : CollisionResource const?;
                               transform : float3x4)
        var bbox = BBox3()
        if ri_extra__bboxMax != null && ri_extra__bboxMin != null
          bbox = BBox3(*ri_extra__bboxMin, *ri_extra__bboxMax)
        elif collres != null
          bbox = (*collres).boundingBox
        else
          return
        let localPos = inverse(transform) * owner_transform[3]
        let isInside = int3(
          localPos.x >= bbox.boxMin.x && localPos.x <= bbox.boxMax.x ? 1 : 0,
          localPos.y >= bbox.boxMin.y && localPos.y <= bbox.boxMax.y ? 1 : 0,
          localPos.z >= bbox.boxMin.z && localPos.z <= bbox.boxMax.z ? 1 : 0
        )
        let diff = float3(
          isInside.x == 1 ? 0.0 : min(abs(localPos.x - bbox.boxMin.x), abs(localPos.x - bbox.boxMax.x)),
          isInside.y == 1 ? 0.0 : min(abs(localPos.y - bbox.boxMin.y), abs(localPos.y - bbox.boxMax.y)),
          isInside.z == 1 ? 0.0 : min(abs(localPos.z - bbox.boxMin.z), abs(localPos.z - bbox.boxMax.z))
        )
        if length_sq(diff) < square(distance)
          res = EBehResult.ER_SUCCESS
    return res


[beh_node(name="findCorticalVault")]
class FindCorticalVault : BehNodeAdapter
  outParam : int
  outContainerParam : int
  outHumanOwnerParam : int
  heroOwnerParam : int

  def override loadFromBlk(var data : DataBlock)
    let unitParamName = datablock_getStr(data, "saveToParam", "")
    if unitParamName == ""
      error("findCorticalVault: no saveToParam specified")
      return
    outParam = owner.blackBoard |> get_or_create(unitParamName, int(uint(INVALID_ENTITY_ID)))

    let heroOwnerParamName = datablock_getStr(data, "heroOwner", "")
    if heroOwnerParamName == ""
      error("findCorticalVault: no heroOwner specified")
      return
    heroOwnerParam = owner.blackBoard |> get_or_create(heroOwnerParamName, int(uint(INVALID_ENTITY_ID)))

    let containerParamName = datablock_getStr(data, "saveContainerToParam", "")
    if containerParamName != ""
      outContainerParam = owner.blackBoard |> get_or_create(containerParamName, int(uint(INVALID_ENTITY_ID)))
    else
      outContainerParam = -1

    let humanOwnerParamName = datablock_getStr(data, "saveHumanOwnerToParam", "")
    if humanOwnerParamName != ""
      outHumanOwnerParam = owner.blackBoard |> get_or_create(humanOwnerParamName, int(uint(INVALID_ENTITY_ID)))
    else
      outHumanOwnerParam = -1


  def override update(var delta : float) : EBehResult
    let heroOwner = EntityId(uint(owner.blackBoard |> datablock_getInt(heroOwnerParam)))
    var result = EBehResult.ER_FAILED

    query(heroOwner) <| $ [es] (possessedByPlr : EntityId)
      find_query() <| $ [es(REQUIRE=cortical_vault)] (playerItemOwner : EntityId;
                                                      eid : EntityId;
                                                      item__containerOwnerEid : EntityId;
                                                      item__humanOwnerEid : EntityId)
        if possessedByPlr == playerItemOwner
          owner.blackBoard |> set(outParam, int(uint(eid)))
          result = EBehResult.ER_SUCCESS
          if outContainerParam != -1
            owner.blackBoard |> set(outContainerParam, int(uint(item__containerOwnerEid)))
          if outHumanOwnerParam != -1
            owner.blackBoard |> set(outHumanOwnerParam, int(uint(item__humanOwnerEid)))
        return result == EBehResult.ER_SUCCESS
    return result


[beh_node(name="benchmarkSelectNextPos")]
class BenchmarkSelectNextPos : BehNodeAdapter
  posParam : int = -1

  def override loadFromBlk(var data : DataBlock)
    posParam = owner.blackBoard |> get_or_create("benchmarkPos", float3())

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    var res = EBehResult.ER_FAILED
    query(eid) <| $ [es] (benchmarked_agent__points : Point3List;
                          var benchmarked_agent__idx : int&;
                          var benchmarked_agent__targetPos : float3&)
      benchmarked_agent__idx = (benchmarked_agent__idx + 1) % length(benchmarked_agent__points)
      benchmarked_agent__targetPos = benchmarked_agent__points[benchmarked_agent__idx]
      owner.blackBoard |> set(posParam, benchmarked_agent__targetPos)
      res = EBehResult.ER_SUCCESS
    return res


[beh_node(name="checkDistanceBetweenPositions")]
class CheckDistanceBetweenPositions : BehNodeAdapter
  pos1Param : int = -1
  pos2Param : int = -1
  distToCheck : float

  def override loadFromBlk(var data : DataBlock)
    let pos1ParamName = datablock_getStr(data, "pos1", "")
    let pos2ParamName = datablock_getStr(data, "pos2", "")
    distToCheck = datablock_getReal(data, "distance", -1.0)

    if pos1ParamName == ""
      error("checkDistanceBetweenNodes: no pos1 specified")
      return

    if pos2ParamName == ""
      error("checkDistanceBetweenNodes: no pos2 specified")
      return

    if distToCheck < 0.0
      error("checkDistanceBetweenNodes: no distance specified")
      return

    pos1Param = owner.blackBoard |> get_or_create(pos1ParamName, float3(0.0))
    pos2Param = owner.blackBoard |> get_or_create(pos2ParamName, float3(0.0))

  def override update(dt : float) : EBehResult
    let pos1 = owner.blackBoard |> datablock_getPoint3(pos1Param)
    let pos2 = owner.blackBoard |> datablock_getPoint3(pos2Param)
    return distance(pos1, pos2) < distToCheck ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


def private get_emote_id_by_name(name : string; human_sec_anim__config : Array)
  for emoteConfig, idx in human_sec_anim__config, iter_range(human_sec_anim__config)
    let config = emoteConfig as Object
    if config == null
      continue
    let a2dName = config?["a2d"] ?? ""
    if !empty(a2dName) && ends_with(a2dName, name)
      return idx
  return -1


[beh_node(name="performEmote")]
class PerformEmote : BehNodeAdapter
  emoteId : int
  isStarted : bool
  failDueToLimiter : bool

  def override loadFromBlk(var data : DataBlock)
    emoteId = -1
    let emoteName = datablock_getStr(data, "emoteName", "")
    query(beh_tree_eid(owner)) <| $ [es] (@shared_comp human_sec_anim__config : Array)
      emoteId = get_emote_id_by_name(emoteName, human_sec_anim__config)
    if emoteId < 0
      logerr_once("[PerformEmote] Emote \"{emoteName}\" not found for {beh_tree_eid(owner)}")

  def override init() : void
    isStarted = false
    failDueToLimiter = false
    query(beh_tree_eid(owner)) <| $ [es] (var bot_gestures_limiter__nextGestureAt : float&; bot_gestures_limiter__gestureInterval : float)
      let curTime = get_sync_time()
      if curTime < bot_gestures_limiter__nextGestureAt
        failDueToLimiter = true
      else
        bot_gestures_limiter__nextGestureAt = curTime + bot_gestures_limiter__gestureInterval

  def override update(dt : float) : EBehResult
    if emoteId < 0 || failDueToLimiter
      return EBehResult.ER_FAILED

    let eid = beh_tree_eid(owner)
    if !isStarted
      isStarted = true
      sendEvent(eid, CmdUseEmote(emoteId = emoteId))
      return EBehResult.ER_RUNNING

    var res = EBehResult.ER_FAILED
    query(eid) <| $ [es] (human_sec_anim__play : bool)
      res = human_sec_anim__play ? EBehResult.ER_RUNNING : EBehResult.ER_SUCCESS
    return res


[beh_node(name="guardHasAllies")]
class GuardHasAllies : BehNodeAdapter
  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)

    var result = EBehResult.ER_FAILED
    query(eid) <| $ [es] (bot_allies__eids : EidList)
      if !empty(bot_allies__eids)
        result = EBehResult.ER_SUCCESS
    return result


[beh_node(name="chooseRandomNearbyAlly")]
class chooseRandomNearbyAlly : BehNodeAdapter
  outParam : int

  def override loadFromBlk(var data : DataBlock) : void
    let unitParamName = datablock_getStr(data, "saveToParam", "")
    if unitParamName == ""
      error("chooseRandomNearbyAlly: no saveToParam specified")
      return
    outParam = owner.blackBoard |> get_or_create(unitParamName, int(uint(INVALID_ENTITY_ID)))

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    var result = EBehResult.ER_FAILED
    query(eid) <| $ [es] (bot_allies__eids : EidList)
      if empty(bot_allies__eids)
        return

      let index = rnd_int(0, length(bot_allies__eids) - 1)
      let allyEid = bot_allies__eids[index]
      owner.blackBoard |> set(outParam, int(uint(allyEid)))
      result = EBehResult.ER_SUCCESS
    return result


[beh_node(name="tellAlliesAboutDanger")]
class TellAlliesAboutDanger : BehNodeAdapter
  dangerBbParam : int

  def override loadFromBlk(var data : DataBlock) : void
    let paramName = datablock_getStr(data, "dangerParam", "")
    dangerBbParam = owner.blackBoard |> get_or_create(paramName, int(uint(INVALID_ENTITY_ID)))

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (bot_allies__eids : EidList)
      let newDangerEid = EntityId(uint(owner.blackBoard |> datablock_getInt(dangerBbParam)))
      var newDangerPos = float3(0.0)
      query(newDangerEid) <| $ [es] (transform : float3x4)
        newDangerPos = transform[3]
      for ally in bot_allies__eids
        query(ally) <| $ [es] (transform aka ally_transform : float3x4;
                               var agent_dangers : AgentDangers)
          var hasThisDanger = false
          for danger in agent_dangers.dangers
            if danger.eid == newDangerEid
              danger.dangerMeter = 1.0
              hasThisDanger = true
              break
          if !hasThisDanger
            using() <| $(var newDanger : Danger#)
              newDanger.eid = newDangerEid
              newDanger.inFrustumTime = -1.0
              newDanger.distance = distance(newDangerPos, ally_transform[3])
              newDanger.alertness = 1000.0
              newDanger.traceable = true
              newDanger.dangerMeter = 1.0
              push_clone(agent_dangers.dangers, newDanger)


      result = EBehResult.ER_SUCCESS
    return result


[beh_node(name="setLean")]
class SetLean : BehNodeAdapter
  leanValue : float

  def override loadFromBlk(var data : DataBlock) : void
    leanValue = datablock_getReal(data, "value", 0.0)
    if leanValue < -1.0 || leanValue > 1.0
      error("setLean: invalid lean value {leanValue}, must be in range [-1.0, 1.0]")
      return

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    var res = EBehResult.ER_FAILED
    query(eid) <| $ [es] (var human_net_phys : HumanActor&)
      human_net_phys.phys.producedCT |> human_control_state_set_lean_position(leanValue)
      res = EBehResult.ER_SUCCESS

    return res


[beh_node(name="isAgentInsideZone")]
class IsInsideStormZone : BehNodeAdapter
  valueIfNoZones : bool
  checkZoneTargetState : bool

  def override loadFromBlk(var data : DataBlock) : void
    valueIfNoZones = datablock_getBool(data, "valueIfNoZones", true)
    checkZoneTargetState = datablock_getBool(data, "checkZoneTargetState", true)

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    var isInZone = valueIfNoZones
    query(eid) <| $ [es] (transform aka owner_transform : float3x4)
      find_query() <| $ [es] (moving_zone__targetPos : float3;
                              transform aka zone_transform : float3x4;
                              sphere_zone__radius : float;
                              moving_zone__targetRadius : float)
        assume zonePos = checkZoneTargetState ? moving_zone__targetPos : zone_transform[3]
        assume zoneRadius = checkZoneTargetState ? moving_zone__targetRadius : sphere_zone__radius
        let distSq = distance_sq(owner_transform[3], zonePos)
        if distSq < square(zoneRadius)
          isInZone = true
          return true
        return false
    return isInZone ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

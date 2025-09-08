require ecs
require ecs.safe
require ecs.common
require app
require math.base
require strings
require DagorMath
require Grid
require GridCollision
require game.events.events_game
require game.events.inventory_events
require game.events.events_active_matter


[es(tag=server)]
def sensor_item_pickup(evt : EventOnItemPickup;
                       var sensor_abilities__abilitiesProps : Array;
                       var sensor_abilities__abilitiesStates : Array)
  query(evt.itemEid) <| $ [es] (item__id : int;
                                sensor__searchRange : float2;
                                sensor__searchRadExtensionMult : float;
                                sensor__directionPerSensors : int;
                                sensor__enemySearchTag : das_string const?;
                                sensor__itemSearchTag : das_string const?)
    var addedToExisting = false
    for abilityProps in sensor_abilities__abilitiesProps
      var abilityPropsObj = getRW_ecs_object(abilityProps)
      if abilityPropsObj != null
        let sensorId = (*abilityPropsObj).sensorId ?? 0
        if item__id == sensorId
          addedToExisting = true
          var sensorsCount = getRW_int(*abilityPropsObj, "sensorsCount")
          if sensorsCount != null
            *sensorsCount += 1
          break

    if addedToExisting == false
      using() <| $(var propsObject : Object)
        propsObject |> set("sensorId", item__id)
        propsObject |> set("sensorTemplate", split_template(getEntityTemplateName(evt.itemEid))[0])
        propsObject |> set("sensorsCount", 1)
        propsObject |> set("sensorSearchRange", sensor__searchRange)
        propsObject |> set("sensorSearchRadExtensionMult", sensor__searchRadExtensionMult)
        propsObject |> set("sensorDirectionPerSensors", sensor__directionPerSensors)
        if sensor__enemySearchTag != null
          propsObject |> set("sensorEnemySearchTag", string(*sensor__enemySearchTag))
        else
          propsObject |> set("sensorItemSearchTag", string(*sensor__itemSearchTag))
        sensor_abilities__abilitiesProps |> push(propsObject)
      using() <| $(var emptyList : EidList)
        sensor_abilities__abilitiesStates |> push(emptyList)


[es(tag=server)]
def sensor_item_drop(evt : EventOnItemDrop;
                     var sensor_abilities__abilitiesProps : Array;
                     var sensor_abilities__abilitiesStates : Array)
  query(evt.itemEid) <| $ [es] (item__id : int)
    for i in iter_range(sensor_abilities__abilitiesProps)
      var abilityPropsObj = getRW_ecs_object(sensor_abilities__abilitiesProps[i])
      if abilityPropsObj != null
        let sensorId = (*abilityPropsObj).sensorId ?? 0
        if item__id == sensorId
          var sensorsCount = getRW_int(*abilityPropsObj, "sensorsCount")
          if sensorsCount != null
            if *sensorsCount > 1
              *sensorsCount -= 1
            else
              sensor_abilities__abilitiesProps |> erase(i)
              sensor_abilities__abilitiesStates |> erase(i)
          break


[es(tag=server, no_order)]
def sensor_abilities_update(act : ParallelUpdateFrameDelayed;
                            sensor_abilities__updateTime : float;
                            sensor_abilities__abilitiesProps : Array;
                            transform : float3x4;
                            var sensor_abilities__nextUpdateTime : float&;
                            var sensor_abilities__abilitiesStates : Array)
  if get_sync_time() < sensor_abilities__nextUpdateTime
    return
  sensor_abilities__nextUpdateTime = get_sync_time() + sensor_abilities__updateTime

  for abilityProps, abilityState in sensor_abilities__abilitiesProps, sensor_abilities__abilitiesStates
    let abilityPropsObj = get_ecs_object(abilityProps)
    var abilityStateList = getRW_ecs_EidList(abilityState)
    if abilityPropsObj != null && abilityStateList != null
      *abilityStateList |> clear()
      let sensorSearchRange = (*abilityPropsObj).sensorSearchRange ?? float2(1f)
      let sensorSearchRadExtensionMult = (*abilityPropsObj).sensorSearchRadExtensionMult ?? 1f
      let sensorsCount = (*abilityPropsObj).sensorsCount ?? 1
      let sensorScanRad = min(sensorSearchRange.y, sensorSearchRange.x * pow(sensorSearchRadExtensionMult, float(sensorsCount - 1)))
      let gridType = has(*abilityPropsObj, "sensorItemSearchTag") ? ecs_hash("loot") : ecs_hash("humans")
      let sensorItemSearchTag = get_string(*abilityPropsObj, "sensorItemSearchTag", "")
      let sensorEnemySearchTag = get_string(*abilityPropsObj, "sensorEnemySearchTag", "")
      let tagName = !empty(sensorItemSearchTag) ? sensorItemSearchTag : sensorEnemySearchTag
      let tagNameHash = ecs_hash(tagName)
      let sensorDirectionPerSensors = (*abilityPropsObj).sensorDirectionPerSensors ?? 0
      let directionsCount = sensorsCount / sensorDirectionPerSensors
      var foundEntities : array<tuple<dist : float; eid : EntityId>>
      for_each_entity_in_grid(gridType, BSphere3(transform[3], sensorScanRad), GridEntCheck.POS) <| $(objEid : EntityId; objPos : float3)
        if !empty(tagName) && objEid |> has(tagName, tagNameHash) && (objEid |> get_bool("isAlive") ?? true)
          var ellipsoidDir = objPos - transform[3]
          ellipsoidDir.y *= 0.3
          let targetDistSq = length_sq(ellipsoidDir)
          let insertIdx = foundEntities |> find_index_if() <| $(value)
            return value.dist > targetDistSq
          foundEntities |> push((targetDistSq, objEid), insertIdx >= 0 ? insertIdx : length(foundEntities))
      if directionsCount == 0 && length(foundEntities) > 0
        *abilityStateList |> push(foundEntities[0].eid)
      else
        for _, entity in range(directionsCount), foundEntities
          *abilityStateList |> push(entity.eid)


[es(tag=server)]
def sensor_owner_died(evt : EventEntityDied;
                      var sensor_abilities__abilitiesProps : Array;
                      var sensor_abilities__abilitiesStates : Array)
  sensor_abilities__abilitiesProps |> clear()
  sensor_abilities__abilitiesStates |> clear()
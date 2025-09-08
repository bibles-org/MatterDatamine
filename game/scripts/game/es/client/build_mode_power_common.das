module build_mode_power_common shared

require ecs
require strings
require math.base
require game.es.client.build_mode_preview_common
require game.es.client.build_mode_common
require DagorSystem


def get_construction_power_station(controller : EntityId)
  var result = INVALID_ENTITY_ID
  query(controller) <| $ [es] (construction_controller__parts : EidList)
    for part in construction_controller__parts
      if has(part, "power_station")
        result = part
        break
  return result


def can_attach_power(powered_controller : EntityId; power_station : EntityId)
  var result = false
  let poweredPreviewId = get_id_from_preview(powered_controller)
  query(powered_controller) <| $ [es] (transform aka powered_controller_transform : float3x4)
    query(power_station) <| $ [es] (power_station__maxSlots : int;
                                    power_station__range : float;
                                    power_station__connectedBuildingIds : StringList;
                                    transform aka power_station_transform : float3x4)
      if distance_sq(power_station_transform[3], powered_controller_transform[3]) > square(power_station__range)
        return

      let index = find_index_if(each(power_station__connectedBuildingIds)) <| $(id : das_string)
        return string(id) == poweredPreviewId
      if index != -1
        result = true
        return

      if length(power_station__connectedBuildingIds) >= power_station__maxSlots
        return
      result = true
  return result


def attach_power(powered_controller : EntityId; power_station : EntityId)
  query(power_station) <| $ [es] (construction_part__controller : EntityId; var power_station__connectedBuildingIds : StringList)
    let stationPreviewId = get_id_from_preview(construction_part__controller)
    query(powered_controller) <| $ [es] (construction_controller__instanceId : string)
      let index = find_index_if(each(power_station__connectedBuildingIds)) <| $(id : das_string)
        return string(id) == construction_controller__instanceId
      if index == -1
        push(power_station__connectedBuildingIds, construction_controller__instanceId)
    addSubTemplate(powered_controller, "powered_controller") <| $(init)
      set(init, "powered_controller__attachedTo", stationPreviewId)


def detach_power(powered_controller : EntityId; power_station : EntityId)
  let previewId = get_id_from_preview(powered_controller)
  query(power_station) <| $ [es] (var power_station__connectedBuildingIds : StringList)
    let index = find_index_if(each(power_station__connectedBuildingIds)) <| $(id : das_string)
      return string(id) == previewId
    if index == -1
      logerr("cannot detach controller <{powered_controller}> from power station <{power_station}>: not attached")
    else
      erase(power_station__connectedBuildingIds, index)
    removeSubTemplate(powered_controller, "powered_controller")


def try_power_controller(controller : EntityId)
  return find_query() <| $ [es(REQUIRE=power_station)] (eid : EntityId)
    if !can_attach_power(controller, eid)
      return false
    attach_power(controller, eid)
    return true

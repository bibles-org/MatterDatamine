module build_mode_common shared

require ecs
require ecs.safe
require game.events.events_active_matter
require DagorSystem


def hide_building(eid : EntityId)
  query(eid) <| $ [es] (var construction_controller__parts : EidList&)
    for part in construction_controller__parts
      destroyEntity(part)
    clear(construction_controller__parts)


def unhide_building(eid : EntityId)
  sendEvent(eid, CmdRecreateBuildingParts())


def is_build_mode_active()
  var buildModeActive = false
  find_query() <| $ [es] (base_build_mode__active : bool)
    buildModeActive = base_build_mode__active
    return true
  return buildModeActive


def find_preview_by_id(id : string)
  var controller = INVALID_ENTITY_ID
  find_query() <| $ [es(REQUIRE=base_build_mode_controller_preview)] (eid : EntityId; construction_controller__instanceId : string)
    if construction_controller__instanceId != id
      return false
    controller = eid
    return true
  return controller


def find_controller_by_id(id : string)
  var controller = INVALID_ENTITY_ID
  find_query() <| $ [es(REQUIRE_NOT=base_build_mode_controller_preview)] (eid : EntityId; construction_controller__instanceId : string)
    if construction_controller__instanceId != id
      return false
    controller = eid
    return true
  return controller


def get_blueprint_from_unique_id(id : string)
  var blueprintName = ""
  find_query() <| $ [es] (player_profile__allItems : Array)
    let stashIndex = find_index_if(each(player_profile__allItems)) <| $(item)
      return (item as Object)?.uniqueId ?? "0" == id
    if stashIndex == -1
      logerr("could not find construction in stash. unique_id = <{id}>")
      return true
    let obj = get_ecs_object(player_profile__allItems[stashIndex])
    if obj == null
      logerr("Deploy from stash: could not get item info as Object, unique_id = <{id}>")
      return true
    blueprintName = obj?.template_name ?? ""
    return true
  return blueprintName

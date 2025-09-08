require ecs
require ecs.safe
require math.base
require math.random
require strings
require DagorSystem
require DngNet
require game.es.objectives.objective_common
require game.es.objectives.objective_utils_common
require game.es.inventory_item_common
require game.events.inventory_events
require game.events.events_active_matter
require DagorMath

let EXTRACT_ITEM_DYNAMIC_TARGET = "itemToExtract"


[es(tag=server, on_appear, REQUIRE=objectiveExtractItem)]
def add_dynamic_target_to_extract_item_objective(evt : Event; var objective__params : Array)
  using() <| $(var obj : Object)
    obj |> set("name", "dynamicTargetTag")
    obj |> set("value", EXTRACT_ITEM_DYNAMIC_TARGET)
    objective__params |> push(obj)


[es(tag=(server, gameClient), on_event=EventPlayerFirstSpawn, REQUIRE=objectiveExtractItem)] //offline only
def trigger_objective_init_offline(evt : Event; eid aka player_eid : EntityId)
  query() <| $ [es] (objective__playerEid : EntityId;
                     eid aka objective_eid : EntityId)
    if objective__playerEid == player_eid
      sendEvent(objective_eid, CmdAssignContainerForPlanting())


[es(tag=server, on_appear, on_event=(CmdAssignContainerForPlanting, EventRetriggerEntity), REQUIRE=objectiveExtractItem)]
def init_extract_item_objective(evt : Event;
                                var objective__containerEid : EntityId&;
                                eid : EntityId;
                                objective__params : Array;
                                objective__playerEid : EntityId;
                                objective__itemTemplateNameInParams : string;
                                objective__additionalItemTemplate : string;
                                objective__additionalContainerTemplate : string;
                                objective__backupContainerTemplate : string;
                                objective__containerTypes : StringList)
  if objective__containerEid != INVALID_ENTITY_ID
    return
  if wake_me_up_when_objective_prerequisites_are_loaded(eid) //mostly needed offline
    return

  let itemTemplateName = get_single_objective_item_from_params(objective__params, objective__itemTemplateNameInParams, eid, objective__playerEid)
  if empty(itemTemplateName)
    return
  var itemTemplate = getTemplateByName(itemTemplateName)
  if itemTemplate == null
    itemTemplate = buildTemplateByName(itemTemplateName)
  if itemTemplate == null
    logerr("Item template for objective does not exist: {itemTemplateName}. param: '{objective__itemTemplateNameInParams}' {getEntityTemplateName(eid)} player_eid: {objective__playerEid}")
    return
  let volume = getTemplateComponent(*itemTemplate, "item__volume") ?? 0.0

  let validContainers <- gather_lootable_ri_for_objective(eid, objective__params, objective__containerTypes, volume)
  if length(validContainers) == 0
    //Note, this isn't necessarily a problem if it happens once.
    print("Failed to find suitable container for objective. player:{objective__playerEid}, objective: {getEntityTemplateName(eid)}.")
    objective__containerEid = create_backup_container_for_objective(objective__backupContainerTemplate, eid, objective__params)
    if objective__containerEid == INVALID_ENTITY_ID
      logerr("Failed to create backup container for objective. player:{objective__playerEid}, objective: {getEntityTemplateName(eid)}.")
      return
  else
    let target = validContainers[grnd() % length(validContainers)]
    objective__containerEid = target
    query(target) <| $ [es] (var lootable_ri__objectiveEid : EntityId&;
                             var loot_drop_system__lootPreset : das_string;
                             transform : float3x4;
                             itemContainer__name : string)
      lootable_ri__objectiveEid = eid
      loot_drop_system__lootPreset := "empty_loot_preset"
      objectives_print_log("Player {objective__playerEid} is assigned container at {transform[3]} for {getEntityTemplateName(eid)}")
      remote_change_sub_template(target, "", objective__additionalContainerTemplate) <| $(init)
        init |> set("map_object_marker__tooltip", itemContainer__name)
  let templ = add_sub_template_name(itemTemplateName, objective__additionalItemTemplate)
  create_item_in_inventory_container(templ, objective__containerEid) <| $(init)
    init |> set("item_for_objective__objectiveEid", eid)
    init |> set("objective_dynamic_target__tag", EXTRACT_ITEM_DYNAMIC_TARGET)


[es(tag=server, REQUIRE=item_for_extract_item_objective)]
def track_extract_item_objective_when_items_moved(evt : EventOnMovingBetweenInventories; item_for_objective__objectiveEid : EntityId)
  query(item_for_objective__objectiveEid) <| $ [es] (eid aka objective_eid : EntityId;
                                                     objective__playerEid : EntityId)
    query(evt.newInventoryEid) <| $ [es] (inventory__humanOwnerEid : EntityId)
      query(inventory__humanOwnerEid) <| $ [es] (possessedByPlr : EntityId)
        if possessedByPlr == objective__playerEid
          complete_progress_for_objective(objective_eid)
        else
          reset_progress_for_objective(objective_eid)


[es(tag=gameClient, REQUIRE=item_for_extract_item_objective)]
def hide_map_marker_when_item_for_extraction_moved(evt : EventOnMovingBetweenInventories; item_for_objective__objectiveEid : EntityId)
  query(evt.oldInventoryEid) <| $ [es] (lootable_ri__objectiveEid : EntityId; var map_object__show : bool&)
    if item_for_objective__objectiveEid == lootable_ri__objectiveEid
      map_object__show = false


[es(tag=gameClient)]
def hide_map_marker_when_item_for_extraction_dropped(evt : EventOnItemDrop; lootable_ri__objectiveEid : EntityId; var map_object__show : bool&)
  query(evt.itemEid) <| $ [es(REQUIRE=item_for_extract_item_objective)] (item_for_objective__objectiveEid : EntityId)
    if item_for_objective__objectiveEid == lootable_ri__objectiveEid
      map_object__show = false


[es(tag=gameClient, on_appear, track=(item__humanOwnerEid, item__containerOwnerEid), REQUIRE=item_for_extract_item_objective)]
def show_item_for_extracting_to_owner(evt : Event;
                                      item__containerOwnerEid : EntityId;
                                      item__humanOwnerEid : EntityId;
                                      item_for_objective__objectiveEid : EntityId;
                                      var map_object__show : bool&)
  query(item_for_objective__objectiveEid) <| $ [es] (objective__playerEid : EntityId;
                                                     objective__containerEid : EntityId;
                                                     objective__defaultContainerColor : E3DCOLOR)
    find_query() <| $ [es(REQUIRE=watchedByPlr)] (eid, possessedByPlr : EntityId)
      map_object__show = possessedByPlr == objective__playerEid && item__humanOwnerEid != eid
      if objective__containerEid != item__containerOwnerEid
        query(objective__containerEid) <| $[es] (var outline__color : E3DCOLOR&)
          outline__color = objective__defaultContainerColor
      return true
  query(item__containerOwnerEid) <| $ [es] (lootable_ri__objectiveEid : EntityId)
    if lootable_ri__objectiveEid == item_for_objective__objectiveEid
      map_object__show = false
require ecs
require ecs.common
require math.base
require math.random
require pathfinder
require strings
require DagorSystem
require DngNet
require game.es.objectives.objective_common
require game.es.objectives.objective_utils_common
require game.es.grav_zones_common
require game.es.ecs_common
require game.es.level_common
require game.es.ai.agent_position_mapping_common
require game.events.inventory_events
require game.events.events_active_matter
require DagorMath

let PLANT_ITEM_DYNAMIC_TARGET = "itemToPlant"

[es(tag=server, on_appear, REQUIRE=objectivePlantItem)]
def add_dynamic_target_to_plant_item_objective(evt : Event; var objective__params : Array)
  using() <| $(var obj : Object)
    obj |> set("name", "dynamicTargetTag")
    obj |> set("value", PLANT_ITEM_DYNAMIC_TARGET)
    objective__params |> push(obj)


[es(tag=server, on_event=EventPlayerFirstSpawn)]
def create_objective_item_on_spawn(evt : Event; eid aka player_eid, possessed : EntityId)
  query() <| $ [es] (objective__playerEid : EntityId;
                     eid aka objective_eid : EntityId;
                     objective__params : Array;
                     objective__itemTemplateNameInParams : string;
                     objective__additionalItemTemplate : string;
                     objective_spawn_item_on_spawn__radius : float2;
                     objective_spawn_item_on_spawn__attempts : int)
    if objective__playerEid == player_eid
      query(possessed) <| $ [es] (transform : float3x4)
        var attempts = objective_spawn_item_on_spawn__attempts
        var seed = int(uint(objective_eid))
        let grav = get_grav_dir(transform[3])
        let ax1 = get_normal(grav)
        let ax2 = cross(ax1, grav)
        while attempts-- > 0
          let horOffset = rnd_point_on_ring(seed, objective_spawn_item_on_spawn__radius.x, objective_spawn_item_on_spawn__radius.y)
          let pos = transform[3] - grav + ax1 * horOffset.x + ax2 * horOffset.y
          if attempts > objective_spawn_item_on_spawn__attempts / 2 //try to spawn the item in front of the player
            let player2Item = normalize(pos - transform[3] + grav)
            if dot(player2Item, transform[0]) < 0.3
              continue

          let mappingZone = navmesh_mapping_find_best_zone_for_position(pos)
          var poly : dtPolyRef
          var navPos = navmesh_map_position_in_zone(pos, mappingZone)
          if !project_to_nearest_navmesh_point(navPos, float3(2, 3, 2), poly)
            continue
          if !is_polygon_accessible(poly)
            continue
          navPos = navmesh_unmap_position_in_zone(navPos, mappingZone)
          validate_gameplay_position(navPos) <| $()
            return <- "mappingZone={mappingZone}"

          let itemTemplate = get_single_objective_item_from_params(objective__params, objective__itemTemplateNameInParams, objective_eid, player_eid)
          if empty(itemTemplate)
            return
          let templ = add_sub_template_name(itemTemplate, objective__additionalItemTemplate)
          createEntity(templ) <| $(init)
            var tm = IDENT_TM
            tm[3] = navPos
            init |> set("transform", tm)
            init |> set("item_for_objective__objectiveEid", objective_eid)
            init |> set("objective_dynamic_target__tag", PLANT_ITEM_DYNAMIC_TARGET)
          if !is_true_net_server()
            sendEvent(objective_eid, CmdAssignContainerForPlanting())
          return
        logerr("Failed to find pos to spawn item for objective. player:{player_eid}, objective: {getEntityTemplateName(objective_eid)}. Pos: {transform[3]}")


[es(tag=server, on_appear, on_event=(CmdAssignContainerForPlanting, EventRetriggerEntity), REQUIRE=objectivePlantItem)]
def init_plant_item_objective(evt : Event;
                              var objective__containerEid : EntityId&;
                              eid : EntityId;
                              objective__params : Array;
                              objective__playerEid : EntityId;
                              objective__additionalContainerTemplate : string;
                              objective__backupContainerTemplate : string;
                              objective__containerMinVolume : float;
                              objective__containerTypes : StringList)
  if objective__containerEid != INVALID_ENTITY_ID
    return
  if wake_me_up_when_objective_prerequisites_are_loaded(eid) //mostly needed offline
    return
  let validContainers <- gather_lootable_ri_for_objective(eid, objective__params, objective__containerTypes, objective__containerMinVolume)
  if length(validContainers) == 0
    //Note, this isn't necessarily a problem if it happens once.
    print("Failed to find suitable container for objective. player:{objective__playerEid}, objective: {getEntityTemplateName(eid)}.")
    objective__containerEid = create_backup_container_for_objective(objective__backupContainerTemplate, eid, objective__params)
    if objective__containerEid == INVALID_ENTITY_ID
      logerr("Failed to create backup container for objective. player:{objective__playerEid}, objective: {getEntityTemplateName(eid)}.")
    return

  let target = validContainers[grnd() % length(validContainers)]
  objective__containerEid = target
  query(target) <| $ [es] (var lootable_ri__objectiveEid : EntityId&; transform : float3x4; itemContainer__name : string)
    lootable_ri__objectiveEid = eid
    objectives_print_log("Player {objective__playerEid} is assigned container at {transform[3]} for {getEntityTemplateName(eid)}")
    remote_change_sub_template(target, "", objective__additionalContainerTemplate) <| $(init)
      init |> set("map_object_marker__tooltip", itemContainer__name)


[es(tag=server, REQUIRE=item_for_plant_item_objective)]
def track_plant_item_objective_when_items_moved(evt : EventOnMovingBetweenInventories; eid, item_for_objective__objectiveEid : EntityId)
  query(evt.newInventoryEid) <| $ [es] (lootable_ri__objectiveEid : EntityId)
    if lootable_ri__objectiveEid == item_for_objective__objectiveEid
      complete_progress_for_objective(item_for_objective__objectiveEid)
      destroyEntity(eid)


[es(tag=gameClient, REQUIRE=objectivePlantItem, track=objective__isCompleted)]
def hide_plant_item_contaier_once_complete(evt : Event; objective__containerEid : EntityId; objective__isCompleted : bool; objective__defaultContainerColor : E3DCOLOR)
  if objective__isCompleted
    query(objective__containerEid) <| $ [es] (var map_object__show : bool&;
                                              var outline__color : E3DCOLOR?)
      map_object__show = false
      if outline__color != null
        *outline__color = objective__defaultContainerColor


[es(tag=gameClient, on_appear, track=item__humanOwnerEid, REQUIRE=item_for_plant_item_objective)]
def show_item_for_planting_to_owner(evt : Event;
                                    item__humanOwnerEid : EntityId;
                                    item_for_objective__objectiveEid : EntityId;
                                    var map_object__show : bool&)
  query(item_for_objective__objectiveEid) <| $ [es] (objective__playerEid : EntityId)
    find_query() <| $ [es(REQUIRE=watchedByPlr)] (eid, possessedByPlr : EntityId)
      map_object__show = possessedByPlr == objective__playerEid && item__humanOwnerEid != eid
      return true
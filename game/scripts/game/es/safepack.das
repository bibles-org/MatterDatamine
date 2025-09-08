require ecs
require net
require ecs.safe
require math.base
require game.events.events_game
require game.events.events_active_matter
require game.es.item_equip_common
require game.es.endgame_common
require game.es.message_queue_common
require game.es.inventory_drop_common
require game.es.chronotrace_progress_track_common
require active_matter.game.es.objectives.objective_common


struct SaveSafepackItemsAction
  session_id : string
  itemsList : array<BattleResultItem>
  safepackEid : int
  battleAreaInfo : BattleAreaInfo


[es(tag=server, REQUIRE_NOT=(nexus_militant, uniqueId), before=damage_model_hp_death_es, on_event=(EventEntityDied, CmdTriggerSafepackDrop))]
def save_safepack_items(evt : Event;
                        possessedByPlr : EntityId;
                        militant_extra_inventories__safepackEid : EntityId;
                        transform : float3x4;
                        human_inventory__dropLootOffset = float3(0))
  query(militant_extra_inventories__safepackEid) <| $ [es] (itemContainer : EidList)
    for itemEid in itemContainer
      query(itemEid) <| $[es] (var item__humanOwnerEid : EntityId&)
        item__humanOwnerEid = INVALID_ENTITY_ID
      let forObjective = is_item_collected_for_some_objective(itemEid)
      if !!forObjective
        reserve_progress_for_objective(forObjective)
      else
        find_query() <| $[es] (eid aka objective_eid : EntityId;
                               objective__playerEid : EntityId)
          if objective__playerEid == possessedByPlr
            if check_is_item_for_collect_objective(itemEid, objective_eid)
              if reserve_progress_for_objective(objective_eid) > 0
                return true
          return false

  query(possessedByPlr) <| $ [es] (userid : uint64; var player__chronotracesProgression : Object)
    var safepackItems : array<BattleResultItem>
    save_inventory(militant_extra_inventories__safepackEid, safepackItems)
    if empty(safepackItems)
      print("[SAFEPACK] Empty safepack, nothing to safe")
      return

    for item in safepackItems
      if item.isCreatedByZone && !empty(item.templateName)
        item_add_progress(player__chronotracesProgression, item.templateName, "extract")

    let data <- SaveSafepackItemsAction(
      session_id = string(get_session_id()),
      itemsList <- safepackItems,
      safepackEid = int(uint(militant_extra_inventories__safepackEid)),
      battleAreaInfo <- get_battle_area_info()
    )

    print("[SAFEPACK] {data}")
    sendToProfileServer("save_safepack_items", userid, data)

  query(militant_extra_inventories__safepackEid) <| $ [es] (safepack__remainsTemplate : string;
                                                            safepack__destroyEffect : string)
    var tm = IDENT_TM
    tm[3] = transform * human_inventory__dropLootOffset
    drop_item_on_ground(tm)
    // spawn remains
    create_item_on_ground(safepack__remainsTemplate, tm)
    // spawn effect
    createEntity(safepack__destroyEffect) <| $(var init)
      init |> set("transform", tm)

  destroyEntity(militant_extra_inventories__safepackEid)

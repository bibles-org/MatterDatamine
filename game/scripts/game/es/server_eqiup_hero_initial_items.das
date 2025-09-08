require ecs
require ecs.safe
require ecs.common
require DagorSystem
require game.es.item_equip_common
require game.es.onboarding_common
require game.es.ecs_common
require game.events.events_active_matter


[es(tag=server, track=(possessed, player__loadoutRecieved), REQUIRE=player)]
def equip_hero_initial_items(evt : Event;
                             possessed : EntityId;
                             player__loadoutRecieved : bool;
                             var initialHeroItems : Array&)
  if !player__loadoutRecieved || possessed == INVALID_ENTITY_ID // no data / hero => no process
    return
  if is_onboarding() // in onboarding hero loadout is created via onboarding_set_hero_loadout template
    return
  if length(initialHeroItems) > 0 && !has(possessed, "ignore_initial_items")
    print("[Apply Initial Items] Equip {length(initialHeroItems)} items to possessed <{possessed}>.")
    load_items(initialHeroItems, possessed)

    let itemsLen = initialHeroItems |> length()
    for i in range(itemsLen)
      let idx = (itemsLen - 1)  - i
      var itemObj = getRW_ecs_object(initialHeroItems[idx])
      if itemObj != null
        let templateName = (*itemObj).templateName ?? ""
        let itemTemplate = getOrBuildTemplateByName(templateName)
        if itemTemplate != null && templateHasComponent(*itemTemplate, "item__permanentItem")
          continue
      initialHeroItems |> erase(idx)


[es(tag=server, on_appear)]
def initial_loadout_creation_to_hero(evt : Event;
                                     eid : EntityId;
                                     var initial_loadout_creation__items : Array;
                                     var initial_loadout_creation__itemsMap : Object&;
                                     player_on_base_components__stashEid = INVALID_ENTITY_ID)
  using() <| $(var uncreatedItems : Array)
    for item in initial_loadout_creation__items
      let itemObject = get_ecs_object(item)
      if itemObject != null
        if !load_item(*itemObject, eid, initial_loadout_creation__itemsMap, player_on_base_components__stashEid)
          uncreatedItems |> push(item)

    initial_loadout_creation__items |> clear()
    initial_loadout_creation__items := uncreatedItems


[es(tag=server, on_appear)]
def equip_landing_equipment_to_hero(evt : Event;
                                    initial_loadout_item__managerEid : EntityId)
  query(initial_loadout_item__managerEid) <| $ [es] (var initial_loadout_creation__items : Array&;
                                                     var initial_loadout_creation__itemsMap : Object&;
                                                     player_on_base_components__stashEid = INVALID_ENTITY_ID)
    using() <| $(var uncreatedItems : Array)
      for item in initial_loadout_creation__items
        let itemObject = get_ecs_object(item)
        if itemObject != null
          if !load_item(*itemObject, initial_loadout_item__managerEid, initial_loadout_creation__itemsMap,
                        player_on_base_components__stashEid)
            uncreatedItems |> push(item)

      initial_loadout_creation__items |> clear()
      initial_loadout_creation__items := uncreatedItems


[es(tag=server, no_order, REQUIRE_NOT=(item_waiting_for_container_appear, weapon_waiting_for_hero_appear,
    equipment_waiting_for_hero_appear, weapon_mod_waiting_for_weapon_appear, equipment_mod_waiting_for_equipment_appear))]
def initial_loadout_item_update(act : UpdateStageInfoAct;
                                eid : EntityId;
                                initial_loadout_item__managerEid : EntityId;
                                initial_loadout_item__slotName : string;
                                initial_loadout_item__parentEid : EntityId)
  query(initial_loadout_item__managerEid) <| $ [es] (player_on_base_components__stashEid = INVALID_ENTITY_ID)
    if check_item_attached_to_parent(eid, initial_loadout_item__managerEid, initial_loadout_item__parentEid,
                                     player_on_base_components__stashEid, initial_loadout_item__slotName)
      eid |> removeSubTemplate("initial_loadout_item")


[es(tag=server, on_disappear)]
def initial_loadout_item_disappear(evt : Event;
                                   initial_loadout_item__managerEid : EntityId)
  query(initial_loadout_item__managerEid) <| $ [es] (var initial_loadout_creation__totalItems : int&;
                                                     hero : Tag const?)
    initial_loadout_creation__totalItems -= 1

    if initial_loadout_creation__totalItems == 0
      initial_loadout_item__managerEid |> removeSubTemplate("initial_loadout_creation")
      initial_loadout_item__managerEid |> removeSubTemplate("equipped_bot")
      initial_loadout_item__managerEid |> removeSubTemplate("equipped_bot_female")

      if hero != null
        find_query() <| $ [es] (var player_profile__disableTransaction : bool&)
          player_profile__disableTransaction = false
          return true


[es(tag=server, no_order)]
def initial_loadout_creation_check_state(act : UpdateStageInfoAct;
                                         eid : EntityId;
                                         possessedByPlr : EntityId;
                                         initial_loadout_creation__totalItems : int;
                                         initial_loadout_creation__items : Array;
                                         initial_loadout_creation__itemsMap : Object;
                                         initial_loadout_creation__totalWaitTime : float;
                                         var initial_loadout_creation__currentWaitTime : float&;
                                         player_on_base_components__stashEid = INVALID_ENTITY_ID)
  initial_loadout_creation__currentWaitTime += act.dt
  if initial_loadout_creation__currentWaitTime < initial_loadout_creation__totalWaitTime
    return

  eid |> removeSubTemplate("initial_loadout_creation")

  let onBase = player_on_base_components__stashEid != INVALID_ENTITY_ID
  logerr("[Item Equipment] too long waiting for initial loadout creation of {get_entity_info(eid)}. initial_loadout_creation__totalItems = {initial_loadout_creation__totalItems} ; initial_loadout_creation__items = {length(initial_loadout_creation__items)}.")

  // collect all unloaded items
  for item in initial_loadout_creation__itemsMap
    let itemEid = get_Eid(item.value) ?? INVALID_ENTITY_ID
    query(itemEid) <| $ [es] (initial_loadout_item__slotName : string;
                              initial_loadout_item__parentEid : EntityId)
      if !check_item_attached_to_parent(itemEid, eid, initial_loadout_item__parentEid,
                                        player_on_base_components__stashEid, initial_loadout_item__slotName)
        logerr("[Item Equipment] item {get_entity_info(itemEid)} was not attached: parent = {get_entity_info(initial_loadout_item__parentEid)} ; hero = {get_entity_info(eid)} ; slot = {initial_loadout_item__slotName}.")
        if onBase // cause we will force load profile
          destroyEntity(itemEid)
      else
        logerr("[Item Equipment] item {get_entity_info(itemEid)} was attached, but initial_loadout_item_disappear has not proccessed yet.")
  for item in initial_loadout_creation__items
    let itemObject = get_ecs_object(item)
    let itemId = get_string(*itemObject, "itemId", "-1")
    let itemTemplate = get_string(*itemObject, "templateName", "")
    logerr("[Item Equipment] item {itemId} <{itemTemplate}> was not created: hero = {get_entity_info(eid)}.
itemObject={itemObject}")
  if onBase
    sendEvent(possessedByPlr, CmdForceLoadProfile())


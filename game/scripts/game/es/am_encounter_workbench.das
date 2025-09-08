require app
require DagorSystem
require daslib/algorithm
require ecs
require ecs.common
require ecs.safe
require game.utils.net_utils
require game.es.inventory_drop_common
require math.base
require math.random
require net
require strings

require game.events.events_active_matter
require game.events.events_game
require game.events.events


[es(tag=server, on_appear)]
def encounter_workbench_init(evt : Event;
                             transform aka workbench_transform : float3x4;
                             encounter_workbench__bonusLootTms : Array;
                             encounter_workbench__bonusLootTemplates : Array;
                             encounter_workbench__initialCharges : int2;
                             var encounter_workbench__charges : int&)
  var bonusLootTotalWeight = 0.0
  for bonusLootTemplateData in encounter_workbench__bonusLootTemplates
    bonusLootTotalWeight += (bonusLootTemplateData as Object)?.weight ?? 0.0

  for bonusLootTm in encounter_workbench__bonusLootTms
    let tm = bonusLootTm ?? IDENT_TM
    let rnd = rnd_float(0.0, bonusLootTotalWeight)
    var weight = 0.0
    for bonusLootTemplateData in encounter_workbench__bonusLootTemplates
      weight += (bonusLootTemplateData as Object)?.weight ?? 0.0
      if weight >= rnd
        let bonusLootTemplateName = (bonusLootTemplateData as Object)?["template"] ?? ""
        let bonusLootTemplate = getTemplateByName(bonusLootTemplateName)
        if bonusLootTemplate != null
          let dropTm = get_item_template_drop_tm(*bonusLootTemplate)
          createEntity("{bonusLootTemplateName}+item_in_world") <| $ [es] (var init : ComponentsInitializer)
            init |> set("transform", workbench_transform * tm * dropTm)
        break

  encounter_workbench__charges = rnd_int(encounter_workbench__initialCharges)


[es(tag=server, on_appear)]
def encounter_corrupted_workbench_init(evt : Event;
                                       eid : EntityId;
                                       transform aka workbench_transform : float3x4;
                                       encounter_corrupted_workbench__corruptionTemplate : string;
                                       var encounter_corrupted_workbench__corruptionEid : EntityId&)
  assume corruptionTemplate = encounter_corrupted_workbench__corruptionTemplate
  assume corruptionEid = encounter_corrupted_workbench__corruptionEid
  if corruptionTemplate != ""
    corruptionEid = createEntity(corruptionTemplate) <| $ [es] (var init : ComponentsInitializer)
      init |> set("transform", workbench_transform)
      init |> set("ownerEid", eid)


[es(tag=server, track=transform)]
def encounter_corrupted_workbench_track_transform(evt : Event;
                                                  transform aka workbench_transform : float3x4;
                                                  encounter_corrupted_workbench__corruptionEid : EntityId)
  query(encounter_corrupted_workbench__corruptionEid) <| $ [es] (var transform aka corruption_transform : float3x4)
    corruption_transform = workbench_transform


[es(tag=server)]
def encounter_corrupted_workbench_clear_action(evt : CmdUse;
                                               encounter_corrupted_workbench__corruptionEid : EntityId;
                                               var encounter_corrupted_workbench__corruptionCleanersInfo : Object
                                               )
  assume corruptionEid = encounter_corrupted_workbench__corruptionEid

  query(corruptionEid) <| $ [es] (encounter_workbench_corruption__amPerNode : int;
                                  composit_holder__childrenEids : EidList;
                                  var encounter_workbench_corruption_cleaning__amCount : int?;
                                  var encounter_workbench_corruption_cleaning__cleanerHero : EntityId?)
    let corruptedNodesCount = length(composit_holder__childrenEids)
    var cleanPrice = encounter_workbench_corruption__amPerNode * corruptedNodesCount
    cleanPrice -= encounter_workbench_corruption_cleaning__amCount ?? 0
    if cleanPrice <= 0
      return

    query(evt.requesterEid) <| $ [es(REQUIRE_NOT=deadEntity)] (am_storage__value : int;
                                                               possessedByPlr : EntityId)
      if am_storage__value <= 0
        return
      let amToUse = min(am_storage__value, cleanPrice)
      sendEventImmediate(evt.requesterEid, CmdChangeActiveMatterBalance(change = -amToUse, reason = "encounter_corrupted_workbench_clear_action"))

      let playerEidKey = "{possessedByPlr}"
      var playerStats = encounter_corrupted_workbench__corruptionCleanersInfo |> getRW_child(playerEidKey) ?as Object
      if playerStats == null
        using() <| $(var newStats : Object)
          newStats |> set("amSpentOnCleanup", amToUse)
          encounter_corrupted_workbench__corruptionCleanersInfo |> set(playerEidKey, newStats)
      else
        *playerStats |> set("amSpentOnCleanup", amToUse + playerStats?.amSpentOnCleanup ?? 0)

      if encounter_workbench_corruption_cleaning__amCount == null
        addSubTemplate(corruptionEid, "encounter_workbench_corruption_cleaning") <| $ [es] (var init : ComponentsInitializer)
          init |> set("encounter_workbench_corruption_cleaning__amCount", amToUse)
          init |> set("encounter_workbench_corruption_cleaning__cleanerHero", evt.requesterEid)
      else
        *encounter_workbench_corruption_cleaning__amCount += amToUse
        *encounter_workbench_corruption_cleaning__cleanerHero = evt.requesterEid


[es(tag=server, on_appear)]
def encounter_workbench_corruption_cleaning_init(evt : Event;
                                                 encounter_workbench_corruption_cleaning__timePerAm : float;
                                                 var encounter_workbench_corruption_cleaning__updateAt : float&)
  encounter_workbench_corruption_cleaning__updateAt = get_sync_time() + encounter_workbench_corruption_cleaning__timePerAm


[es(tag=server, no_order)]
def encounter_workbench_corruption_cleaning_update(act : UpdateStageInfoAct;
                                                   eid : EntityId;
                                                   ownerEid : EntityId;
                                                   encounter_workbench_corruption_cleaning__timePerAm : float;
                                                   encounter_workbench_corruption_cleaning__cleanerHero : EntityId;
                                                   var encounter_workbench_corruption_cleaning__updateAt : float&;
                                                   var encounter_workbench_corruption_cleaning__amCount : int&;
                                                   var composit_holder__childrenEids : EidList)
  if act.curTime < encounter_workbench_corruption_cleaning__updateAt
    return

  if encounter_workbench_corruption_cleaning__amCount > 0
    --encounter_workbench_corruption_cleaning__amCount
    encounter_workbench_corruption_cleaning__updateAt = get_sync_time() + encounter_workbench_corruption_cleaning__timePerAm
    if encounter_workbench_corruption_cleaning__amCount == 0
      removeSubTemplate(eid, "encounter_workbench_corruption_cleaning")

    let nodesCount = length(composit_holder__childrenEids)
    if nodesCount > 0
      let childEid = composit_holder__childrenEids[nodesCount - 1]
      query(childEid) <| $ [es] (transform aka corruption_transform : float3x4)
        send_net_event(ownerEid, EventWorkbenchCorruptionBlockRemoved(pos = corruption_transform[3]))
      destroyEntity(childEid)
      composit_holder__childrenEids |> erase(nodesCount - 1)
      if length(composit_holder__childrenEids) == 0
        sendEvent(encounter_workbench_corruption_cleaning__cleanerHero, EventCorruptedWorkbenchCleaned())
        query(ownerEid) <| $ [es] (var encounter_corrupted_workbench__cleaned : bool&)
          encounter_corrupted_workbench__cleaned = true


def update_encounter_workbench_decor(workbench_eid : EntityId)
  query(workbench_eid) <| $ [es] (transform aka workbench_transform : float3x4;
                                  encounter_workbench__activeStateDecor : Array;
                                  encounter_corrupted_workbench__cleaned : bool = true;
                                  encounter_workbench__charges : int;
                                  var encounter_workbench__activeStateDecorEids : EidList;
                                  var composit_holder__childrenEids : EidList)
    let decorRequired = encounter_corrupted_workbench__cleaned && encounter_workbench__charges > 0
    let decorExists = length(encounter_workbench__activeStateDecorEids) > 0

    if decorRequired && !decorExists
      for decorData in encounter_workbench__activeStateDecor
        let decorObj = decorData as Object
        let decorTemplate = decorObj?["template"] ?? ""
        if decorTemplate == ""
          logerr("{workbench_eid}<{getEntityTemplateName(workbench_eid)}>: encounter_workbench__activeStateDecor contains empty template!")
          continue

        let localTm = decorObj?.tm ?? IDENT_TM
        let decorEid = createEntity("{decorTemplate}+transform_attached") <| $ [es] (var init : ComponentsInitializer)
          init |> set("transform", workbench_transform * localTm)
          init |> set("transform_attached__entityEid", workbench_eid)
          init |> set("transform_attached__localTm", localTm)
        composit_holder__childrenEids |> push(decorEid)
        encounter_workbench__activeStateDecorEids |> push(decorEid)

      query() <| $ [es] (eid aka item_eid : EntityId;
                         item_on_corrupted_workbench__workbenchEid : EntityId;
                         transform aka item_transform : float3x4)
        if item_on_corrupted_workbench__workbenchEid == workbench_eid
          let itemTemplateName = getEntityTemplateName(item_eid) |> replace("item_on_corrupted_workbench", "item_in_world")
          destroyEntity(item_eid)
          createEntity(itemTemplateName) <| $(var init : ComponentsInitializer)
            init |> set("transform", item_transform)
    elif !decorRequired && decorExists
      for activeStateDecorEid in encounter_workbench__activeStateDecorEids
        let childIdx = composit_holder__childrenEids |> find_index(activeStateDecorEid)
        if childIdx >= 0
          composit_holder__childrenEids |> erase(childIdx)
        destroyEntity(activeStateDecorEid)
      encounter_workbench__activeStateDecorEids |> clear()


[es(tag=server, on_appear, track=encounter_workbench__charges,
  REQUIRE=encounter_workbench__charges)]
def encounter_workbench_update_decor(evt : Event;
                                     eid aka workbench_eid : EntityId)
  update_encounter_workbench_decor(workbench_eid)


[es(tag=server, on_appear, track=encounter_corrupted_workbench__cleaned,
  REQUIRE=encounter_corrupted_workbench__cleaned)]
def encounter_corrupted_workbench_update_decor(evt : Event;
                                               eid aka workbench_eid : EntityId)
  update_encounter_workbench_decor(workbench_eid)


def encounter_workbench_craft(recipes : Object;
                              workbench_eid : EntityId;
                              hero_eid : EntityId;
                              resultTm : float3x4)
  let requiredCharges = recipes.requiredCharges ?? 0
  var workbenchCharges = 0
  query(workbench_eid) <| $ [es] (encounter_workbench__charges : int)
    workbenchCharges = encounter_workbench__charges

  if requiredCharges > workbenchCharges
    send_net_event(hero_eid, ShowStatusTip(statusTip = "status_tip_workbench_not_enough_charges"))
    return

  // resultEvent
  let resultEvent = recipes.resultEvent ?? ""

  // requiredItems
  let requiredItems = recipes.requiredItems ?as Array
  if (requiredItems == null || *requiredItems |> length() == 0) && resultEvent == ""
    logerr("expected a `requiredItems` array or `resultEvent` string, but got nothing")

  var requiredItemsTbl : table<string; int>
  if requiredItems != null
    for itemChild in *requiredItems
      let item = itemChild as Object
      if item == null
        logerr("could not get an `item` from `requiredItems`")
      let templ = item?["template"] ?? ""
      let count = item.count ?? 0
      if empty(templ) || count == 0
        logerr("every item in `requiredItems` should have non-empty `template` and `count` fields")
      if requiredItemsTbl |> key_exists(templ)
        logerr("the `{templ}` already exists in `requiredItemsTbl`")
      requiredItemsTbl.insert(templ, count)

  // resultItems
  let resultItems = recipes.resultItems ?as Array
  if (resultItems == null || *resultItems |> length() == 0) && resultEvent == ""
    logerr("expected a `resultItems` array or `resultEvent` string, but got nothing")
    return

  var usedItemIndices : array<int>
  var usedItems : array<EntityId>
  var createdItems : array<EntityId>

  var haveAllRequiredItems = false
  query(hero_eid) <| $ [es] (itemContainer : EidList)
    for idx, itemEid in iter_range(itemContainer), itemContainer
      let itemTemplate = getEntityTemplateName(itemEid)
      for templ, count in keys(requiredItemsTbl), values(requiredItemsTbl)
        let found = itemTemplate |> find(templ)
        if count == 0 || found == -1
          continue
        usedItemIndices |> push(idx)
        usedItems |> push(itemEid)
        count--

    haveAllRequiredItems = true
    for count in values(requiredItemsTbl)
      haveAllRequiredItems &&= count == 0

  if !haveAllRequiredItems
    if (resultItems != null && *resultItems |> length() > 0)
      send_net_event(hero_eid, ShowStatusTip(statusTip = "status_tip_workbench_not_enough_items_craft"))
    else
      send_net_event(hero_eid, ShowStatusTip(statusTip = "status_tip_workbench_not_enough_items"))
    return

  query(workbench_eid) <| $ [es] (var encounter_workbench__charges : int&)
    encounter_workbench__charges -= requiredCharges

  if resultItems != null
    var resultItemsTbl : table<string; int>
    for itemChild in *resultItems
      let item = itemChild as Object
      if item == null
        logerr("could not get an `item` from `resultItems`")
        return
      let templ = item?["template"] ?? ""
      let count = item.count ?? 0
      if empty(templ) || count == 0
        logerr("every item in `resultItems` should have non-empty `template` and `count` fields")
        return
      if getTemplateByName(templ) == null
        logerr("template {templ} does not exist")
        return
      if resultItemsTbl |> key_exists(templ)
        logerr("the `{templ}` already exists in `resultItemsTbl`")
        return
      resultItemsTbl.insert(templ, count)

    for templ, count in keys(resultItemsTbl), values(resultItemsTbl)
      for _ in range(count)
        // There is a pass above that checks that all result items are valid before entities are created/destroyed.
        // The following code simply dereferences without any validation.
        let templId = getTemplateByName(templ)
        let itemName = getTemplateComponent(*templId, "item__name") ?? "undefined"
        let key = "encounter/workbench_item_created"

        let itemEid = createEntity("{templ}+item_in_world") <| $(var init : ComponentsInitializer)
          let dropTm = *templId |> get_item_template_drop_tm()
          init |> set("transform", resultTm * dropTm)

        createdItems |> push(itemEid)

        using() <| $(var data : Object)
          data |> set("item", itemName)
          send_net_event(hero_eid, CmdHeroLogExEvent(event = "", key = key, data = ecs_addr(data)), target_entity_conn(hero_eid))

  using() <| $(var data : Object)
    using() <| $(var usedItemsList : EidList)
      usedItemsList |> resize(length(usedItems))
      for usedItemInList, usedItem in usedItemsList, usedItems
        usedItemInList = usedItem
      data |> set("usedItems", usedItemsList)
    using() <| $(var createdItemsList : EidList)
      createdItemsList |> resize(length(createdItems))
      for createdItemInList, createdItem in createdItemsList, createdItems
        createdItemInList = createdItem
      data |> set("createdItems", createdItemsList)

    if resultEvent != ""
      // Send immediate before used items destruction
      sendEventImmediate(workbench_eid, CmdWorkbenchResultEvent(name := resultEvent, heroEid = hero_eid, data = ecs_addr(data)))

      // Notify clients
      send_net_event(workbench_eid, EventWorkbenchResultEvent(name := resultEvent, heroEid = hero_eid, data = ecs_addr(data)))

    // Delete / destroy
    query(hero_eid) <| $ [es] (itemContainer : EidList)
      for itemIdx in usedItemIndices
        destroyEntity(itemContainer[itemIdx])

    if length(createdItems) > 0
      send_net_event(workbench_eid, EventWorkbenchItemsCreated(heroEid = hero_eid, data = ecs_addr(data)))


def encounter_workbench_repair_item(workbench_eid : EntityId;
                                    hero_eid : EntityId;
                                    item_eid : EntityId)
  let requiredCharges = 1
  var workbenchCharges = 0
  query(workbench_eid) <| $ [es] (encounter_workbench__charges : int)
    workbenchCharges = encounter_workbench__charges

  if requiredCharges > workbenchCharges
    send_net_event(hero_eid, ShowStatusTip(statusTip = "status_tip_workbench_not_enough_charges"))
    return

  var repaired = false
  query(item_eid) <| $ [es] (item__maxHp : float;
                             var item__hp : float&)
    if item__hp < item__maxHp
      item__hp = item__maxHp
      repaired = true

  if !repaired
    return

  query(workbench_eid) <| $ [es] (var encounter_workbench__charges : int&)
    encounter_workbench__charges -= requiredCharges

  send_net_event(workbench_eid, EventWorkbenchItemRepaired(heroEid = hero_eid, itemEid = item_eid))


[es(tag=gameClient, on_appear, track=encounter_workbench__charges)]
def encounter_workbench_interaction_menu_header(evt : Event;
                                                encounter_workbench__charges : int;
                                                encounter_workbench__maxCharges : int;
                                                var interaction_menu_header : Array)
  interaction_menu_header |> clear()

  using() <| $(var object : Object)
    object |> set("icon", "")
    object |> set("loc", "hud/workbench_charges_hint")

    using() <| $(var loc_param_object : Object)
      loc_param_object |> set("charges", encounter_workbench__charges)
      loc_param_object |> set("maxCharges", encounter_workbench__maxCharges)
      object |> set("locParam", loc_param_object)

    interaction_menu_header |> push(object)


[es(tag=gameClient, on_appear)]
def encounter_workbench_interaction_menu(evt : Event;
                                         encounter_workbench_crafts : Array;
                                         var interaction_menu : Array)
  for recipeChild, idx in encounter_workbench_crafts, iter_range(encounter_workbench_crafts)
    let recipe = recipeChild as Object
    if recipe == null
      logerr("The recipe must be an instance of an Object")
      continue

    using() <| $(var object : Object)
      object |> set("icon", recipe?.icon ?? "")
      object |> set("loc", recipe?.loc ?? "")
      object |> set("action", "craft")
      object |> set("enabled", false)
      object |> set("closeInteraction", recipe?.closeInteraction ?? true)
      // todo: use enabled to show, that there is enough items to craft

      using() <| $(var action_param_object : Object)
        action_param_object |> set("recipeIdx", idx)
        object |> set("actionParam", action_param_object)

      interaction_menu |> push(object)

[es(tag=gameClient, on_appear, track=encounter_corrupted_workbench__cleaned)]
def encounter_workbench_interaction_menu_enable(evt : Event;
                                                encounter_corrupted_workbench__cleaned : bool;
                                                var interaction_menu_available : bool&)
  interaction_menu_available = encounter_corrupted_workbench__cleaned


[es(tag=server)]
def encounter_workbench_on_menu_action(evt : RequestInteractionMenuAction;
                                       eid : EntityId;
                                       encounter_workbench_crafts : Array;
                                       transform : float3x4;
                                       encounter_workbench__craftResultTm : float3x4)
  if evt.action != "craft" || evt.actionParam == null
    return
  let idx = (*evt.actionParam).recipeIdx ?? 0

  let recipesChild = encounter_workbench_crafts?[idx]
  if recipesChild == null
    logerr("{eid}<{getEntityTemplateName(eid)}>: the idx({idx}) is not within the encounter_workbench_crafts {length(encounter_workbench_crafts)} array")
    return

  let recipes = *recipesChild as Object

  if recipes == null
    logerr("{eid}<{getEntityTemplateName(eid)}>: recipes is null")
    return

  let resultTm = transform * encounter_workbench__craftResultTm
  encounter_workbench_craft(*recipes, eid, evt.heroEid, resultTm)


[es(tag=server)]
def encounter_workbench_on_repair_item_action(evt : RequestEncounterWorkbenchRepairItemAction;
                                              eid aka workbench_eid : EntityId)
  encounter_workbench_repair_item(workbench_eid, evt.heroEid, evt.itemEid)


[es(tag=server)]
def encounter_workbench_on_result_event(evt : CmdWorkbenchResultEvent;
                                        encounter_workbench__maxCharges : int;
                                        var encounter_workbench__charges : int&)
  if evt.name == "battery"
    let usedItems = get_ecs_EidList(evt.data.usedItems)
    if usedItems != null
      for usedItemEid in *usedItems
        query(usedItemEid) <| $ [es] (item__amount : int)
          encounter_workbench__charges = min(encounter_workbench__maxCharges,
                                             encounter_workbench__charges + item__amount)

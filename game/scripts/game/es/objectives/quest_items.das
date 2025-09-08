require ecs
require ecs.common
require ecs.safe
require DagorSystem
require game.es.inventory_item_common
require game.es.inventory_checks_common
require player
require game.es.objectives.objective_common
require game.events.events
require game.events.events_active_matter
require game.events.player_events
require game.events.inventory_events
require game.events.events_game


struct QuestItem
  templateName : string
  objectives : array<EntityId>


def destroy_quest_item(item_eid : EntityId)
  query(item_eid) <| $ [es] (var quest_item__playerEid : EntityId&)
    quest_item__playerEid = INVALID_ENTITY_ID // Entity removal is not instantaneous. That's why we unbind it from the player
    destroyEntity(item_eid)


def is_player_already_has_included_quest_items(player_eid : EntityId)
  return find_query() <| $ [es(REQUIRE=includedQuestItem)] (quest_item__playerEid : EntityId)
    return player_eid == quest_item__playerEid


[es(tag=server, after=player_possess)]
def create_included_quest_items_for_hero(evt : PossessTargetByPlayer;
                                         eid aka player_eid : EntityId;
                                         possessed : EntityId)

  if is_player_already_has_included_quest_items(player_eid)
    return

  var questItemsForCreation : array<QuestItem>
  reserve(questItemsForCreation, 3)

  for_each_player_active_objective(player_eid) <| $(objective_eid : EntityId)

    query(objective_eid) <| $ [es] (objective__params : Array;
                                    objective__questItemTemplateNameInParams : string)

      var questItemTemplates : array<string>
      collect_objective_param_values_by_name(objective__params, objective__questItemTemplateNameInParams, questItemTemplates)
      if empty(questItemTemplates)
        return

      for questItemTemplate in questItemTemplates

        let tmpl = getTemplateByName(questItemTemplate)
        if tmpl == null
          logerr("[Quest Items] Quest item template {questItemTemplate} does not exist")
          continue

        let isSingletonQuestItem = templateHasComponent(*tmpl, "singletonQuestItem")
        if isSingletonQuestItem
          var isSimilarQuestItemFound = false

          for questItemForCreation in questItemsForCreation
            if questItemForCreation.templateName == questItemTemplate
              push(questItemForCreation.objectives, objective_eid)
              print("[Quest Items] Link singleton included quest item <{questItemTemplate}> for player {player_eid} with objective <{getEntityTemplateName(objective_eid)}>")
              isSimilarQuestItemFound = true
              break

          if isSimilarQuestItemFound
            continue

        print("[Quest Items] Creating included quest item <{questItemTemplate}> for player {player_eid} for objective <{getEntityTemplateName(objective_eid)}>")

        emplace(questItemsForCreation, QuestItem(
          templateName = questItemTemplate,
          objectives <- [ objective_eid]
        ))


  for questItem in questItemsForCreation
    create_quest_item_in_container(questItem.templateName, possessed, player_eid, questItem.objectives)


[es(tag=server, REQUIRE=itemContainer)]
def create_discovered_items_for_player(evt : EventQuestStaticTargetAssigned;
                                       eid aka container_eid : EntityId;
                                       container_target__discoveredItemTemplates : StringList;
                                       var container_target__generatedForPlayers : EidList&)
  if has_value(container_target__generatedForPlayers, evt.playerEid)
    return

  push(container_target__generatedForPlayers, evt.playerEid)

  print("[Quest Items] Creating discovered quest items for player {evt.playerEid}")
  for itemTemplate in container_target__discoveredItemTemplates
    create_quest_item_in_container(string(itemTemplate), container_eid, evt.playerEid, [ evt.objectiveEid])


[es(tag=server, on_event=EventEntityDied)]
def destroy_included_quest_items_on_player_death(evt : Event;
                                                 possessedByPlr : EntityId)
  print("[Quest Items] Destroying all included quest items on death for player {possessedByPlr}")
  query() <| $ [es(REQUIRE=includedQuestItem)] (eid aka item_eid, quest_item__playerEid : EntityId)
    if quest_item__playerEid == possessedByPlr
      destroy_quest_item(item_eid)


[es(tag=server, track=item__humanOwnerEid, REQUIRE=discoveredQuestItem)]
def change_accessibility_for_quest_item(evt : Event;
                                        eid aka item_eid : EntityId;
                                        item__humanOwnerEid : EntityId;
                                        quest_item__playerEid : EntityId;
                                        quest_item__objectiveEids : EidList;
                                        var quest_item__canBeTakenByAll : bool&)
  if quest_item__canBeTakenByAll
    query(quest_item__playerEid) <| $[es] (possessed : EntityId)
      if possessed != item__humanOwnerEid
        var isSecretQuest = false
        for objective in quest_item__objectiveEids
          isSecretQuest ||= has(objective, "secretObjective")
        if !isSecretQuest
          createEntity("game_effect_recreate_discovered_quest_item") <| $(var init)
            init |> set("game_effect__attachedTo", item_eid)
      else
        find_query() <| $[es(REQUIRE=game_effect_recreate_discovered_quest_item)] (eid aka game_effect_eid : EntityId;
                                                                                   game_effect__attachedTo : EntityId;
                                                                                   var game_effect__recreateDiscoveredQuestItem : bool&)
          if game_effect__attachedTo == item_eid
            game_effect__recreateDiscoveredQuestItem = false
            destroyEntity(game_effect_eid)
            return true
          return false
  else
    quest_item__canBeTakenByAll = true


[es(tag=server, on_disappear, REQUIRE=game_effect_recreate_discovered_quest_item)]
def create_new_discovered_quest_item(evt : Event;
                                     game_effect__recreateDiscoveredQuestItem : bool;
                                     game_effect__attachedTo : EntityId)
  if !game_effect__recreateDiscoveredQuestItem
    return
  query(game_effect__attachedTo) <| $[es] (var quest_item__playerEid : EntityId&;
                                           var quest_item__objectiveEids : EidList&)
    find_query() <| $[es] (eid aka container_eid : EntityId;
                           container_target__generatedForPlayers : EidList;
                           container_target__discoveredItemTemplates : StringList)
      for player in container_target__generatedForPlayers
        if player != quest_item__playerEid
          continue
        let dropItemTemplate = split_template(getEntityTemplateName(game_effect__attachedTo))[0]
        for itemTemplate in container_target__discoveredItemTemplates
          if itemTemplate != dropItemTemplate
            continue
          print("[Quest Items] Rereating discovered quest item ({itemTemplate}) for player {quest_item__playerEid}")
          var objectives : array<EntityId>
          for objective in quest_item__objectiveEids
            objectives |> push(objective)
          create_quest_item_in_container(string(itemTemplate), container_eid,
            quest_item__playerEid, objectives)
          return true
      return false
    quest_item__objectiveEids |> clear()
    quest_item__playerEid = INVALID_ENTITY_ID

require ecs
require DngNet
require math.random
require game.es.objectives.objective_common
require DagorSystem
require game.events.events
require game.events.events_game
require math.base
require player


[es(tag=server, REQUIRE=possessed, after=player_possess,
    on_event=(PossessTargetByPlayer, EventOnPlayerConnected))]
def objective_selection_static_targets_by_tag(evt : Event;
                                              team : int;
                                              eid : EntityId)
  for_each_player_active_objective(eid) <| $(objective_eid : EntityId)
    query(objective_eid) <| $ [es] (objective__name : string = "";
                                    objective__params : Array;
                                    objective__targetTagNameInParams : string;
                                    objective__numTagsNameInParams : string;
                                    var objective__staticTargetsList : EidList&)

      if !empty(objective__staticTargetsList)
        for static_target in objective__staticTargetsList
          send_net_event(static_target, EventQuestStaticTargetAssigned(playerEid = eid, objectiveEid = objective_eid))
        return

      var allStaticTargetTags : array<string>
      collect_objective_param_values_by_name_strict(objective_eid, objective__params, objective__targetTagNameInParams, allStaticTargetTags)
      let numAllTargetTags = length(allStaticTargetTags)
      if numAllTargetTags == 0
        return

      var numRequireTargetTags = numAllTargetTags
      get_objective_param_value_by_name_i(objective__params, objective__numTagsNameInParams, numRequireTargetTags)
      if numRequireTargetTags > numAllTargetTags
        logerr("Require more targets for quest than exist ({numRequireTargetTags} vs {numAllTargetTags}) for player {eid}, objective {getEntityTemplateName(objective_eid)}:
objective__name = <{objective__name}>
allStaticTargetTags = {allStaticTargetTags}")
        numRequireTargetTags = numAllTargetTags

      var staticTargetsInfo : table<string; array<EntityId>>
      collect_all_static_targets_with_tag(allStaticTargetTags, staticTargetsInfo)
      if length(staticTargetsInfo) < numAllTargetTags
        logerr("Not all quest static targets are found ({length(staticTargetsInfo)} vs {numAllTargetTags}) for player {eid}, objective {getEntityTemplateName(objective_eid)}:
objective__name = <{objective__name}>
allStaticTargetTags = {allStaticTargetTags}
staticTargetsInfo = {staticTargetsInfo}")
        return

      var potentialTargetsByTag : array<string>
      for tagName in keys(staticTargetsInfo)
        potentialTargetsByTag |> push(tagName)
      if numRequireTargetTags < numAllTargetTags
        if get_session_id() != uint64(0) //Hack for offline testing
          var seed = int(get_session_id() % uint64(100000)) + team
          shuffle_seeded(potentialTargetsByTag, seed)
        else
          shuffle(potentialTargetsByTag)


      for idx in range(numRequireTargetTags)
        staticTargetsInfo |> get(potentialTargetsByTag[idx]) <| $(targetEids)
          for targetEid in targetEids
            push(objective__staticTargetsList, targetEid)
            send_net_event(targetEid, EventQuestStaticTargetAssigned(playerEid = eid, objectiveEid = objective_eid))
      return


def private collect_teammates_targets(player_eid : EntityId; player_team : int)
  var res : array<EntityId>
  var teammates : array<EntityId>
  query() <| $ [es(REQUIRE=possessed)] (eid : EntityId; team : int)
    if team == player_team && eid != player_eid
      teammates |> push(eid)
  query() <| $ [es] (objective__staticTargetsList : EidList; objective__playerEid : EntityId)
    if has_value(teammates, objective__playerEid)
      for teid in objective__staticTargetsList
        if !has_value(res, teid)
          res |> push(teid)
  return <- res


def private disable_objectives_static_targets(static_targets_list : EidList;
                                              player_eid : EntityId)
  for static_target in static_targets_list
    var canDisable = true
    for_each_player_active_objective(player_eid) <| $(objective_eid : EntityId)
      query(objective_eid) <| $ [es] (objective__staticTargetsList : EidList)
        canDisable &&= !has_value(objective__staticTargetsList, static_target)
    if canDisable
      sendEvent(static_target, CmdToggleMapObject(value = false))


[es(tag=gameClient, on_appear, track=objective__isCompleted)]
def disable_static_targets_on_quest_complete(evt : Event;
                                             objective__isCompleted : bool;
                                             objective__playerEid : EntityId;
                                             objective__staticTargetsList : EidList)
  if objective__isCompleted && objective__playerEid == get_local_player_eid()
    disable_objectives_static_targets(objective__staticTargetsList, objective__playerEid)


[es(tag=gameClient, on_appear, track=objective__isFailed)]
def disable_static_targets_on_quest_failed(evt : Event;
                                           objective__isFailed : bool;
                                           objective__playerEid : EntityId;
                                           objective__staticTargetsList : EidList)
  if objective__isFailed && objective__playerEid == get_local_player_eid()
    disable_objectives_static_targets(objective__staticTargetsList, objective__playerEid)
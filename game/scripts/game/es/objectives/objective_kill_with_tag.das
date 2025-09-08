require DngDm
require ecs
require app
require level
require strings
require ecs.safe
require math.base
require game.utils.net_utils
require game.utils.team
require game.events.events_game
require game.es.objectives.objective_common
require game.events.events_active_matter
require DagorSystem
require DngNet


[es(tag=server, on_appear)]
def objective_victim_tags_init(evt : Event;
                               eid : EntityId;
                               objective__params : Array;
                               objective__victimTagNameInParams : string;
                               var objective__victimTags : StringList&)
  var victimTags : array<string>
  collect_objective_param_values_by_name_strict(eid, objective__params, objective__victimTagNameInParams, victimTags)
  for victimTag in victimTags
    objective__victimTags |> push(victimTag)


[es(tag=server, on_appear)]
def objective_am_for_kill_init(evt : Event;
                               objective__params : Array;
                               objective__amForKillNameInParams : string;
                               var objective__amForKill : int&)
  get_objective_param_value_by_name_i(objective__params, objective__amForKillNameInParams, objective__amForKill)


[es(tag=server)]
def track_hits_for_objective(evt : EventOnDamaged; var kill_tracking__taggedPlayers : Object&)
  query(evt.offender) <| $ [es] (possessedByPlr : EntityId)
    kill_tracking__taggedPlayers |> set("{possessedByPlr}", get_sync_time())


[es(tag=server)]
def track_kills_for_objective(evt : EventEntityDied;
                              kill_tracking_tag : string;
                              kill_tracking__taggedPlayers : Object const?)
  query(evt.offender) <| $ [es] (possessedByPlr : EntityId; team aka offender_team : int)
    query() <| $ [es(REQUIRE=(objectiveKillWithTag, objective_active))] (objective__params : Array;
                                                                         objective__victimTags : StringList;
                                                                         objective__regionNameInParams : string;
                                                                         objective__questItemTemplateNameInParams : string;
                                                                         objective__requiredWeaponTypeNameInParams : string;
                                                                         eid aka objective_eid, objective__playerEid : EntityId;
                                                                         objective__teammateKillDistance = 100.0;
                                                                         objective__teammateTaggingTime = 20.0;
                                                                         objective__amForKillReason : string = "";
                                                                         objective__amForKill : int const?;
                                                                         var objective__totalAmReward : int?)
      if possessedByPlr != objective__playerEid
        if kill_tracking__taggedPlayers != null
          if get_sync_time() - ((*kill_tracking__taggedPlayers)["{objective__playerEid}"] ?? 0.0) > objective__teammateTaggingTime
            return // too late, even for teammate
        var canProcessObjective = false
        query(objective__playerEid) <| $ [es] (possessed : EntityId; team : int)
          if team == offender_team && !has(possessed, "player_controlled_monster")
            query(possessed) <| $ [es] (isAlive : bool; transform aka offender_transform : float3x4)
              if isAlive
                query(evt.victim) <| $ [es] (transform : float3x4)
                  canProcessObjective = distance_sq(transform[3], offender_transform[3]) <= square(objective__teammateKillDistance)
        if !canProcessObjective
          return

      if !has_value(objective__victimTags, kill_tracking_tag)
        return

      var allowedWeaponTypes : array<string>
      collect_objective_param_values_by_name(objective__params, objective__requiredWeaponTypeNameInParams, allowedWeaponTypes)
      let killedByRequiredWeaponType = empty(allowedWeaponTypes) || has_value(allowedWeaponTypes, get_gun_stat_type_by_props_id(evt.gunPropsId))
      if !killedByRequiredWeaponType
        return

      var questWeaponTemplates : array<string>
      collect_objective_param_values_by_name(objective__params, objective__questItemTemplateNameInParams, questWeaponTemplates)
      if !empty(questWeaponTemplates)
        let killedByQuestWeapon = find_query() <| $ [es(REQUIRE=questItem)] (item__proto : string;
                                                                             gun__propsId : int;
                                                                             quest_item__playerEid : EntityId;
                                                                             quest_item__objectiveEids : EidList)
          if gun__propsId != evt.gunPropsId
            return false
          if !has_value(questWeaponTemplates, item__proto)
            return false
          if quest_item__playerEid != possessedByPlr || !has_value(quest_item__objectiveEids, eid)
            return false
          return true
        if !killedByQuestWeapon
          return

      var regionNames : array<string>
      collect_objective_param_values_by_name(objective__params, objective__regionNameInParams, regionNames)

      var actualProgress = 0
      if !empty(regionNames)
        query(evt.victim) <| $ [es] (transform : float3x4)
          let pos = transform[3].xz
          let killRegionName = get_region_name_by_pos(pos)
          if has_value(regionNames, killRegionName)
            actualProgress = do_progress_for_objective(eid)
      else
        actualProgress = do_progress_for_objective(eid)

      if objective__amForKill != null && objective__totalAmReward != null && actualProgress > 0
        let amCount = (*objective__amForKill) * actualProgress
        *objective__totalAmReward += amCount
        sendEvent(evt.offender, CmdChangeActiveMatterBalance(change = amCount, reason = objective__amForKillReason))
        using() <| $(var data : Object)
          set(data, "count", "{amCount}")
          set(data, "total", "{*objective__totalAmReward}")
          send_net_event(evt.offender, CmdHeroLogExEvent(event = "", key = "hint/objective_am_for_kill_got", data = ecs_addr(data)), target_entity_conn(evt.offender))


require ecs
require DngNet
require strings
require ecs.safe
require ecs.common
require game.events.events
require game.utils.team
require game.es.level_common
require game.events.events_active_matter
require game.es.objectives.objective_common
require game.es.objectives_enums_common
require game.es.entity_mods_common
require game.events.events_game
require DngNet
require DagorSystem
require DagorMath


[unused_argument(objective__reserveValue), es(track=objective__reserveValue)]
def update_objective_current_value(evt : Event;
                                   eid aka objective_eid : EntityId;
                                   objective__reserveValue : int;
                                   objective__currentValue : int)
  set_progress_for_objective(objective_eid, objective__currentValue)


[es(track=objective__currentValue)]
def manage_objective_complete_status(evt : Event;
                                     eid : EntityId;
                                     objective__currentValue : int;
                                     objective__requireValue : int)
  set_objective_complete_status(eid, objective__currentValue >= objective__requireValue)


[es(on_appear, track=(objective__isCompleted, objective__isFailed))]
def objective_optimization(evt : Event;
                           eid : EntityId;
                           objective__isCompleted,
                           objective__isFailed : bool;
                           disableObjectiveUpdate : Tag const? = null)
  let shouldDisableUpdate = objective__isCompleted || objective__isFailed
  if shouldDisableUpdate && disableObjectiveUpdate == null
    addSubTemplate(eid, "disable_objective_update")
  elif !shouldDisableUpdate && disableObjectiveUpdate != null
    removeSubTemplate(eid, "disable_objective_update")


[es(tag=server, on_appear, REQUIRE=showMapObjectOnQuestTargetAssignition)]
def show_assigned_objective_ri_on_map(evt : Event; eid : EntityId; lootable_ri__objectiveEid : EntityId)
  query(lootable_ri__objectiveEid) <| $ [es] (objective__playerEid : EntityId)
    send_net_event(eid, EventQuestStaticTargetAssigned(playerEid = objective__playerEid, objectiveEid = lootable_ri__objectiveEid))


[es(tag=server, REQUIRE=objective__id, REQUIRE_NOT=disable_auto_objective_activation, on_appear)]
def activate_objective(evt : Event;
                       eid : EntityId)
  remote_add_sub_template(eid, "objective_active")


[es(tag=server, REQUIRE=objective_active, on_appear)]
def activate_objective_log_server(evt : Event;
                                  eid : EntityId;
                                  objective__playerEid : EntityId;
                                  objective__id : string;
                                  objective__name : string)
  print("[OBJECTIVE] Objective<{objective__id}> '{objective__name}' {getEntityTemplateName(eid)} is active for player <{objective__playerEid}>")


[es(tag=server, REQUIRE=objective_active, on_disappear)]
def not_activate_objective_log_server(evt : Event;
                                      eid : EntityId;
                                      objective__playerEid : EntityId;
                                      objective__id : string;
                                      objective__name : string)
  print("[OBJECTIVE] Objective<{objective__id}> '{objective__name}' {getEntityTemplateName(eid)} is not active for player <{objective__playerEid}>")


[es(tag=server, REQUIRE=objective_active, track=objective__isCompleted)]
def completed_objective_log_server(evt : Event;
                                   eid : EntityId;
                                   objective__playerEid : EntityId;
                                   objective__id : string;
                                   objective__name : string;
                                   objective__isCompleted : bool)
  if objective__isCompleted
    print("[OBJECTIVE] Completed objective<{objective__id}> '{objective__name}' {getEntityTemplateName(eid)} for player <{objective__playerEid}>")
  else
    print("[OBJECTIVE] NOT completed objective<{objective__id}> '{objective__name}' {getEntityTemplateName(eid)} for player <{objective__playerEid}>")


[es(tag=server, REQUIRE=objective_active, track=objective__isFailed)]
def failed_objective_log_server(evt : Event;
                                eid : EntityId;
                                objective__playerEid : EntityId;
                                objective__id : string;
                                objective__name : string;
                                objective__isFailed : bool)
  if objective__isFailed
    print("[OBJECTIVE] Failed objective<{objective__id}> '{objective__name}' {getEntityTemplateName(eid)} for player <{objective__playerEid}>")
  else
    print("[OBJECTIVE] NOT failed objective<{objective__id}> '{objective__name}' {getEntityTemplateName(eid)} for player <{objective__playerEid}>")


[es(tag=gameClient, REQUIRE=objective_active, on_appear)]
def activate_objective_log_client(evt : Event;
                                  eid : EntityId;
                                  objective__playerEid : EntityId;
                                  objective__id : string;
                                  objective__name : string)
  if objective__playerEid == get_local_player_eid()
    print("[OBJECTIVE] Objective<{objective__id}> '{objective__name}' {getEntityTemplateName(eid)} is active for hero")


[es(tag=gameClient, REQUIRE=objective_active, on_disappear)]
def not_activate_objective_log_client(evt : Event;
                                      eid : EntityId;
                                      objective__playerEid : EntityId;
                                      objective__id : string;
                                      objective__name : string)
  if objective__playerEid == get_local_player_eid()
    print("[OBJECTIVE] Objective<{objective__id}> '{objective__name}' {getEntityTemplateName(eid)} is not active  for hero")


[es(tag=gameClient, REQUIRE=objective_active, track=objective__isCompleted)]
def completed_objective_log_client(evt : Event;
                                   eid : EntityId;
                                   objective__playerEid : EntityId;
                                   objective__id : string;
                                   objective__name : string;
                                   objective__isCompleted : bool)
  if objective__playerEid == get_local_player_eid()
    if objective__isCompleted
      print("[OBJECTIVE] Completed objective<{objective__id}> '{objective__name}' {getEntityTemplateName(eid)}")
    else
      print("[OBJECTIVE] NOT completed objective<{objective__id}> '{objective__name}' {getEntityTemplateName(eid)}")


[es(tag=gameClient, REQUIRE=objective_active, track=objective__isFailed)]
def failed_objective_log_client(evt : Event;
                                eid : EntityId;
                                objective__playerEid : EntityId;
                                objective__id : string;
                                objective__name : string;
                                objective__isFailed : bool)
  if objective__playerEid == get_local_player_eid()
    if objective__isFailed
      print("[OBJECTIVE] Failed objective<{objective__id}> '{objective__name}' {getEntityTemplateName(eid)}")
    else
      print("[OBJECTIVE] NOT failed objective<{objective__id}> '{objective__name}' {getEntityTemplateName(eid)}")


[es(tag=gameClient, REQUIRE=objective_active, on_appear)]
def objective_show_on_activation(evt : Event;
                                 var objective__show : bool&)
  objective__show = true


[es(tag=gameClient, REQUIRE=objective_active, on_disappear)]
def objective_hide_on_deactivation(evt : Event;
                                   var objective__show : bool&)
  objective__show = false


[es(tag=server, REQUIRE=activate_objective_by_player_tag, on_appear)]
def activate_objective_by_player_tag_init(evt : Event;
                                          objective__params : Array;
                                          objective_activate__playerTagNameInParams : string;
                                          var objective_activate__playerTag : das_string&)
  get_objective_param_value_by_name_t(objective__params, objective_activate__playerTagNameInParams, objective_activate__playerTag)


let MONOLITH_PARAMS = "monolith_apply_params"

[es(tag=server, on_event=EventPlayerFirstSpawn)]
def objective_apply_params_from_template_on_spawn(evt : Event; eid aka player_eid, possessed : EntityId)
  query() <| $ [es] (objective__contractType : int; objective__playerEid : EntityId)
    if objective__playerEid == player_eid && objective__contractType == 5 // MONOLITH
      var applyFromTemplate = getTemplateByName(MONOLITH_PARAMS)
      if applyFromTemplate == null
        applyFromTemplate = buildTemplateByName(MONOLITH_PARAMS)
      if applyFromTemplate == null
        logerr("Template with params for monoloith objective does not exist: {MONOLITH_PARAMS}, {getEntityTemplateName(eid)} player_eid: {objective__playerEid}")
        return
      query(possessed) <| $ [es] (var hunter_vision_target__radius : float&;
                                  var hunter_vision_target__fxDurationMult : float&;
                                  var entity_mods : Object)
        hunter_vision_target__radius = getTemplateComponent(*applyFromTemplate, "hunter_vision_target__radius") ?? hunter_vision_target__radius
        hunter_vision_target__fxDurationMult = getTemplateComponent(*applyFromTemplate, "hunter_vision_target__fxDurationMult") ?? hunter_vision_target__fxDurationMult
        let modEffects = get_ecs_object(getTemplateComponent(*applyFromTemplate, "entity_mod_effects"))
        if modEffects != null
          add_mod_effects_to_object(*modEffects, "monolithContract", entity_mods)


[es(tag=gameClient, on_appear)]
def filter_relevant_container_quest_names(evt : Event; var itemContainer__questName : das_string&; lootable_ri__objectiveEid : EntityId)
  query(lootable_ri__objectiveEid) <| $ [es] (objective__playerEid : EntityId)
    query(objective__playerEid) <| $ [es] (is_local : bool)
      if !is_local
        itemContainer__questName := ""


[es(tag=gameClient, on_appear)]
def filter_relevant_container_quest_names2(evt : Event; objective__containerEid, objective__playerEid : EntityId)
  query(objective__playerEid) <| $ [es] (is_local : bool)
    if !is_local
      query(objective__containerEid) <| $ [es] (var itemContainer__questName : das_string&)
        itemContainer__questName := ""


[es(tag=gameClient, on_appear)]
def change_outline_for_objective_container(evt : Event;
                                           eid : EntityId;
                                           var outline__color : E3DCOLOR&)
  var playerEid = INVALID_ENTITY_ID
  query() <| $[es(REQUIRE=hero)] (possessedByPlr : EntityId)
    playerEid = possessedByPlr
  find_query() <| $[es] (objective__playerEid : EntityId;
                         objective__containerEid : EntityId;
                         objective__isCompleted : bool;
                         objective__outlineContainerColor : E3DCOLOR;
                         var objective__defaultContainerColor : E3DCOLOR&)
    if objective__containerEid == eid && objective__playerEid == playerEid && !objective__isCompleted
      objective__defaultContainerColor = outline__color
      outline__color = objective__outlineContainerColor
      return true
    return false


[es(tag=gameClient, after=objective_show_on_activation, REQUIRE=objective_show_only_completed, on_appear, track=(objective__currentValue))]
def change_objective_visibility_behaviour(evt : Event;
                                          objective__currentValue, objective__requireValue : int;
                                          var objective__show : bool&)
  objective__show = objective__currentValue == objective__requireValue


def process_final_extraction_contract(player_eid : EntityId)
  var allBlockingContractsCompleted = true
  var hasActiveMonstrifyContracts = false
  var anyMonstrifyContractsCompleted = false
  var extractionContractEid = INVALID_ENTITY_ID
  for_each_player_objective(player_eid) <| $(objective_eid : EntityId)
    query(objective_eid) <| $ [es] (objective__id : string;
                                    objective__isCompleted, objective__isFailed : bool;
                                    objective__blockExtractionWhenIncomplete : bool;
                                    objective__contractType : int;
                                    objective_active : Tag const?)
      if objective__id == "0"
        extractionContractEid = objective_eid
      elif objective__blockExtractionWhenIncomplete
        allBlockingContractsCompleted &&= objective__isCompleted || objective__isFailed
      elif objective__contractType == int(ContractType.MONSTER) && objective_active != null
        hasActiveMonstrifyContracts = true
        anyMonstrifyContractsCompleted ||= objective__isCompleted || objective__isFailed
  query(extractionContractEid) <| $ [es] (var objective__currentValue : int&)
    let primaryContractsCompleted = allBlockingContractsCompleted || (hasActiveMonstrifyContracts && anyMonstrifyContractsCompleted)
    objective__currentValue = primaryContractsCompleted ? 1 : 0


[unused_argument(objective__isCompleted, objective__isFailed),
es(tag=server, on_appear, REQUIRE=objective_active, track=(objective__isCompleted, objective__isFailed))]
def track_extraction_contract_avaliable(evt : Event;
                                        objective__id : string;
                                        objective__isCompleted, objective__isFailed : bool;
                                        objective__blockExtractionWhenIncomplete : bool;
                                        objective__contractType : int;
                                        objective__playerEid : EntityId)
  if !is_raid_mode()
    return
  if objective__id != "0" && (objective__blockExtractionWhenIncomplete || objective__contractType == int(ContractType.MONSTER))
    process_final_extraction_contract(objective__playerEid)


[es(tag=server, on_disappear, REQUIRE=objective_active)]
def track_extraction_contract_avaliable_activity_toggle(evt : Event;
                                                        objective__id : string;
                                                        objective__contractType : int;
                                                        objective__playerEid : EntityId;
                                                        objective__blockExtractionWhenIncomplete : bool)
  if !is_raid_mode()
    return
  if objective__id != "0" && (objective__blockExtractionWhenIncomplete || objective__contractType == int(ContractType.MONSTER))
    process_final_extraction_contract(objective__playerEid)

module objective_common shared
require ecs
require ecs.common
require ecs.safe
require rapidjson
require DagorSystem
require daslib/strings_boost
require game.es.inventory_item_common
require game.es.objectives_enums_common
require strings
require game.events.events_active_matter


// sync with dagor\active_matter\profileServer\structures\contracts_structures.das
struct ContractProgression
  id : string
  currentValue : int


def objectives_print_log(text)
  print("[OBJECTIVES] {text}")


def collect_all_static_targets_with_tag(tag_list : array<string>;
                                        var out : table<string; array<EntityId>>&)
  query() <| $ [es] (eid : EntityId; objective_static_target__tag : string)
    if has_value(tag_list, objective_static_target__tag)
      if out |> key_exists(objective_static_target__tag)
        out |> get(objective_static_target__tag) <| $(var arr)
          arr |> push(eid)
      else
        out[objective_static_target__tag] <- [ eid]


def make_array_of_objectives_for_save(has_extracted : bool; player_eid : EntityId; var out_array : Array)
  print("[OBJECTIVE SAVE] Save objectives for player <{player_eid}>")
  for_each_player_objective(player_eid) <| $(objective_eid : EntityId)
    print("[OBJECTIVE SAVE] Try save objective {getEntityTemplateName(objective_eid)}")
    query(objective_eid) <| $ [es(REQUIRE_NOT=dontSaveObjective)] (objective__id : string;
                                                                   objective__name : string;
                                                                   objective__currentValue : int;
                                                                   objective__reserveValue : int;
                                                                   objective__requireValue : int;
                                                                   objective__templateName : string;
                                                                   objective__isReported : bool;
                                                                   objective__isStoryContract : bool;
                                                                   objective__blockExtractionWhenIncomplete : bool;
                                                                   objective__requireExtraction : bool;
                                                                   objective__requireFullCompleteInSession : bool;
                                                                   objective__isFailed : bool;
                                                                   objective__params : Array;
                                                                   objective_active : Tag const?;
                                                                   objective_activate_extraction_portal : Tag const?)
      using <| $(var objectiveObj : Object)
        set(objectiveObj, "id", objective__id)
        set(objectiveObj, "name", objective__name)
        set(objectiveObj, "handledByGameTemplate", objective__templateName)
        set(objectiveObj, "isReported", objective__isReported)
        set(objectiveObj, "isStoryContract", objective__isStoryContract)
        set(objectiveObj, "blockExtractionWhenIncomplete", objective__blockExtractionWhenIncomplete)
        set(objectiveObj, "requireExtraction", objective__requireExtraction)
        set(objectiveObj, "requireFullCompleteInSession", objective__requireFullCompleteInSession)
        set(objectiveObj, "params", objective__params)

        var requireValue = objective__requireValue
        if objective_activate_extraction_portal != null
          requireValue = 1
        set(objectiveObj, "requireValue", requireValue)

        var currentValue = objective__currentValue
        if objective_active == null
          print("[OBJECTIVE SAVE] Reset progress of objective<{objective__id}> '{objective__name}' because it is not active")
          currentValue = 0
        elif objective__isFailed
          print("[OBJECTIVE SAVE] Reset progress of objective<{objective__id}> '{objective__name}' because it is failed")
          currentValue = 0
        elif objective_activate_extraction_portal != null
          currentValue = has_extracted ? 1 : 0
        elif objective__requireFullCompleteInSession && currentValue < requireValue
          print("[OBJECTIVE SAVE] Reset progress of objective<{objective__id}> '{objective__name}' because it is not fully completed in session (currentValue={currentValue}; requireValue={requireValue};)")
          currentValue = 0
        elif !has_extracted && objective__requireExtraction && objective__reserveValue < requireValue
          print("[OBJECTIVE SAVE] Reset progress of objective<{objective__id}> '{objective__name}' because it is require extraction (reserveValue={objective__reserveValue}; requireValue={requireValue};)")
          currentValue = 0
        set(objectiveObj, "currentValue", currentValue)

        print("[OBJECTIVE SAVE] Save objective<{objective__id}> '{objective__name}' (currentValue={currentValue}; requireValue={requireValue};)")
        push(out_array, objectiveObj)


def get_objectives_for_save(has_extracted : bool; player_eid : EntityId) : array<ContractProgression>
  var result : array<ContractProgression>
  print("[OBJECTIVE SAVE] Save objectives for player <{player_eid}>")
  for_each_player_objective(player_eid) <| $(objective_eid : EntityId)
    print("[OBJECTIVE SAVE] Try save objective {getEntityTemplateName(objective_eid)}")
    query(objective_eid) <| $ [es(REQUIRE_NOT=dontSaveObjective)] (objective__id : string;
                                                                   objective__name : string;
                                                                   objective__currentValue : int;
                                                                   objective__reserveValue : int;
                                                                   objective__requireValue : int;
                                                                   objective__requireExtraction : bool;
                                                                   objective__requireFullCompleteInSession : bool;
                                                                   objective__isFailed : bool;
                                                                   objective_active : Tag const?;
                                                                   objective_activate_extraction_portal : Tag const?)
      var contractProgression : ContractProgression
      contractProgression.id = objective__id

      var requireValue = objective__requireValue
      if objective_activate_extraction_portal != null
        requireValue = 1

      contractProgression.currentValue = objective__currentValue
      if objective_active == null
        print("[OBJECTIVE SAVE] Reset progress of objective<{objective__id}> '{objective__name}' because it is not active")
        contractProgression.currentValue = 0
      elif objective__isFailed
        print("[OBJECTIVE SAVE] Reset progress of objective<{objective__id}> '{objective__name}' because it is failed")
        contractProgression.currentValue = 0
      elif objective_activate_extraction_portal != null
        contractProgression.currentValue = has_extracted ? 1 : 0
      elif objective__requireFullCompleteInSession && contractProgression.currentValue < requireValue
        print("[OBJECTIVE SAVE] Reset progress of objective<{objective__id}> '{objective__name}' because it is not fully completed in session (currentValue={contractProgression.currentValue}; requireValue={requireValue};)")
        contractProgression.currentValue = 0
      elif !has_extracted && objective__requireExtraction && objective__reserveValue < requireValue
        print("[OBJECTIVE SAVE] Reset progress of objective<{objective__id}> '{objective__name}' because it is require extraction (reserveValue={objective__reserveValue}; requireValue={requireValue};)")
        contractProgression.currentValue = 0

      print("[OBJECTIVE SAVE] Save objective<{objective__id}> '{objective__name}' (currentValue={contractProgression.currentValue}; requireValue={requireValue};)")
      result |> push(contractProgression)

  return <- result


def create_quest_item_in_container(item_template : string; container_eid, player_eid : EntityId; objective_eids : array<EntityId>)
  return create_item_in_inventory_container(item_template, container_eid) <| $(var init)
    set(init, "quest_item__playerEid", player_eid)
    set(init, "quest_item__canBeTakenByAll", false)
    using <| $(var objectiveEids : EidList)
      for objective_eid in objective_eids
        push(objectiveEids, objective_eid)
      set(init, "quest_item__objectiveEids", objectiveEids)


def collect_objective_param_values_by_name(params : Array; name : string; var out : array<string>)
  for param in params
    let paramObj = get_ecs_object(param)
    if paramObj != null
      let paramName = get_string(paramObj, "name", "")
      if paramName == name
        let paramValue = get_string(paramObj, "value", "")
        let separatedParamValues <- paramValue |> split("+")
        for separatedParam in separatedParamValues
          out |> push(separatedParam)


def collect_objective_param_values_by_name_strict(objective_eid : EntityId; params : Array; name : string; var out : array<string>)
  collect_objective_param_values_by_name(params, name, out)
  if empty(out)
    query(objective_eid) <| $[es] (objective__name : string;
                                   objective__playerEid : EntityId)
      logerr("[Contracts] Contract has parametr name:<{name}>, but no have this in params:<{params}> in objective:{getEntityTemplateName(objective_eid)}:
<{objective_eid}> objective__name:<{objective__name}> for player:<{objective__playerEid}>")


def get_objective_param_value_by_name_t(params : Array; name : string; var out : das_string&)
  for param in params
    let paramObj = get_ecs_object(param)
    if paramObj != null
      let paramName = get_string(paramObj, "name", "")
      if paramName == name
        out := get_string(paramObj, "value", "")
        return

def get_objective_param_value_by_name_i(params : Array; name : string; var out : int&)
  for param in params
    let paramObj = get_ecs_object(param)
    if paramObj != null
      let paramName = get_string(paramObj, "name", "")
      if paramName == name
        out = int(get_string(paramObj, "value", "0"))
        return

def get_objective_param_value_by_name_f(params : Array; name : string; var out : float&)
  for param in params
    let paramObj = get_ecs_object(param)
    if paramObj != null
      let paramName = get_string(paramObj, "name", "")
      if paramName == name
        out = float(get_string(paramObj, "value", "0.0"))
        return


def for_each_player_objective(player_eid : EntityId; cb : block<(res : EntityId) : void>)
  query() <| $ [es] (eid, objective__playerEid : EntityId)
    if objective__playerEid == player_eid
      invoke(cb, eid)


def for_each_hero_objective(hero_eid : EntityId; cb : block<(res : EntityId) : void>)
  query(hero_eid) <| $ [es] (possessedByPlr : EntityId)
    for_each_player_objective(possessedByPlr, cb)


def for_each_player_active_objective(player_eid : EntityId; cb : block<(res : EntityId) : void>)
  query() <| $ [es(REQUIRE=objective_active)] (eid, objective__playerEid : EntityId; objective__isCompleted, objective__isFailed : bool)
    if objective__playerEid == player_eid && !objective__isCompleted && !objective__isFailed
      invoke(cb, eid)


def for_each_hero_active_objective(hero_eid : EntityId; cb : block<(res : EntityId) : void>)
  query(hero_eid) <| $ [es] (possessedByPlr : EntityId)
    for_each_player_active_objective(possessedByPlr, cb)


def do_progress_for_objective(objective_eid : EntityId; progress : int = 1)
  var actualProgress = 0
  query(objective_eid) <| $ [es(REQUIRE=objective_active)] (objective__unlimitedProgress : bool = false; objective__requireValue : int; var objective__currentValue : int&)
    if objective__unlimitedProgress
      actualProgress = progress
      objective__currentValue = objective__currentValue + progress
    else
      actualProgress = min(objective__currentValue + progress, objective__requireValue) - objective__currentValue
      objective__currentValue = min(objective__currentValue + progress, objective__requireValue)
    print("[Contracts] Objective <{getEntityTemplateName(objective_eid)}> progress: {objective__currentValue}/{objective__requireValue}")
  return actualProgress


def rollback_progress_for_objective(objective_eid : EntityId; progress : int = 1)
  var actualRollback = 0
  query(objective_eid) <| $ [es(REQUIRE=objective_active)] (objective__requireValue, objective__reserveValue : int; var objective__currentValue : int&)
    actualRollback = objective__currentValue - max(objective__currentValue - progress, objective__reserveValue)
    objective__currentValue = max(objective__currentValue - progress, objective__reserveValue)
    print("[Contracts] Objective <{getEntityTemplateName(objective_eid)}> rollback progress: {objective__currentValue}/{objective__requireValue}")
  return actualRollback


def reserve_progress_for_objective(objective_eid : EntityId; reserve_progress : int = 1)
  var actualProgress = 0
  query(objective_eid) <| $ [es(REQUIRE=objective_active)] (var objective__reserveValue : int&;
                                                            objective__requireValue : int)
    actualProgress = objective__reserveValue
    objective__reserveValue = min(objective__reserveValue + reserve_progress, objective__requireValue)
    actualProgress = objective__reserveValue - actualProgress
    print("[Contracts] Reserve progress to <{objective__reserveValue}> for objective <{getEntityTemplateName(objective_eid)}>")
  return actualProgress


def set_progress_for_objective(objective_eid : EntityId; new_value : int)
  query(objective_eid) <| $ [es(REQUIRE=objective_active)] (var objective__currentValue : int&;
                                                            objective__reserveValue : int)
    objective__currentValue = max(new_value, objective__reserveValue)
    print("[Contracts] Set progress to <{objective__currentValue}> for objective <{getEntityTemplateName(objective_eid)}>")


def reset_progress_for_objective(objective_eid : EntityId)
  query(objective_eid) <| $ [es(REQUIRE=objective_active)] (var objective__currentValue : int&;
                                                            objective__reserveValue : int)
    objective__currentValue = max(0, objective__reserveValue)
    print("[Contracts] Reset progress for objective <{getEntityTemplateName(objective_eid)}>")


def complete_progress_for_objective(objective_eid : EntityId)
  query(objective_eid) <| $ [es(REQUIRE=objective_active)] (objective__requireValue : int; var objective__currentValue : int&)
    objective__currentValue = objective__requireValue
    print("[Contracts] Complete progress for objective <{getEntityTemplateName(objective_eid)}>")


def generate_id_for_objective(player_eid : EntityId)
  var resId = 1u
  for_each_player_objective(player_eid) <| $(objective_eid : EntityId)
    let objectiveId = to_uint(get_string(objective_eid, "objective__id", "0"))
    resId ^= objectiveId
  return resId


def is_item_collected_for_some_objective(item_eid : EntityId)
  var objectiveEid = INVALID_ENTITY_ID
  find_query() <| $ [es] (eid : EntityId; objective__collectedItemsList : EidList)
    if has_value(objective__collectedItemsList, item_eid)
      objectiveEid = eid
      return true
    return false
  return objectiveEid


def seize_item_for_objective_on_extraction(item_eid : EntityId)
  var result = false
  let collectedByObjective = is_item_collected_for_some_objective(item_eid)
  query(collectedByObjective) <| $ [es(REQUIRE=forbidExtractItemForObjective)] (objective__currentValue : int;
                                                                                objective__requireValue : int;
                                                                                objective__requireFullCompleteInSession : bool)
    if !objective__requireFullCompleteInSession || objective__currentValue >= objective__requireValue
      result = true
  return result


def collected_for_objectives_am_count(player_eid : EntityId)
  var totalCount = 0
  for_each_player_objective(player_eid) <| $(objective_eid : EntityId)
    query(objective_eid) <| $ [es(REQUIRE=(objectiveGatherAm, objective_active), REQUIRE_NOT=objective_activate_extraction_portal)] (objective__requireFullCompleteInSession : bool;
                                                                                                                                     objective__currentValue,
                                                                                                                                     objective__requireValue : int)
      if !objective__requireFullCompleteInSession || objective__currentValue >= objective__requireValue
        totalCount += objective__currentValue
  return totalCount


def set_objective_fail_status(objective_eid : EntityId; fail : bool)
  query(objective_eid) <| $ [es] (var objective__isFailed : bool&)
    objective__isFailed = fail
    if objective__isFailed
      print("[Contracts] {objective_eid}<{getEntityTemplateName(objective_eid)}> is marked as failed")
      return
    print("[Contracts] {objective_eid}<{getEntityTemplateName(objective_eid)}> is marked as not failed")


def set_objective_complete_status(objective_eid : EntityId; complete : bool)
  query(objective_eid) <| $ [es] (var objective__isCompleted, objective__isFailed : bool&)
    objective__isCompleted = complete
    if objective__isCompleted
      print("[Contracts] {objective_eid}<{getEntityTemplateName(objective_eid)}> is marked as completed")
      if objective__isFailed
        objective__isFailed = false
        print("[Contracts] {objective_eid}<{getEntityTemplateName(objective_eid)}> was failed but now is completed")
      return
    print("[Contracts] {objective_eid}<{getEntityTemplateName(objective_eid)}> is marked as not completed")


def make_objective_entity(objective : JsonValue; player_eid : EntityId)
  let objectiveTemplate = objective |> json_get_or("handledByGameTemplate", "")

  return createEntity(objectiveTemplate) <| $(init)
    init |> set("objective__id", objective |> json_get_or("id", string(generate_id_for_objective(player_eid))))
    init |> set("objective__name", objective |> json_get_or("name", ""))
    init |> set("objective__currentValue", objective |> json_get_or("currentValue", -1))
    init |> set("objective__requireValue", objective |> json_get_or("requireValue", 0))
    init |> set("objective__contractType", objective |> json_get_or("contractType", int(ContractType.ITEM)))
    init |> set("objective__playerEid", player_eid)
    init |> set("objective__templateName", objectiveTemplate)
    init |> set("objective__isReported", objective |> json_get_or("isReported", false))
    init |> set("objective__isStoryContract", objective |> json_get_or("isStoryContract", false))
    init |> set("objective__blockExtractionWhenIncomplete", objective |> json_get_or("blockExtractionWhenIncomplete", false))
    init |> set("objective__requireExtraction", objective |> json_get_or("requireExtraction", false))
    init |> set("objective__requireFullCompleteInSession", objective |> json_get_or("requireFullCompleteInSession", false))
    init |> set("objective__completeForEntireTeamInRadius", objective |> json_get_or("completeForEntireTeamInRadius", -1.0))

    using() <| $(var params : Array&)
      objective |> FindMember("params", JsonType.kArrayType) <| $(paramsJson : JsonValue)
        paramsJson |> GetArray() <| $(paramsJsonArray : JsonConstArray)
          for param in paramsJsonArray
            using() <| $(var paramObj : Object&)
              paramObj |> set("name", param |> json_get_or("name", ""))
              paramObj |> set("value", param |> json_get_or("value", ""))
              params |> push(paramObj)
      init |> set("objective__params", params)


def make_objective_entity(objective : Object;
                          player_eid : EntityId;
                          init_block : block<(var init_obj : ComponentsInitializer) : void>)
  let objectiveTemplate = objective |> get_string("handledByGameTemplate", "")

  return createEntity(objectiveTemplate) <| $(init)
    init |> set("objective__id", objective |> get_string("id", string(generate_id_for_objective(player_eid))))
    init |> set("objective__name", objective |> get_string("name", ""))
    init |> set("objective__currentValue", objective |> get_int("currentValue") ?? -1)
    init |> set("objective__requireValue", objective |> get_int("requireValue") ?? 0)
    init |> set("objective__contractType", objective |> get_int("contractType") ?? int(ContractType.ITEM))
    init |> set("objective__playerEid", player_eid)
    init |> set("objective__templateName", objectiveTemplate)
    init |> set("objective__isReported", objective |> get_bool("isReported") ?? false)
    init |> set("objective__isStoryContract", objective |> get_bool("isStoryContract") ?? false)
    init |> set("objective__blockExtractionWhenIncomplete", objective |> get_bool("blockExtractionWhenIncomplete") ?? false)
    init |> set("objective__requireExtraction", objective |> get_bool("requireExtraction") ?? false)
    init |> set("objective__requireFullCompleteInSession", objective |> get_bool("requireFullCompleteInSession") ?? false)

    let params = objective |> get_ecs_array("params")
    if params != null
      init |> set("objective__params", *params)

    invoke(init_block, init)


def make_extraction_objective_entity(player_eid : EntityId; is_active : bool)
  return createEntity(is_active ? "objective_final_extraction+objective_active" : "objective_final_extraction") <| $(init)
    init |> set("objective__id", "0")
    init |> set("objective__name", "contract_primary_successful_extract")
    init |> set("objective__currentValue", is_active ? 1 : 0)
    init |> set("objective__isCompleted", is_active)
    init |> set("objective__requireValue", 1)
    init |> set("objective__contractType", int(ContractType.PRIMARY))
    init |> set("objective__playerEid", player_eid)
    init |> set("objective__templateName", "objective_final_extraction")
    init |> set("objective__isReported", false)
    init |> set("objective__isStoryContract", false)
    init |> set("objective__blockExtractionWhenIncomplete", false)
    init |> set("objective__requireExtraction", true)
    init |> set("objective__requireFullCompleteInSession", true)


def make_objective_entity(objective : Object;
                          player_eid : EntityId)
  return make_objective_entity(objective, player_eid) <| $ [unused_argument(init)] (var init) {}


def make_objective_entities(objectives_array : Array; player_eid : EntityId)
  for objective in objectives_array
    let obj = get_ecs_object(objective)
    if obj == null
      continue
    make_objective_entity(*obj, player_eid)


def destroy_player_objectives(player_eid : EntityId)
  for_each_player_objective(player_eid) <| $(objective_eid : EntityId)
    destroyEntity(objective_eid)


def check_is_item_for_collect_objective(item_eid, objective_eid : EntityId)
  // if is_item_collected_for_some_objective(item_eid) != INVALID_ENTITY_ID
  //   return false

  var res = false
  query(objective_eid) <| $ [es] (objective__params : Array;
                                  objective__itemTemplateNameInParams : string)
    var objectiveItemNames : array<string>
    collect_objective_param_values_by_name_strict(objective_eid, objective__params, objective__itemTemplateNameInParams, objectiveItemNames)
    let itemTemplateForCheck = split_template(getEntityTemplateName(item_eid))[0]
    res = has_value(objectiveItemNames, itemTemplateForCheck)
  query(objective_eid) <| $ [es] (objective__params : Array;
                                  objective__itemTagNameInParams : string)
    var objectiveItemTags : array<string>
    collect_objective_param_values_by_name_strict(objective_eid, objective__params, objective__itemTagNameInParams, objectiveItemTags)
    res = length(objectiveItemTags) > 0
    for tag in objectiveItemTags
      if !has(item_eid, tag, ecs_hash(tag))
        res = false
        break
  return res
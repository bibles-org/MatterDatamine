options no_aot
require ecs
require ecs.soa_template
require math.base
require DagorConsole
require game.es.net_console_macro
require game.events.events_active_matter
require game.es.door_operations_common
require game.es.am_encounter_jump_quest_common


[net_console_cmd(name="encounter.open_all_doors")]
def console_encounter_open_all_doors(req_state : int = int(DoorState.OPENED))
  query() <| $ [es(REQUIRE=encounter_door)] (eid aka door_eid : EntityId;
                                             pair_door__eid : EntityId)
    change_door_state(door_eid, req_state, float3(), true)
    change_door_state(pair_door__eid, req_state, float3(), true)


[net_console_cmd(name="encounter.unlock_all_doors")]
def console_encounter_unlock_all_doors(unlock : bool = true)
  query() <| $ [es(REQUIRE=encounter_door)] (pair_door__eid : EntityId;
                                             var locked__isLocked : bool&)
    locked__isLocked = !unlock

    query(pair_door__eid) <| $ [es] (var locked__isLocked aka pair_locked__isLocked : bool&)
      pair_locked__isLocked = !unlock


[net_console_cmd(name="encounter.jump_quest_generate")]
def console_encounter_jump_quest_generate(@net_hero eid : EntityId)
  query(eid) <| $ [es] (transform aka hero_transform : float3x4)
    find_query() <| $ [soa_blk, es(REQUIRE=encounter_jump_quest)] (transform aka jump_quest_transform : float3x4;
                                                                   eid aka jump_quest_eid : EntityId)
      if distance_sq(hero_transform[3], jump_quest_transform[3]) > square(100.0)
        return false
      generate_jump_nodes_tree(jump_quest_eid)
      return true


[soa_def, net_console_cmd(name="encounter.jump_quest_demolition")]
def console_encounter_jump_quest_demolition(@net_hero eid : EntityId)
  query(eid) <| $ [es] (transform aka hero_transform : float3x4)
    find_query() <| $ [soa_blk, es(REQUIRE=encounter_jump_quest)] (transform aka jump_quest_transform : float3x4;
                                                                   encounter_jump_quest__pathRendinsts : Array;
                                                                   encounter_jump_quest__topPlatformRendinsts : Array;
                                                                   encounter_jump_quest__decorRendinsts : Array;
                                                                   encounter_jump_quest__coreEid : EntityId;
                                                                   encounter_jump_quest__nodes : EncounterJumpQuestNode_SOA;
                                                                   encounter_jump_quest__recoveringDelay : float2;
                                                                   var encounter_jump_quest__recoverAt : float&)
      if distance_sq(hero_transform[3], jump_quest_transform[3]) > square(100.0)
        return false
      demolish_jump_nodes_tree(encounter_jump_quest__pathRendinsts,
                              encounter_jump_quest__topPlatformRendinsts,
                              encounter_jump_quest__decorRendinsts,
                              encounter_jump_quest__coreEid,
                              encounter_jump_quest__nodes,
                              encounter_jump_quest__recoveringDelay,
                              encounter_jump_quest__recoverAt)
      return true


[soa_def, net_console_cmd(name="encounter.jump_quest_recover")]
def console_encounter_jump_quest_recover(@net_hero eid : EntityId)
  query(eid) <| $ [es] (transform aka hero_transform : float3x4)
    find_query() <| $ [soa_blk, es(REQUIRE=encounter_jump_quest)] (transform aka jump_quest_transform : float3x4;
                                                                   encounter_jump_quest__coreEid : EntityId;
                                                                   encounter_jump_quest__nodes : EncounterJumpQuestNode_SOA)
      if distance_sq(hero_transform[3], jump_quest_transform[3]) > square(100.0)
        return false
      recover_jump_nodes_tree(encounter_jump_quest__coreEid,
                              encounter_jump_quest__nodes)
      return true
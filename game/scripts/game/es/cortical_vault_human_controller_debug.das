options no_aot
require ecs
require DagorConsole
require DagorMath
require Grid
require game.es.ecs_common
require game.es.cortical_vault_human_controller_common

/* not up to date with cortical vault changes

def print_analyze(text : string)
  let finalText = "[HACKING ANALYZE] {text}"
  print(finalText)
  console_print(finalText)


def analyze_militant_ragdoll_phys_obj_use_option(actor_eid : EntityId;
                                                 militant_ragdoll_phys_obj_eid : EntityId)
  if is_another_hacking_cortical_vault_process_exists(actor_eid, militant_ragdoll_phys_obj_eid)
    print_analyze("RESULT IS NONE - Another hacking process exists!")
    return CorticalVaultHumanControllerUseOption.NONE

  var i = 0

  var result = CorticalVaultHumanControllerUseOption.NONE
  query(actor_eid) <| $ [es] (team aka my_team : int)
    print_analyze("my_team = {my_team}")
    i = 1
    query(militant_ragdoll_phys_obj_eid) <| $ [es(REQUIRE=militant_ragdoll_phys_obj)] (ragdoll_phys_obj__attachedTo : EntityId;
                                                                                       itemContainer aka ragdoll_itemContainer : EidList)
      i = 2
      print_analyze("ragdoll_itemContainer = {ragdoll_itemContainer} ({length(ragdoll_itemContainer)})")
      query(ragdoll_phys_obj__attachedTo) <| $ [es] (team aka target_team : int;
                                                     createdByPlr : EntityId;
                                                     possessedByPlr : EntityId)
        i = 3
        let ragdollPlayerEid = createdByPlr != INVALID_ENTITY_ID ? createdByPlr : possessedByPlr
        print_analyze("
target_team = {target_team}
createdByPlr = {get_entity_info(createdByPlr)}
possessedByPlr = {get_entity_info(possessedByPlr)}
ragdollPlayerEid = {get_entity_info(ragdollPlayerEid)}")
        let coritcalVaultIndex = find_index_if(each(ragdoll_itemContainer)) <| $(item_eid : EntityId)

          if isLoadingEntity(item_eid)
            print_analyze("ITEM IS LOADING! item_eid={get_entity_info(item_eid)}")
          if !doesEntityExist(item_eid)
            print_analyze("ITEM IS NOT EXIST! item_eid={get_entity_info(item_eid)}")

          var isCorticalVaultOfTargetPlayer = false
          query(item_eid) <| $ [es(REQUIRE=cortical_vault)] (playerItemOwner : EntityId;
                                                             cortical_vault__hacked : bool;
                                                             am_storage__value : int)
            isCorticalVaultOfTargetPlayer = (ragdollPlayerEid == playerItemOwner)
            print_analyze("CORTICAL VAULT ITEM: {get_entity_info(item_eid)}}
playerItemOwner = {playerItemOwner}
cortical_vault__hacked = {cortical_vault__hacked}
am_storage__value = {am_storage__value}
isCorticalVaultOfTargetPlayer = {isCorticalVaultOfTargetPlayer}")
            if !isCorticalVaultOfTargetPlayer
              return

            i = 4

            // Enemy
            if target_team != my_team
              if !cortical_vault__hacked
                result = CorticalVaultHumanControllerUseOption.HACK_CORTICAL_VAULT
                print_analyze("RESULT IS HACK_CORTICAL_VAULT!")
              elif am_storage__value > 0
                result = CorticalVaultHumanControllerUseOption.GATHER_AM
                print_analyze("RESULT IS GATHER_AM!")
            // Teammate
            else
              if am_storage__value > 0
                result = CorticalVaultHumanControllerUseOption.GATHER_AM
                print_analyze("RESULT IS GATHER_AM!")
          return isCorticalVaultOfTargetPlayer
        print_analyze("coritcalVaultIndex = {coritcalVaultIndex}")
  print_analyze("ANALYZE RESULT = {result} (i = {i})")
  return result


[console_cmd(name="am.analyze_hacking")]
def am_analyze_hacking_cmd()
  query() <| $ [es(REQUIRE=watchedByPlr)] (eid aka actor_eid : EntityId;
                                           transform aka actor_transform : float3x4;
                                           team aka actor_team : int;
                                           possessedByPlr aka actor_possessedByPlr : EntityId;
                                           createdByPlr aka actor_createdByPlr : EntityId)
    print_analyze("actor: {get_entity_info(actor_eid)}
actor_team = {actor_team}
actor_possessedByPlr = {get_entity_info(actor_possessedByPlr)}
actor_createdByPlr = {get_entity_info(actor_createdByPlr)}")
    let bounding = BSphere3(actor_transform[3], 20.0)
    gather_entities_in_grid(ecs_hash("interactable"), bounding, GridEntCheck.POS) <| $(interactableList)
      for ieid in interactableList
        query(ieid) <| $ [es(REQUIRE=militant_ragdoll_phys_obj)] (transform aka ragdoll_phys_obj_transform : float3x4)
          print_analyze("phys_obj: {get_entity_info(ieid)}
ragdoll_phys_obj_transform[3] = {ragdoll_phys_obj_transform[3]}")
          analyze_militant_ragdoll_phys_obj_use_option(actor_eid, ieid)
*/
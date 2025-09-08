module cortical_vault_human_controller_common shared
require ecs


enum CorticalVaultHumanControllerUseOption
  NONE
  HACK_CORTICAL_VAULT
  GATHER_AM


def is_hacking_cortical_vault_process_exists(militant_ragdoll_phys_obj_eid : EntityId)
  return find_query() <| $ [es] (hacking_cortical_vault_process__ragdollPhysObjEid : EntityId)
    return hacking_cortical_vault_process__ragdollPhysObjEid == militant_ragdoll_phys_obj_eid


def is_another_hacking_cortical_vault_process_exists(actor_eid : EntityId;
                                                     militant_ragdoll_phys_obj_eid : EntityId)
  var  exists = false
  find_query() <| $ [es] (hacking_cortical_vault_process__hackerActorEid : EntityId;
                          hacking_cortical_vault_process__ragdollPhysObjEid : EntityId)
    exists = (hacking_cortical_vault_process__hackerActorEid != actor_eid)
    return hacking_cortical_vault_process__ragdollPhysObjEid == militant_ragdoll_phys_obj_eid
  return exists


def calculate_militant_ragdoll_phys_obj_use_option(actor_eid : EntityId;
                                                   militant_ragdoll_phys_obj_eid : EntityId)
  if is_another_hacking_cortical_vault_process_exists(actor_eid, militant_ragdoll_phys_obj_eid)
    return CorticalVaultHumanControllerUseOption.NONE

  var result = CorticalVaultHumanControllerUseOption.NONE
  query(actor_eid) <| $ [es] (team aka my_team : int;
                              resources_gatherer_hero__enabled : bool)
    if !resources_gatherer_hero__enabled
      return
    query(militant_ragdoll_phys_obj_eid) <| $ [es(REQUIRE=militant_ragdoll_phys_obj)] (ragdoll_phys_obj__attachedTo : EntityId;
                                                                                       am_storage__hacked : bool;
                                                                                       am_storage__value : int)
      query(ragdoll_phys_obj__attachedTo) <| $ [es] (team aka target_team : int;
                                                     cortical_hack_disabled : Tag const?)
        // not turned enemy
        if target_team != my_team && cortical_hack_disabled == null
          if !am_storage__hacked
            result = CorticalVaultHumanControllerUseOption.HACK_CORTICAL_VAULT
          elif am_storage__value > 0
            result = CorticalVaultHumanControllerUseOption.GATHER_AM
        // Teammate or turned soldier
        else
          if am_storage__value > 0
            result = CorticalVaultHumanControllerUseOption.GATHER_AM
  return result
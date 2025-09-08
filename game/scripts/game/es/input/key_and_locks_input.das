require ecs
require game.es.keys_and_locks_common


[es(tag=input, REQUIRE=hero, REQUIRE_NOT=deadEntity,
  after=hero_human_use_object,
  before=hero_human_final_use_object_sync)]
def hero_human_use_check_keys(act : UpdateStageInfoAct;
                              inventories_owner__inventoryEids : EidList;
                              var human_use_object__blockReason : das_string&;
                              var human_use_object__blockReasonStatusTip : das_string&;
                              var human_use_object__canUseSelected : bool&;
                              human_use_object__selectedObject : EntityId)
  query(human_use_object__selectedObject) <| $ [es] (locked__isLocked : bool;
                                                     locked__keyTags : StringList;
                                                     locked__statusTip : string = "";
                                                     locked__reason : string = "")
    human_use_object__canUseSelected = !locked__isLocked
    for inventoryEid in inventories_owner__inventoryEids
      if human_use_object__canUseSelected // can be opened from previous container iteration
        break
      query(inventoryEid) <| $ [es] (itemContainer : EidList)
        for itemEid in itemContainer
          if human_use_object__canUseSelected // can be opened from previous item container iteration
            break
          query(itemEid) <| $ [es] (key__tags : StringList)
            human_use_object__canUseSelected = have_same_tag(locked__keyTags, key__tags)

    if !human_use_object__canUseSelected
      if !empty(locked__reason)
        human_use_object__blockReason := locked__reason
      elif !empty(locked__statusTip)
        human_use_object__blockReasonStatusTip := locked__statusTip

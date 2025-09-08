module inventory_item_mod_common shared
require ecs
require ecs.safe
require ecs.common
require math.base
require DagorSystem


def get_item_slot_available_mods(@shared_comp slots : Object;
                                 slot_name : string;
                                 cb : block<(available_items : StringList) : void>)
  let slotTemplateName = slots |> get_ecs_string(slot_name)
  if slotTemplateName == null
    return false

  let slotTemplate = getTemplateByName(string(*slotTemplateName))
  if slotTemplate == null
    logerr("Invalid slotTemplateName={slotTemplateName}!")
    return false

  let availableItems = get_ecs_StringList(getTemplateComponent(*slotTemplate, "slot_holder__availableItems"))
  if availableItems == null
    return false

  cb |> invoke(*availableItems)
  return true


def is_mod_available_for_slot(mod_item_proto : string;
                              @shared_comp slots : Object;
                              slot_name : string)
  var available = false
  get_item_slot_available_mods(slots, slot_name) <| $ [es] (available_items : StringList)
    for availableItem in available_items
      if availableItem == mod_item_proto
        available = true
        break
  return available
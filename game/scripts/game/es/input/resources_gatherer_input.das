require ecs
require DagorInput
require DngNet
require game.events.events
require game.events.events_active_matter

[es(tag=input)]
def gatherer_input_es(info : UpdateStageUpdateInput;
                      eid : EntityId;
                      resources_gatherer__eid : EntityId;
                      resources_gatherer_hero__enabled : bool;
                      human_inventory__entityToUse : EntityId;
                      human_use_object__selectedObject : EntityId;
                      human_input__use : int;
                      resources_gatherer_hero_debug : Tag const?)
  let handle = uint16(human_input__use)
  let btnPressed = is_action_active(handle) && get_digital_action_state(handle).bState

  var isWorking = false
  query(resources_gatherer__eid) <| $ [es] (resources_gatherer_device__tickAt : float)
    isWorking = resources_gatherer_device__tickAt > 0.0

  if btnPressed && resources_gatherer_hero_debug != null
    print("[RESOURCES GATHERER DEBUG]
resources_gatherer__eid={resources_gatherer__eid}
isWorking={isWorking}
resources_gatherer_hero__enabled={resources_gatherer_hero__enabled}
human_inventory__entityToUse={human_inventory__entityToUse}
btnPressed={btnPressed}")

  if !resources_gatherer_hero__enabled
    if isWorking
      if resources_gatherer_hero_debug != null
        print("[RESOURCES GATHERER DEBUG] CmdGathererToggle SEND RESET")
      send_net_event(eid, CmdGathererToggle(isOn = false))
    return

  // if hero interacting with some item, disable am gatherer
  if human_inventory__entityToUse != INVALID_ENTITY_ID
    if isWorking
      if resources_gatherer_hero_debug != null
        print("[RESOURCES GATHERER DEBUG] CmdGathererToggle SEND RESET2")
      send_net_event(eid, CmdGathererToggle(isOn = false))
    return

  if (!isWorking &&
    !has(human_use_object__selectedObject, "item__am") &&
    !has(human_use_object__selectedObject, "active_matter_pile_provider"))
    return

  if !(isWorking ^^ btnPressed)
    return

  if resources_gatherer_hero_debug != null
    print("[RESOURCES GATHERER DEBUG] CmdGathererToggle SEND isOn={btnPressed}")
  send_net_event(eid, CmdGathererToggle(isOn = btnPressed))

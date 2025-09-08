require ecs
require app
require net
require game.es.status_tip_common
require game.events.input_events
require danetlibs.package_soldier.soldier_inventory_events
require game.events.events_active_matter
require DagorInput
require game.es.inventory_item_common
require game.events.events
require ecs.safe
require game.es.inventory_checks_common


def init(var quick_use_input__slots : IntList&;
         quick_use_input__slotsNum : int;
         var quick_use_input__ObjectiveItem : int&)
  if length(quick_use_input__slots) != quick_use_input__slotsNum
    quick_use_input__slots |> resize(quick_use_input__slotsNum)
  for i in range(quick_use_input__slotsNum)
    quick_use_input__slots[i] = int(get_action_handle("Human.QuickUse{i+1}", TYPEGRP_DIGITAL))
  quick_use_input__ObjectiveItem = int(get_action_handle("Human.QuickUseObjectiveItem", TYPEGRP_DIGITAL))


def reset(var quick_use_input__slots : IntList&;
          quick_use_input__slotsNum : int;
          var quick_use_input__ObjectiveItem : int&)
  if length(quick_use_input__slots) != quick_use_input__slotsNum
    quick_use_input__slots |> resize(quick_use_input__slotsNum)
  for i in range(quick_use_input__slotsNum)
    quick_use_input__slots[i] = int(BAD_ACTION_HANDLE)
  quick_use_input__ObjectiveItem = int(BAD_ACTION_HANDLE)

[es(tag=input)]
def quick_use_input__setup(evt : EventDaInputInit;
                           var quick_use_input__slots : IntList&;
                           quick_use_input__slotsNum : int;
                           var quick_use_input__ObjectiveItem : int&)
  if evt.init
    init(quick_use_input__slots, quick_use_input__slotsNum, quick_use_input__ObjectiveItem)
  else
    reset(quick_use_input__slots, quick_use_input__slotsNum, quick_use_input__ObjectiveItem)


[es(tag=input, on_appear)]
def quick_use_init_on_appear(evt : Event;
                             var quick_use_input__slots : IntList&;
                             quick_use_input__slotsNum : int;
                             var quick_use_input__ObjectiveItem : int&)
  init(quick_use_input__slots, quick_use_input__slotsNum, quick_use_input__ObjectiveItem)


[es(tag=input, on_disappear)]
def quick_use_init_on_disappear(evt : Event;
                                var quick_use_input__slots : IntList&;
                                quick_use_input__slotsNum : int;
                                var quick_use_input__ObjectiveItem : int&)
  reset(quick_use_input__slots, quick_use_input__slotsNum, quick_use_input__ObjectiveItem)


[es(tag=gameClient, REQUIRE_NOT=item__customQuickUseAction)]
def on_item_quick_used_default(evt : EventQuickUseItemUsed; eid : EntityId)
  sendEvent(eid, TryUseItem(userEid = evt.userEid))


[es(tag=input, before=human_common_input_action_triggered_es, REQUIRE_NOT=deadEntity)]
def quick_use__cursor_down_es(evt : EventDaInputActionTriggered;
                              input__enabled : bool;
                              eid : EntityId;
                              quick_use_input__slotsNum : int;
                              quick_use_input__slots : IntList)
  if !input__enabled
    return

  var idx = -1
  for inpt, i in quick_use_input__slots, range(quick_use_input__slotsNum)
    if inpt == int(evt.action)
      idx = i
      break

  if idx == -1
    return

  foreach_pocket_slot(eid) <| $ [unused_argument(equipment)] (modIdx : int;
                                                              equipment : tuple<slot : string; eid : EntityId>;
                                                              mod : tuple<slot : string; eid : EntityId>)
    if modIdx == idx && mod.eid != INVALID_ENTITY_ID
      sendEvent(mod.eid, EventQuickUseItemUsed(userEid = eid))


[es(tag=input, before=human_common_input_action_triggered_es, REQUIRE_NOT=deadEntity)]
def quick_use__objective_item_cursor_down_es(evt : EventDaInputActionTriggered;
                                             input__enabled : bool;
                                             eid : EntityId;
                                             quick_use_input__ObjectiveItem : int;
                                             quick_use__objective : string;
                                             human_use_object__selectedObject : EntityId)
  if !input__enabled || human_use_object__selectedObject != INVALID_ENTITY_ID
    return

  let action = int(evt.action)
  if action != quick_use_input__ObjectiveItem || empty(quick_use__objective)
    return

  let itemsInInventory <- find_items_in_inventory_by_template_name(quick_use__objective, eid)

  if empty(itemsInInventory)
    return

  sendEvent(itemsInInventory[0], TryUseItem(userEid = eid))

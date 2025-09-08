require ecs
require app
require game.events.events
require game.events.events_game
require game.events.input_events
require DagorInput
require HumanPhys
require DngHuman
require DngNet
require game.es.inventory_checks_common
require inventory


def init(var human_input__throw : int&;
         var human_input__throw2 : int&;
         var human_input__throw3 : int&;
         var human_input__throw4 : int&)
  human_input__throw = int(get_action_handle("Human.Throw", TYPEGRP_DIGITAL))
  human_input__throw2 = int(get_action_handle("Human.Throw2", TYPEGRP_DIGITAL))
  human_input__throw3 = int(get_action_handle("Human.Throw3", TYPEGRP_DIGITAL))
  human_input__throw4 = int(get_action_handle("Human.Throw4", TYPEGRP_DIGITAL))


def reset(var human_input__throw : int&;
          var human_input__throw2 : int&;
          var human_input__throw3 : int&;
          var human_input__throw4 : int&)
  human_input__throw = int(BAD_ACTION_HANDLE)
  human_input__throw2 = int(BAD_ACTION_HANDLE)
  human_input__throw3 = int(BAD_ACTION_HANDLE)
  human_input__throw4 = int(BAD_ACTION_HANDLE)


def set_throwbit(var ct &; throw_actions : array<uint16>)
  ct |> human_control_state_set_throw_state(false, HumanControlThrowSlot.HCTS_EMPTY)

  for action in throw_actions
    if is_action_active(action) && get_digital_action_state(action).bState
      ct |> human_control_state_set_throw_state(true, HumanControlThrowSlot.HCTS_EMPTY)
      break


def set_throwbit(var ct &; action : uint16; hero_eid : EntityId; grenade_type : string)
  if is_action_active(action) && get_digital_action_state(action).bState
    let res = find_grenade_ammo_item_id(hero_eid, grenade_type)
    if res.itemId != INVALID_ITEM_ID
      ct |> human_control_state_set_throw_state(true, HumanControlThrowSlot.HCTS_EMPTY)
      return true
  return false


def set_throwbackbit(var ct &; actionHandle)
  if is_action_active(actionHandle) && get_digital_action_state(actionHandle).bState
    ct |> human_control_state_set_control_bit(HumanPhysControlType.HCT_THROW_BACK, true)
  else
    ct |> human_control_state_set_control_bit(HumanPhysControlType.HCT_THROW_BACK, false)

[es(tag=input, on_appear)]
def human_grenade_input_appear_es(evt : Event;
                                  var human_input__throw : int&;
                                  var human_input__throw2 : int&;
                                  var human_input__throw3 : int&;
                                  var human_input__throw4 : int&)
  init(human_input__throw,
       human_input__throw2,
       human_input__throw3,
       human_input__throw4)

[es(tag=input)]
def human_grenade_input_init_es(evt : EventDaInputInit;
                                var human_input__throw : int&;
                                var human_input__throw2 : int&;
                                var human_input__throw3 : int&;
                                var human_input__throw4 : int&)
  if evt.init
    init(human_input__throw,
         human_input__throw2,
         human_input__throw3,
         human_input__throw4)
  else
    reset(human_input__throw,
          human_input__throw2,
          human_input__throw3,
          human_input__throw4)

def find_grenade_ammo_item_id(hero_eid : EntityId; grenade_type : string) : tuple<itemId : int; itemEid : EntityId>
  var itemId = INVALID_ITEM_ID
  var itemEid = INVALID_ENTITY_ID

  foreach_pocket_slot(hero_eid) <| $ [unused_argument(modIdx, equipment)] (modIdx : int;
                                                                           equipment : tuple<slot : string; eid : EntityId>;
                                                                           mod : tuple<slot : string; eid : EntityId>)
    if itemId != INVALID_ITEM_ID
      return
    query(mod.eid) <| $ [es] (item__grenadeType : string; item__id : int)
      if grenade_type == item__grenadeType
        itemId = item__id
        itemEid = mod.eid

  return itemId, itemEid

def try_quick_throw_grenade_slot(eid : EntityId; grenade_type : string)
  let res = find_grenade_ammo_item_id(eid, grenade_type)
  if res.itemId != INVALID_ITEM_ID
    send_net_event(eid, RequestQuickThrowGrenade(grenade_ammo_id = res.itemId, grenade_ammo_eid = res.itemEid))

[es(tag=input)]
def human_grenade_input_action_triggered_es(evt : EventDaInputActionTriggered;
                                            eid : EntityId;
                                            input__enabled : bool;
                                            human_input__throw : int;
                                            human_input__throw2 : int;
                                            human_input__throw3 : int;
                                            human_input__throw4 : int)
  if !input__enabled
    return

  let action = int(evt.action)
  var grenadeType = ""
  if action == human_input__throw
    grenadeType = "explosive"
  elif action == human_input__throw2
    grenadeType = "smoke"
  elif action == human_input__throw3
    grenadeType = "flash"
  elif action == human_input__throw4
    grenadeType = "flame"

  if grenadeType == ""
    return

  try_quick_throw_grenade_slot(eid, grenadeType)

[es(tag=input)]
def human_grenade_input_es(info : UpdateStageUpdateInput;
                           eid : EntityId;
                           human_input__throw : int;
                           human_input__throw2 : int;
                           human_input__throw3 : int;
                           human_input__throw4 : int;
                           human_weap__throwMode : bool;
                           var human_net_phys : HumanActor&)
  assume ct = human_net_phys.phys.producedCT
  if !human_weap__throwMode
    ct |> human_control_state_set_throw_state(false, HumanControlThrowSlot.HCTS_EMPTY)
    if (set_throwbit(ct, uint16(human_input__throw), eid, "explosive")
      || set_throwbit(ct, uint16(human_input__throw2), eid, "smoke")
      || set_throwbit(ct, uint16(human_input__throw3), eid, "flash")
      || set_throwbit(ct, uint16(human_input__throw4), eid, "flame"))
      return
  else
    ct |> set_throwbit(array<uint16>(uint16(human_input__throw),
                                uint16(human_input__throw2),
                                uint16(human_input__throw3),
                                uint16(human_input__throw4)))

[es(tag=input)]
def human_grenade_input_entity_reset_es(evt : EventOnEntityReset;
                                        human_input__use : int;
                                        human_input__throw : int;
                                        human_input__throw2 : int;
                                        human_input__throw3 : int;
                                        human_input__throw4 : int;
                                        var human_net_phys : HumanActor&)
  assume ct = human_net_phys.phys.producedCT
  ct |> set_throwbit(array<uint16>(uint16(human_input__throw),
                              uint16(human_input__throw2),
                              uint16(human_input__throw3),
                              uint16(human_input__throw4)))
  ct |> set_throwbackbit(uint16(human_input__use))

[es(tag=input)]
def human_grenade_throwback_input_es(info : UpdateStageUpdateInput;
                                     human_input__use : int;
                                     var human_net_phys : HumanActor&)
  assume ct = human_net_phys.phys.producedCT
  ct |> set_throwbackbit(uint16(human_input__use))

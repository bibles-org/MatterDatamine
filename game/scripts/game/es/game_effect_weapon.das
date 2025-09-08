require ecs
require DngHuman
require DaWeapons
require game.events.events_game
require game.es.human_weap_common


[es(on_appear)]
def on_switch_weapon_game_effect_appear(evt : Event; game_effect__attachedTo : EntityId; game_effect__switchToWeaponSlot : int)
  query(game_effect__attachedTo) <| $ [es] (human_net_phys : HumanActor;
                                            human_weap__currentGunSlot : int)
    assume weapEquipState = human_net_phys.phys.currentState.weapEquipState
    let curGunSlot = human_weap__currentGunSlot >= 0 ? HUWeaponSlots(human_weap__currentGunSlot) : HUWeaponSlots.EWS_NUM
    let nextGunSlot = weapEquipState.nextSlot
    let curState = weapEquipState.curState

    let isNeededSlot = int(curGunSlot) == game_effect__switchToWeaponSlot
    let isNeededSlotEquipping = int(nextGunSlot) == game_effect__switchToWeaponSlot && curState == HUWeaponEquipState.EES_EQUIPING
    let isEquippingOtherSlot = isNeededSlot && int(nextGunSlot) != game_effect__switchToWeaponSlot
    if !isNeededSlot && !isNeededSlotEquipping
      sendEventImmediate(game_effect__attachedTo, HumanWeapSetCurrentGun(slot = uint8(game_effect__switchToWeaponSlot)))
    elif isEquippingOtherSlot
      sendEventImmediate(game_effect__attachedTo, HumanWeapSetCurrentGun(slot = uint8(game_effect__switchToWeaponSlot)))
    else
      sendEvent(game_effect__attachedTo, HumanEquipStateWeaponEquipped(slot = game_effect__switchToWeaponSlot))


[es]
def on_unarmed_game_effect_disable_switch(evt : HumanEquipStateWeaponEquipped;
                                          eid aka hero_eid : EntityId)
  find_query() <| $ [es] (eid aka effect_eid, game_effect__attachedTo : EntityId; game_effect__disableSwitchOnSlot : int)
    if game_effect__attachedTo == hero_eid && int(evt.slot) == game_effect__disableSwitchOnSlot
      effect_eid |> addSubTemplate("disabled_weapon_switch_game_effect")
      return true
    return false


[es(on_appear)]
def check_disable_switch_on_slot_on_appear(evt : Event;
                                           eid aka effect_eid : EntityId;
                                           game_effect__attachedTo : EntityId;
                                           game_effect__disableSwitchOnSlot : int)
  query(game_effect__attachedTo) <| $ [es] (human_weap__currentGunSlot : int)
    if human_weap__currentGunSlot == game_effect__disableSwitchOnSlot
      addSubTemplate(effect_eid, "disabled_weapon_switch_game_effect")


[es(on_disappear)]
def on_unarmed_game_effect_disappear(evt : Event; game_effect__attachedTo : EntityId; game_effect__switchToWeaponSlot : int; game_effect__startFromMiddle : bool = true)
  if game_effect__switchToWeaponSlot != int(HUWeaponSlots.EWS_UNARMED)
    return
  query(game_effect__attachedTo) <| $ [es] (eid aka human_eid : EntityId;
                                            human_weap__previousGunSlot : int;
                                            var human_net_phys : HumanActor&)
    deselect_slot_and_try_switch_to_previous_slot(human_eid, int(HUWeaponSlots.EWS_UNARMED), human_weap__previousGunSlot, human_net_phys)
    if game_effect__startFromMiddle
      // set reload progress to middle
      assume weapEquipState = human_net_phys.phys.currentState.weapEquipState
      weapEquipState.progress = 0.0
      weapEquipState.curState = HUWeaponEquipState.EES_EQUIPING
      weapEquipState.curSlot = weapEquipState.nextSlot


[es(on_appear)]
def save_weapon_slot_on_effect_appear(evt : Event;
                                      game_effect__attachedTo : EntityId;
                                      var game_effect__saveWeaponSlot : int&)
  query(game_effect__attachedTo) <| $ [es] (human_weap__currentGunSlot : int)
    game_effect__saveWeaponSlot = human_weap__currentGunSlot


[es(on_disappear)]
def set_weapon_slot_on_effect_disappear(evt : Event;
                                        game_effect__attachedTo : EntityId;
                                        game_effect__saveWeaponSlot : int)
  sendEvent(game_effect__attachedTo, HumanEquipStateWeaponEquipped(slot = game_effect__saveWeaponSlot))

require ecs
require DngNet
require DngHuman
require DagorSystem
require game.events.events_game
require game.es.item_equip_common
require game.es.objectives.objective_common


[es(tag=server, before=(cleanup_intentory_on_destroy_es, raid_player_extracted), on_event=CmdExtractFromBattlefieldServer)]
def save_items_on_extraction(evt : Event;
                             possessed : EntityId;
                             var currentHeroItems : Array)
  query(possessed) <| $ [es] (human_weap__gunEids : EidList;
                              inventories_owner__inventoryEids : EidList;
                              human_equipment__slots : Object;
                              human_equipment__ignoreSlotsOnExtraction : StringList)
    save_player_items(
      currentHeroItems, human_weap__gunEids, inventories_owner__inventoryEids, human_equipment__slots,
      human_equipment__ignoreSlotsOnExtraction)


[es(tag=server, before=(cleanup_intentory_on_destroy_es, raid_player_extracted), on_event=CmdExtractFromBattlefieldServer)]
def save_am_on_extraction(evt : Event;
                          eid, possessed : EntityId;
                          var currentHeroAM : int&)
  query(possessed) <| $ [es] (am_storage__value : int)
    currentHeroAM = am_storage__value - collected_for_objectives_am_count(eid)
    if currentHeroAM < 0
      logerr("[Raid Profile] player {eid} has am_storage__value = {am_storage__value} < taken for objectives count = {collected_for_objectives_am_count(eid)}")


[es(tag=server, on_disappear, REQUIRE=initial_loadout_creation)]
def landing_set_weapon_in_hands(evt : Event;
                                eid : EntityId;
                                human_weap__gunEids : EidList;
                                default_stub_melee_controller__meleeTemplate : string = "";
                                human_net_phys : HumanActor)
  let nextSlot = int(human_net_phys.phys.currentState.weapEquipState.nextSlot)
  if nextSlot != int(HUWeaponSlots.EWS_UNARMED) && human_weap__gunEids[nextSlot] != INVALID_ENTITY_ID
    return
  for weaponEid, i in human_weap__gunEids, range(int(HUWeaponSlots.EWS_MELEE))
    if weaponEid != INVALID_ENTITY_ID
      sendEvent(eid, HumanWeapSetCurrentGun(slot = uint8(i)))
      return

  if default_stub_melee_controller__meleeTemplate != ""
    sendEvent(eid, HumanWeapSetCurrentGun(slot = uint8(HUWeaponSlots.EWS_MELEE)))
  else
    sendEvent(eid, HumanWeapSetCurrentGun(slot = uint8(HUWeaponSlots.EWS_UNARMED)))


[es(tag=gameClient, after=human_gun_attach_es)]
def am_equip_weapon_client(evt : CmdWeapAttach; gun__melee : bool; var slot_attach__visible : bool&)
  if gun__melee
    query(evt.toEid) <| $ [es] (human_weap__currentGunSlot : int; isInVehicle : bool)
      if !isInVehicle
        slot_attach__visible = human_weap__currentGunSlot == int(HUWeaponSlots.EWS_MELEE)

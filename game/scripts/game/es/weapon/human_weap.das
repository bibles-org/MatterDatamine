require ecs
require app
require ecs.common
require ecs.safe
require game.es.grenade_thrower_common
require game.events.events_game
require game.events.events
require math.base
require DagorSystem
require DaWeapons
require DngHuman
require DngWeapon
require DngPhys
require Gun
require AnimV20
require game.events.inventory_events
require game.es.inventory_weapon_common
require game.es.inventory_weapon_mod_common
require game.es.weapon.human_weap_common


[es(on_appear)]
def human_weap_state_on_appear(evt : Event;
                               human_weap__currentGunSlot : int;
                               var human_net_phys : HumanActor)
  if human_weap__currentGunSlot != -1
    human_net_phys.phys.appliedCT |> set_chosen_weapon(HUWeaponSlots(human_weap__currentGunSlot))
    human_net_phys.phys.producedCT |> set_chosen_weapon(HUWeaponSlots(human_weap__currentGunSlot))
    human_net_phys.phys.currentState.weapEquipState.curSlot = HUWeaponSlots(human_weap__currentGunSlot)
    human_net_phys.phys.currentState.weapEquipState.nextSlot = HUWeaponSlots(human_weap__currentGunSlot)


//This is addendum to gun_init_ammo_prop_ids_es_event_handler for mod type ammo holders
[es(tag=server, on_appear)]
def init_mod_ammo_holders_ids(evt : Event;
                              @shared_comp gun_mods__slots : Object;
                              var gun__secondaryAmmoHolderIds : IntList?;
                              var gun__ammoHolderIds : IntList)
  get_gun_available_magazines(gun_mods__slots) <| $ [es] (magazines : StringList)
    for magazine in magazines
      gun__ammoHolderIds |> push(int(ecs_hash(string(magazine))))
      if gun__secondaryAmmoHolderIds != null
        var magTempl = getTemplateByName(string(magazine))
        if magTempl == null
          magTempl = buildTemplateByName(string(magazine))
        if magTempl != null
          let secHolderName = getTemplateComponent(*magTempl, "item_holder__boxedItemTemplate") ?? ""
          if secHolderName != ""
            let hash = ecs_hash(string(secHolderName))
            if find_index(*gun__secondaryAmmoHolderIds, int(hash)) == -1
              *gun__secondaryAmmoHolderIds |> push(int(hash))



[es(on_appear)]
def gun_mod_custom_props_init_es(evt : Event;
                                 gunAttachable__slotName : string;
                                 var slot_attach__slotId : int&)
  let animcharSlotId = animchar_getSlotId(gunAttachable__slotName)
  slot_attach__slotId = animcharSlotId


[es(tag=server, on_appear)]
def human_weap_created_server_es(evt : Event;
                                 eid : EntityId;
                                 human_weap__initialWeaponTemplates : Object;
                                 human_weap__gunEids : EidList)
  for weapTemplate in human_weap__initialWeaponTemplates
    let slotId = int(HUWeaponSlots(weapTemplate.key))
    let weaponTemplate = get_string(weapTemplate.value, "")
    if slotId >= 0 && slotId < length(human_weap__gunEids) && !empty(weaponTemplate)
      create_weapon_in_slot(weaponTemplate, slotId, eid)


[es(tag=server, on_appear, before=gun_init_es)]
def gun_init_ammo_prop_ids(evt : Event;
                           eid : EntityId;
                           gun__ammoHolders : StringList;
                           var gun__ammoHolderIds : IntList)
  for ammoHolderName in gun__ammoHolders
    if ammoHolderName == ""
      logerr("Unacceptable to have empty \"ammoHolder\" in template <{getEntityTemplateName(eid)}>")
    let ammoHolderNameStr = string(ammoHolderName)
    gun__ammoHolderIds |> push(int(ecs_hash(ammoHolderNameStr)))


[es(tag=netClient)]
def clear_client_pending_gun_creation_waits_es(evt : EventEntityManagerBeforeClear)
  remove_delayed_actions_client_wait_for_gun_creation()


// Tracking the creation of non-physical projectiles (displayed in hand)
[es(tag=netClient, REQUIRE_NOT=phys_obj_net_phys, on_appear)]
def replace_local_projectile_es(evt : Event;
                                eid : EntityId;
                                shell__owner : EntityId;
                                var slot_attach__attachedTo aka server_slot_attach__attachedTo : EntityId&;
                                var slot_attach__slotId aka server_slot_attach__slotId : int&;
                                var slot_attach__visible aka server_slot_attach__visible : bool&)
  // The local and the server projectiles must have the same owner
  // The owner of a long-living projectile may be already destroyed

  // human_weap__localProjectileEid is not found means the projectile's owner was destroyed
  query(shell__owner) <| $ [es] (var human_weap__localProjectileEid : EntityId&)
    let serverProjectileEid = eid

    // localProjectileEid == ecs::INVALID_ENTITY_ID means there was no client-side projectile or it's already destroyed
    // serverProjectileEid == localProjectileEid means this ES is processing the local projectile (name "serverProjectileEid" is misleading)
    if human_weap__localProjectileEid == INVALID_ENTITY_ID || serverProjectileEid == human_weap__localProjectileEid
      return
    // If there are two projectiles (local and server's) with the same owner, the local should be destroyed

    // Copy the visibility and attachment state from the local projectile, so if it was already displayed, new projectile will be too
    // Local projectile may not have the components if it's not yet created, hence the ECS_GET_OR
    query(human_weap__localProjectileEid) <| $ [es] (slot_attach__attachedTo aka local_slot_attach__attachedTo : EntityId)
      server_slot_attach__attachedTo = local_slot_attach__attachedTo

    query(human_weap__localProjectileEid) <| $ [es] (slot_attach__slotId aka local_slot_attach__slotId : int)
      server_slot_attach__slotId = local_slot_attach__slotId

    query(human_weap__localProjectileEid) <| $ [es] (slot_attach__visible aka local_slot_attach__visible : bool)
      server_slot_attach__visible = local_slot_attach__visible

    // The local projectile should be destroyed even if its asynchronous creation process is yet in progress
    destroyEntity(human_weap__localProjectileEid)
    human_weap__localProjectileEid = INVALID_ENTITY_ID


[es(tag=netClient, on_disappear)]
def destroy_local_projectile_es(evt : Event;
                                var human_weap__localProjectileEid : EntityId&)
  // Destroying the grenade in hand, when the human_weap is destroyed
  destroyEntity(human_weap__localProjectileEid)
  human_weap__localProjectileEid = INVALID_ENTITY_ID


[es(REQUIRE=human_weap, REQUIRE_NOT=human_input, REQUIRE_NOT=disableUpdate)]
def human_weap_post_phys_es(evt : CmdPostPhysUpdate;
                            eid : EntityId;
                            transform : float3x4;
                            isInVehicle : bool;
                            humap_weap__useGrenadeInVehicle : bool = false;
                            human_weap__lockedGrenadeThrowingCounter : int = 0;
                            entity_mods__shotDeviationMult : float = 1.0;
                            entity_mods__rotationShotSpreadDecrMult : float = 1.0;
                            entity_mods__aimingAfterFireMult : float = 1.0;
                            entity_mods__boltActionMult : float = 1.0;
                            entity_mods__deviationBufferSizeMult : float = 1.0;
                            entity_mods__shotDeviationAdd : float = 0.0;
                            human_weap__fastThrowExclusive : bool = true;
                            human_unarmed__active : bool = false;
                            isAlive : bool = true;
                            isDowned : bool = false;
                            human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID;
                            var human_net_phys : HumanActor;
                            human_weap__gunEids : EidList;
                            var human_weap__throwMode : bool&)
  if isAlive && !isDowned
    let dt = evt.dt
    let isForReal = evt.isForReal
    let atTime = float(evt.tick) * dt
    let gunDir = human_net_phys.phys.currentState.gunDir
    let physTransform = human_net_phys.phys.currentState.location |> location_makeTM()

    let updCtx = GunUpdateCtx(
      dt = dt,
      atTime = atTime,
      isForReal = isForReal,
      eid = eid,
      isDowned = isDowned,
      isThrowingAllowed = human_weap__lockedGrenadeThrowingCounter == 0 && (humap_weap__useGrenadeInVehicle || !isInVehicle),
      shotDeviationMult = entity_mods__shotDeviationMult,
      rotationShotSpreadDecrMult = entity_mods__rotationShotSpreadDecrMult,
      aimingAfterFireMult = entity_mods__aimingAfterFireMult,
      boltActionMult = entity_mods__boltActionMult,
      shotDeviationAdd = entity_mods__shotDeviationAdd,
      fastThrowExclusive = human_weap__fastThrowExclusive,
      deviationBufferSizeMult = entity_mods__deviationBufferSizeMult)

    human_weap_update(human_net_phys, human_weap__gunEids, human_weap__throwMode,
                      updCtx,  transform, gunDir, gunDir, physTransform,
                      human_net_phys.phys.appliedCT,
                      human_unarmed__active, human_attached_gun__attachedGunEid)


[es(tag=server, before=human_weap_post_phys_es, REQUIRE_NOT=disableUpdate)]
def human_weap_es(evt : CmdPostPhysUpdate;
                  eid : EntityId;
                  human_weap__gunEids : EidList;
                  human_net_phys : HumanActor;
                  human_inventory__entityToUse : EntityId;
                  action__running : bool = false;
                  isInVehicle : bool = false;
                  isPassenger : bool = false;
                  isInVehicleHidden : bool = false;
                  isDowned : bool = false;
                  human_sec_anim__hideWeapon : bool = false;
                  human_sec_anim__hideMelee : bool = false;
                  human_sec_anim__play : bool = false;
                  human_unarmed__hiddenWeapon : bool = false;
                  state_counter__disableWeaponSwitch : int = 0;
                  burning__isPuttingOut : bool = false;
                  human_weap__blockAiming : bool = false;
                  isAlive : bool;
                  human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID;
                  var human_weap__currentGunSlot : int&;
                  var human_weap__previousGunSlot : int&)
  if isAlive
    human_weap_es_impl(
      human_weap__currentGunSlot, human_weap__previousGunSlot, get_sync_time(), eid, human_weap__gunEids,
      human_net_phys, human_inventory__entityToUse, action__running,
      isInVehicle, isPassenger, isInVehicleHidden, isDowned, human_sec_anim__hideWeapon, human_sec_anim__hideMelee,
      human_sec_anim__play, human_unarmed__hiddenWeapon, state_counter__disableWeaponSwitch, burning__isPuttingOut,
      human_weap__blockAiming, human_attached_gun__attachedGunEid)


[es(track=(isAlive, isDowned), on_event=EventEntityDied)]
def human_weap_drop_grenade_es(evt : Event;
                               eid : EntityId;
                               isAlive : bool;
                               isDowned : bool;
                               human_weap__gunEids : EidList;
                               human_weap__throwMode : bool;
                               human_net_phys : HumanActor)
  if isAlive && !isDowned
    return

  if human_weap__throwMode
    query(human_weap__gunEids[int(HUWeaponSlots.EWS_GRENADE)]) <| $ [es] (grenade_thrower__projectileEntity : EntityId)
      query(grenade_thrower__projectileEntity) <| $ [es] (slot_attach__attachedTo : EntityId;
                                                          shell__shell_id__shell_id : int;
                                                          var active : bool&;
                                                          var shell__explTime : float?)
        if !slot_attach__attachedTo
          return
        if !active && shell__explTime != null
          // If the soldier is downed before grenade's cookProgressTime, activate and set explosion timer anyway
          detonation_get_props(shell__shell_id__shell_id) <| $(detonationProps : DetonationProps)
            *shell__explTime = get_sync_time() + detonationProps.timer

        active = true
        query(eid) <| $ [es] (human_net_phys__velocity : float3)
          assume curState = human_net_phys.phys.currentState
          var tm = IDENT_TM
          let locTm = curState.location |> location_makeTM()
          human_net_phys.phys |> human_phys_calcGunTm(PrecomputedPresetMode.FPV,
                                                      locTm,
                                                      curState.gunAngles.y,
                                                      curState.leanPosition,
                                                      curState.height,
                                                      tm)
          let curTime = get_sync_time()
          let isForReal = true
          let rndSeed = phys_time_to_seed(curTime)

          let dir = (!isAlive ? normalize(float3(0.14, -0.99, 0.0)) // Approximative down
                              : human_net_phys.phys.currentState.gunDir)

          using(dir, dir, human_net_phys__velocity, tm, tm) <| $(var gloc : GunLocation#)
            using() <| $(var gtrlNew : GunControls#)
              gtrlNew.shoot = true
              gtrlNew.wishShoot = false
              gtrlNew.boltActionMult = 1.0
              gtrlNew.timeStep = 0.01
              sendEventImmediate(
                human_weap__gunEids[int(HUWeaponSlots.EWS_GRENADE)],
                CmdGunUpdate(
                  atTime = curTime,
                  isForReal = isForReal,
                  seed = rndSeed,
                  gctrl := gtrlNew,
                  gloc := gloc))
      clear_projectile_entity(eid, grenade_thrower__projectileEntity)


[es(tag=server)]
def human_weap_req_switch_firing_mode_es(evt : HumanWeapRequestSwitchFiringMode;
                                         human_weap__gunEids : EidList)
  let slotId = int(evt.slotId)
  let modeId = int(evt.modeId)
  if slotId >= length(human_weap__gunEids)
    return

  query(human_weap__gunEids[slotId]) <| $ [es] (var gun : Gun; var gun__firingModeIndex : int&)
    if gun |> gun_checkFiringModeIndex(modeId)
      gun |> gun_setFiringModeIndex(evt.modeId)
      gun__firingModeIndex = modeId


[es]
def human_weap_set_current_gun_es(evt : HumanWeapSetCurrentGun;
                                  eid : EntityId;
                                  human_weap__currentGunSlot : int;
                                  var human_net_phys : HumanActor)
  let fromSlotId = human_weap__currentGunSlot
  let toSlotId = int(evt.slot)
  human_net_phys.phys.producedCT |> set_chosen_weapon(HUWeaponSlots(toSlotId))
  if fromSlotId >= 0
    human_net_phys.phys.currentState.weapEquipState.curSlot = HUWeaponSlots(fromSlotId)
  human_net_phys.phys.currentState.weapEquipState.nextSlot = HUWeaponSlots(toSlotId)
  if fromSlotId == toSlotId
    sendEventImmediate(eid, HumanEquipStateWeaponEquipped(slot = toSlotId))


[es]
def human_weap_weap_throw_back_abort_es(evt : HumanWeapThrowBackAbort;
                                        var human_weap__throwMode : bool&;
                                        var human_net_phys : HumanActor)
  if human_weap__throwMode && human_net_phys.phys.appliedCT |> is_control_bit_set(HumanPhysControlType.HCT_THROW_BACK)
    human_weap__throwMode = false
    human_net_phys.phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_THROW_BACK, false)

[es(tag=server, track=(human_weap__gunEids, itemContainer))]
def human_weap_update_total_count_es(evt : Event;
                                     human_weap__gunEids : EidList;
                                     itemContainer : EidList)
  for i in iter_range(human_weap__gunEids)
    update_total_ammo(human_weap__gunEids[i], itemContainer)
    query(human_weap__gunEids[i]) <| $ [es] (gun_mods__curModInSlots : Object)
      for gunMod in gun_mods__curModInSlots
        let gunModEid = get_Eid(gunMod.value) ?? INVALID_ENTITY_ID
        if gunModEid != INVALID_ENTITY_ID
          update_total_ammo(gunModEid, itemContainer)


[es(tag=server, REQUIRE=eid)]
def set_gun_insvisible(evt : EventOnWeaponUnequipped)
  query(evt.weaponEid) <| $ [es] (var slot_attach__visible : bool&)
    slot_attach__visible = evt.toInventoryEid == INVALID_ENTITY_ID


[es(REQUIRE=eid)]
def set_gun_visible_on_ground_drop(evt : EventOnItemDrop)
  query(evt.itemEid) <| $ [es(REQUIRE=gun__melee)] (var slot_attach__visible : bool&)
    slot_attach__visible = true


[es(REQUIRE=eid)]
def set_gun_visible_from_ground_pickup(evt : EventOnItemPickup)
  query(evt.itemEid) <| $ [es(REQUIRE=gun__melee)] (var slot_attach__visible : bool&)
    slot_attach__visible = false


[es(tag=gameClient)]
def check_selected_weapon(evt : EventOnWeaponChanged;
                          eid : EntityId;
                          default_stub_melee_controller__meleeTemplate : string = "";
                          default_stub_melee_controller__meleeItemEid : EntityId = INVALID_ENTITY_ID;
                          human_net_phys : HumanActor;
                          human_weap__gunEids : EidList)
  let curWishSlot = int(human_net_phys.phys.producedCT.chosenWeapon)
  let isDroppedFromCurrentSlot = evt.slotId == curWishSlot && evt.newWeaponEid == INVALID_ENTITY_ID
  if isDroppedFromCurrentSlot
    if (curWishSlot == int(HUWeaponSlots.EWS_MELEE) &&
      default_stub_melee_controller__meleeTemplate != "")
      return

    for i in iter_range(human_weap__gunEids)
      if i == evt.slotId
        continue
      if i != int(HUWeaponSlots.EWS_GRENADE) && human_weap__gunEids[i] != INVALID_ENTITY_ID
        sendEvent(eid, HumanWeapSetCurrentGun(slot = uint8(i)))
        return
      if i == int(HUWeaponSlots.EWS_GRENADE) && (get_int(human_weap__gunEids[i], "gun__ammo") ?? 0) > 0
        sendEvent(eid, HumanWeapSetCurrentGun(slot = uint8(i)))
        return
    sendEvent(eid, HumanWeapSetCurrentGun(slot = uint8(HUWeaponSlots.EWS_UNARMED)))
    return

  var hasOnlyDefaultMelee = true
  for i in iter_range(human_weap__gunEids)
    if i < int(HUWeaponSlots.EWS_MELEE) && human_weap__gunEids[i] != INVALID_ENTITY_ID
      hasOnlyDefaultMelee = false
      break
    elif (i == int(HUWeaponSlots.EWS_MELEE) &&
          human_weap__gunEids[i] != INVALID_ENTITY_ID &&
          human_weap__gunEids[i] != default_stub_melee_controller__meleeItemEid)
      hasOnlyDefaultMelee = false
      break
    elif i == int(HUWeaponSlots.EWS_GRENADE) && (get_int(human_weap__gunEids[i], "gun__ammo") ?? 0) > 0
      hasOnlyDefaultMelee = false
      break

  if (curWishSlot == int(HUWeaponSlots.EWS_MELEE) && hasOnlyDefaultMelee && evt.newWeaponEid != INVALID_ENTITY_ID &&
      evt.slotId <= int(HUWeaponSlots.EWS_GRENADE))
    sendEvent(eid, HumanWeapSetCurrentGun(slot = uint8(evt.slotId)))
    return


[es]
def check_selected_weapon_on_swap(evt : EventOnWeaponSwap;
                                  eid : EntityId;
                                  var human_weap__currentGunSlot : int&)
  var firstSlotId = evt.firstSlotId
  var secondSlotId = evt.secondSlotId
  if human_weap__currentGunSlot == firstSlotId
    if evt.firstWeaponEid == INVALID_ENTITY_ID
      swap(firstSlotId, secondSlotId)
    human_weap__currentGunSlot = secondSlotId
    sendEvent(eid, HumanWeapSetCurrentGun(slot = uint8(firstSlotId)))
  elif human_weap__currentGunSlot == secondSlotId
    if evt.secondWeaponEid == INVALID_ENTITY_ID
      swap(firstSlotId, secondSlotId)
    human_weap__currentGunSlot = firstSlotId
    sendEvent(eid, HumanWeapSetCurrentGun(slot = uint8(secondSlotId)))

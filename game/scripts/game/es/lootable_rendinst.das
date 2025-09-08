require ecs
require ecs.safe
require math.random
require strings
require math.base
require level
require RiDestr
require RendInst
require DagorMath
require DagorSystem
require game.events.events
require game.events.events_game
require game.utils.sound_utils
require game.es.inventory_common
require game.es.generate_loot_common
require game.es.riextra_common
require ecs.common
require DngNet
require game.events.events_active_matter
require active_matter.game.es.loot_preset_common
require game.es.inventory_item_common


[es(tag=server, REQUIRE=search_lootable_rendinst_invoice, on_appear)]
def start_use_lootable_rendinst(evt : Event;
                                interactable_invoice__parentInteractableEid : EntityId)
  query(interactable_invoice__parentInteractableEid) <| $ [es] (transform : float3x4;
                                                                lootable_rendinst__onStartLootingSoundPath : string)
    broadcast_net_sound(interactable_invoice__parentInteractableEid, lootable_rendinst__onStartLootingSoundPath, transform[3])


[es(on_appear, on_event=EventLevelLoaded)]
def lootable_rendinst_prepare_riextra(evt : Event;
                                      lootable_rendinst__riAfterLoot : string;
                                      ri_extra__name : string)
  if !is_level_loaded()
    return
  if lootable_rendinst__riAfterLoot != "" && lootable_rendinst__riAfterLoot != ri_extra__name
    let resIdx = ensure_riextra_res_idx(lootable_rendinst__riAfterLoot)
    if resIdx >= 0
      rendinst_updateRiExtraReqLod(uint(resIdx), 0u)


[es(tag=server, REQUIRE=lootable_rendinst)]
def used_lootable_rendinst(evt : EventDroppedLoot;
                           eid : EntityId;
                           transform : float3x4;
                           lootable_rendinst__riAfterLoot : string = "";
                           lootable_rendinst__onSuccessfulLootSoundPath : string;
                           lootable_rendinst__onEmptyLootSoundPath : string;
                           lootable_rendinst__infiniteLoot : bool = false;
                           var use_object__enabled : bool&)
  if evt.count > 0
    broadcast_net_sound(eid, lootable_rendinst__onSuccessfulLootSoundPath, transform[3])
  else
    broadcast_net_sound(eid, lootable_rendinst__onEmptyLootSoundPath, transform[3])

  if lootable_rendinst__infiniteLoot
    return

  if !empty(lootable_rendinst__riAfterLoot)
    send_net_event(eid, CmdReplaceRiExtraRes(
      riExtra := lootable_rendinst__riAfterLoot,
      destroyPrevRi = true,
      addPrevRiToRestorables = true,
      createPrevRiDestr = false))
    use_object__enabled = false
  else
    destroyEntity(eid)


[es(REQUIRE=lootable_rendinst, on_disappear)]
def remove_lootable_rendinst(evt : Event; ri_extra__handle : riex_handle_t; ri_extra : RiExtraComponent const?)
  // All RI will be cleared by clearRIGen,
  // and due to the inability to predict what will be deleted first (entity of the scene or this RI),
  // we can get into the assert when the list of RI has already been cleared by clearRIGen
  if is_level_unloading()
    return
  if ri_extra != null
    rendinst_delRIGenExtra(ri_extra.handle)
  else
    rendinst_delRIGenExtra(ri_extra__handle)


[es(tag=server, on_event=EventLevelLoaded, on_appear)]
def create_lootable_rendinsts(evt : Event;
                              eid : EntityId;
                              transform : float3x4;
                              lootable_rendinsts__list : Array;
                              lootable_rendinsts__allowSpawnInForbiddenZone : bool = false;
                              lootable_rendinsts__restrictToBoundingBox : bool = false)
  if !is_level_loaded()
    return
  var sphere = BSphere3()
  find_query() <| $ [es(REQUIRE=moving_zone__sourcePos)] (sphere_zone__radius : float; transform : float3x4)
    sphere = BSphere3(transform[3], sphere_zone__radius * 2.f)
    print("[Lootable Rendinsts] Creating entities in zone with center <{transform[3]}> and radius <{sphere_zone__radius}>")
    return true

  let itm = inverse(transform)

  for entity in lootable_rendinsts__list
    let lootableRendinstsObjPtr = entity as Object
    if lootableRendinstsObjPtr == null
      continue
    assume lootableRendinstsObj = *lootableRendinstsObjPtr

    let riName = lootableRendinstsObj.ri_name ?? ""
    let openedRiName = lootableRendinstsObj.ri_after_loot_name ?? ""
    let containerCapacity = lootableRendinstsObj.container_capacity ?? 50.0
    let lootPreset = lootableRendinstsObj.loot_preset ?? ""
    let dropPreset = lootableRendinstsObj.drop_preset ?? ""
    let sound = lootableRendinstsObj.openable_ri_sound ?? ""
    let turnDir = lootableRendinstsObj.turn_dir ?? false
    let useTimeRange = lootableRendinstsObj.use_time ?? float2(-1) // -1 value force auto calculation
    let customName = lootableRendinstsObj.container_name ?? ""
    let customType = lootableRendinstsObj.container_type ?? ""
    let additionalTemplate = lootableRendinstsObj.additional_template ?? ""
    let resIdx = get_rigen_extra_res_idx(riName)
    if resIdx < 0
      logwarn("lootable_rendinsts: {eid}:{getEntityTemplateName(eid)} contains unknown ri name '{riName}'")
      continue
    var counter = 0
    getRiGenExtraInstances(resIdx, sphere) <| $(handles : array<riex_handle_t>#)
      for handle in handles
        var tm : float3x4
        get_rigen_extra_matrix(handle, tm)

        if !lootable_rendinsts__allowSpawnInForbiddenZone && is_loot_point_in_forbidden_zone(tm[3])
          continue

        if lootable_rendinsts__restrictToBoundingBox && !(IDENT_BBOX & (itm * tm[3]))
          continue

        ++counter

        if turnDir
          tm[0] = -tm[2]
          tm[2] = cross(tm[1], tm[0])

        let templName = empty(additionalTemplate) ? "lootable_rendinst" : add_sub_template_name("lootable_rendinst", additionalTemplate)
        createEntity(templName) <| $(var init)
          init |> set("transform", tm)
          init |> set("ri_extra__handle", handle)
          init |> set("openable_ri__closed", riName)
          init |> set("openable_ri_sound__path", sound)
          init |> set("ri_preload__name", empty(openedRiName) ? riName : openedRiName)
          init |> set("human_inventory__maxVolume", containerCapacity)
          init |> set("loot_drop_system__lootPreset", lootPreset)
          init |> set("loot_drop_system__dropPreset", dropPreset)
          init |> set("item__useTime", rnd_float(useTimeRange))
          if !empty(customName)
            init |> set("itemContainer__name", customName)
          if !empty(customType)
            init |> set("itemContainer__type", customType)
    print("[Lootable Rendinsts] Creating <{counter}> entities for <{riName}> rendinst")


[es(tag=server, REQUIRE=search_lootable_rendinst_invoice)]
def on_search_lootable_rendinst_invoice(evt : CmdExecInteractionAction; interactable_invoice__parentInteractableEid : EntityId)
  sendEvent(interactable_invoice__parentInteractableEid, EventDropLootRequest())


[es(tag=server, REQUIRE=lootable_rendinst__useTime, on_appear, before=start_use_lootable_rendinst)]
def reset_interactable_use_time(evt : Event;
                                interactable_invoice__parentInteractableEid : EntityId;
                                var interactable_invoice__duration : float&)
  query(interactable_invoice__parentInteractableEid) <| $ [es] (item__useTime : float)
    interactable_invoice__duration = item__useTime


[es(tag=server, on_appear, on_event=EventRendinstsLoaded)]
def lootable_rendinst_autocalculate_use_time(evt : Event; ri_extra__handle : riex_handle_t; var item__useTime : float&)
  if item__useTime <= 0.
    let riType = handle_to_ri_type(ri_extra__handle)
    let collres = get_ri_gen_extra_collres(int(riType))
    if collres != null
      let size = collres.boundingBox.width
      item__useTime = clamp(abs(size.x * size.y * size.z) * 1.5, 0.1, 0.3) // TODO: rebalance this coef-s


[es(tag=server, on_appear, REQUIRE=external_inventory_container, REQUIRE_NOT=loot_drop_system_delayed_loot_generation__generated)]
def lootable_rendinst_init_inventory(evt : Event;
                                     eid : EntityId;
                                     loot_drop_system__lootPreset : string;
                                     var human_inventory__maxVolumeInt : int?;
                                     human_inventory__additionalOverVolume = 100)
  var capacityOccupied = 0.0
  loot_preset_generate(loot_drop_system__lootPreset, capacityOccupied) <| $(items)
    for item in items
      let newName = get_item_in_container_template(item)
      if newName == ""
        return
      createEntity(newName) <| $(var init)
        init |> set("item__containerOwnerEid", eid)
  if human_inventory__maxVolumeInt != null
    *human_inventory__maxVolumeInt = max(*human_inventory__maxVolumeInt, human_inventory__additionalOverVolume + int(capacityOccupied * 10.0))


[es(tag=server, on_event=(CmdUse, EventExternalInventoryContainerAccessedByHero))]
def loot_drop_system_delayed_loot_generation(evt : Event;
                                             eid : EntityId;
                                             loot_drop_system__lootPreset : string;
                                             var loot_drop_system_delayed_loot_generation__generated : bool&;
                                             var human_inventory__maxVolumeInt : int?;
                                             human_inventory__additionalOverVolume = 100)
  if loot_drop_system_delayed_loot_generation__generated
    return

  loot_drop_system_delayed_loot_generation__generated = true

  var capacityOccupied = 0.0
  loot_preset_generate(loot_drop_system__lootPreset, capacityOccupied) <| $(items)
    for item in items
      create_item_in_inventory_container(item, eid)
  if human_inventory__maxVolumeInt != null
    *human_inventory__maxVolumeInt = max(*human_inventory__maxVolumeInt, human_inventory__additionalOverVolume + int(capacityOccupied * 10.0))


[es(tag=server, on_event=(CmdUse, EventExternalInventoryContainerAccessedByHero),
    REQUIRE=regenerateLoot, before=loot_drop_system_delayed_loot_generation)]
def loot_drop_system_empty_regeneratable_container(evt : Event;
                                                   var loot_drop_system_delayed_loot_generation__generated : bool&;
                                                   var itemContainer : EidList;
                                                   var human_inventory__currentVolume : int&)
  if !loot_drop_system_delayed_loot_generation__generated
    return
  loot_drop_system_delayed_loot_generation__generated = false
  human_inventory__currentVolume = 0
  for itemEid in itemContainer
    destroyEntity(itemEid)
  itemContainer |> clear()

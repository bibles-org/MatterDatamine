require ecs
require ecs.common
require ecs.safe
require ecs.extra_set
require math.base
require math.random
require inventory
require DagorRandom
require game.events.events
require ecs.common
require DagorMath
require DagorSystem
require DngNet
require pathfinder
require game.es.inventory_drop_common
require game.events.events_active_matter
require game.es.inventory_item_common
require active_matter.game.es.loot_preset_common


[es(tag=server)]
def loot_drop_system_create_loot(evt : EventDropLootRequest;
                                 eid : EntityId;
                                 loot_drop_system__lootPreset : string;
                                 loot_drop_system__dropPreset : string)
  var list : array<string>
  loot_preset_generate(loot_drop_system__lootPreset) <| $(items)
    for item in items
      list |> push(item)
  if !empty(list)
    createEntitySync(loot_drop_system__dropPreset) <| $(var init)
      init |> set("drop_preset__itemTemplates", list)
      init |> set("drop_preset__ownerEid", eid)
  else
    sendEvent(eid, EventDroppedLoot(count = 0))


[es(tag=server, REQUIRE=loot_drop_system__dropRequestOnRiDestruction)]
def drop_loot_on_ri_destruction(evt : EventOnRendinstDestruction;
                                eid : EntityId;
                                var loot_drop_system__lootPreset : das_string)
  sendEventImmediate(eid, EventDropLootRequest())
  loot_drop_system__lootPreset := ""


[es(tag=server, on_appear)]
def loot_drop_system_drop_loot_finalizer(evt : Event;
                                         eid : EntityId;
                                         drop_preset__itemTemplates : StringList;
                                         drop_preset__ownerEid : EntityId)
  destroyEntity(eid)
  sendEvent(drop_preset__ownerEid, EventDroppedLoot(count = length(drop_preset__itemTemplates)))


[es(tag=server, on_appear, before=loot_drop_system_drop_loot_finalizer)]
def loot_drop_system_forward_sector_drop_loot(evt : Event;
                                              drop_preset__itemTemplates : StringList;
                                              drop_preset__ownerEid : EntityId;
                                              drop_preset__dropRangeRng : float2;
                                              drop_preset__dropAnglesRng : float2)
  query(drop_preset__ownerEid) <| $ [es] (transform aka owner_transform : float3x4;
                                          drop_preset_owner__dropOffset : float3 = float3())
    let forwardOffsetLen = rnd_float(drop_preset__dropRangeRng.x, drop_preset__dropRangeRng.y)
    for itemTempl in drop_preset__itemTemplates
      var tm = IDENT_TM
      let dropAngle = rnd_float(drop_preset__dropAnglesRng.x, drop_preset__dropAnglesRng.y)
      let sideOffsetLen = forwardOffsetLen * sin(deg_to_rad(dropAngle))
      let dropPoint = owner_transform[3] + rotate(owner_transform, drop_preset_owner__dropOffset)
      tm[3] = dropPoint + owner_transform[0] * forwardOffsetLen + owner_transform[2] * sideOffsetLen
      drop_item_on_ground(tm)

      let templ = getTemplateByName(string(itemTempl))
      let dropTm = templ != null ? get_item_template_drop_tm(*templ) : IDENT_TM
      createEntity("{itemTempl}+item_in_world") <| $(var init)
        set(init, "transform", tm * dropTm)


[es(tag=server, on_appear, before=loot_drop_system_drop_loot_finalizer)]
def loot_drop_system_circle_drop_loot(evt : Event;
                                      drop_preset__itemTemplates : StringList;
                                      drop_preset__ownerEid : EntityId;
                                      drop_preset__circlePhysFallHeightRng : float2;
                                      drop_preset__circlePhysFallRangeRng : float2;
                                      drop_preset__circlePhysFallAnglesRng : float2;
                                      drop_preset__circlePhysFallImpulseVelocityRng : float2;
                                      drop_preset__circlePhysFallImpulseOmegaRng : float2)
  query(drop_preset__ownerEid) <| $ [es] (transform aka owner_transform : float3x4;
                                          drop_preset_owner__dropOffset : float3 = float3())
    for itemTempl in drop_preset__itemTemplates
      var tm = IDENT_TM
      let dropAngle = deg_to_rad(rnd_float(drop_preset__circlePhysFallAnglesRng.x, drop_preset__circlePhysFallAnglesRng.y))
      var offset : float3
      offset.y = rnd_float(drop_preset__circlePhysFallHeightRng)
      sincos(dropAngle, offset.z, offset.x)

      let offsetLen = rnd_float(drop_preset__circlePhysFallRangeRng.x, drop_preset__circlePhysFallRangeRng.y)
      tm[3] = owner_transform[3] + rotate(owner_transform, (offset * offsetLen) + drop_preset_owner__dropOffset)


      let templ = getTemplateByName(string(itemTempl))
      let dropTm = templ != null ? get_item_template_drop_tm(*templ) : IDENT_TM
      createEntity("{itemTempl}+item_in_world_phys+phys_obj_init_impulse") <| $(var init)
        set(init, "transform", tm * dropTm)
        set(init, "phys_obj_init_impulse__velocityRng", drop_preset__circlePhysFallImpulseVelocityRng)
        set(init, "phys_obj_init_impulse__omegaRng", drop_preset__circlePhysFallImpulseOmegaRng)


[es(tag=server, on_appear, before=loot_drop_system_drop_loot_finalizer)]
def loot_drop_system_inside_owner_drop_loot(evt : Event;
                                            drop_preset__itemTemplates : StringList;
                                            drop_preset__ownerEid : EntityId;
                                            drop_preset__dropInsideOwnerOffset : float3)
  query(drop_preset__ownerEid) <| $ [es] (transform : float3x4)
    for itemTempl in drop_preset__itemTemplates
      var tm = transform
      tm[3] += drop_preset__dropInsideOwnerOffset
      createEntity("{itemTempl}+item_in_world") <| $(var init)
        set(init, "transform", tm)
        set(init, "item__alreadyLooted", true) // for dropTm work


[es(tag=server, on_appear, before=loot_drop_system_drop_loot_finalizer)]
def loot_drop_system_in_places_from_list_drop_loot(evt : Event;
                                                   drop_preset__itemTemplates : StringList;
                                                   drop_preset__ownerEid : EntityId;
                                                   drop_in_places_from_list__placesList : TMatrixList)
  query(drop_preset__ownerEid) <| $ [es] (transform : float3x4)
    let itemsToDrop = min(length(drop_preset__itemTemplates), length(drop_in_places_from_list__placesList))
    var idxs : array<int>
    for i in range(length(drop_in_places_from_list__placesList))
      idxs |> push(i)
    idxs |> shuffle()

    for i in range(itemsToDrop)
      let itemTemplate = getTemplateByName(string(drop_preset__itemTemplates[i]))
      let dropTm = itemTemplate != null ? get_item_template_drop_tm(*itemTemplate) : IDENT_TM
      createEntity("{drop_preset__itemTemplates[i]}+item_in_world") <| $(var init)
        set(init, "transform", transform * drop_in_places_from_list__placesList[idxs[i]] * dropTm)


[es(tag=server, on_appear, before=loot_drop_system_drop_loot_finalizer, REQUIRE=drop_preset__freeFall)]
def loot_drop_system_freefall_drop_loot(evt : Event;
                                        drop_preset__itemTemplates : StringList;
                                        drop_preset__ownerEid : EntityId)
  query(drop_preset__ownerEid) <| $ [es] (transform aka owner_transform : float3x4)
    for itemTempl in drop_preset__itemTemplates
      var tm = IDENT_TM
      tm[3] = owner_transform[3]
      createEntity("{itemTempl}+shell_free_fall_effect") <| $(var init)
        set(init, "transform", tm)

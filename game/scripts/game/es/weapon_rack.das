require ecs
require ecs.safe
require ecs.common
require math.base
require math.random
require DagorSystem
require DagorMath
require gameObject
require AnimV20
require GeomNodeTree


[es(tag=gameClient, on_appear)]
def init_racked_slot_item_id(evt : Event; racked_item_slot__itemTemplate : string; var racked_item_slot__itemId : int&)
  let templ = getTemplateByName(racked_item_slot__itemTemplate)
  if templ == null
    logerr("racked_item_slot has invelid template '{racked_item_slot__itemTemplate}'")
    return
  let protoName = getTemplateComponent(*templ, "item__proto") ?? ""
  racked_item_slot__itemId = int(ecs_hash(protoName))


[es(tag=gameClient, on_event=EventLevelLoaded)]
def init_gunwall_from_game_obj(evt : Event;
                               gunwall_template : string;
                               gunwall_obj_name : string)
  let gameObjectsEid = getSingletonEntity("game_objects")
  query(gameObjectsEid) <| $ [es] (game_objects : GameObjects)
    let box = BBox3(float3(), float3(10000))
    game_objects |> get_scene_game_objects_by_name(gunwall_obj_name) |> for_scene_game_objects(box) <| $ [unused_argument(ni)] (ni : uint; tm : float3x4#)
      createEntity(gunwall_template) <| $(init)
        let gunwallSize = float3(length(tm[0]), length(tm[1]), length(tm[2]))
        var gunwallTM = tm
        gunwallTM[0] /= gunwallSize.x
        gunwallTM[1] /= gunwallSize.y
        gunwallTM[2] /= gunwallSize.z
        init |> set("gunwall__tm", gunwallTM)
        init |> set("gunwall__size", gunwallSize)


[es(tag=gameClient, on_appear)]
def init_gunwall_on_appear(evt : Event;
                           gunwall__cellDim : int2;
                           gunwall__size : float3;
                           var gunwall__cellSize : float2&;
                           var gunwall__cells : EidList)
  gunwall__cellSize = float2(safediv(gunwall__size.x, float(gunwall__cellDim.x)), safediv(gunwall__size.y, float(gunwall__cellDim.y)))
  resize(gunwall__cells, gunwall__cellDim.x * gunwall__cellDim.y)


def is_cells_free(grid : EidList; grid_size : int2; cellFrom : int2; cellTo : int2) : bool
  if cellTo.x > grid_size.x || cellTo.y > grid_size.y
    return false
  var cell = cellFrom
  while cell.y < cellTo.y
    while cell.x < cellTo.x
      let cellId = cell.y * grid_size.x + cell.x
      if grid[cellId] != INVALID_ENTITY_ID
        return false
      cell.x += 1
    cell.y += 1
    cell.x = cellFrom.x
  return true


def set_grid_value(var grid : EidList; grid_size : int2; cellFrom : int2; cellTo : int2; value : EntityId)
  var cell = cellFrom
  while cell.y < cellTo.y
    while cell.x < cellTo.x
      let cellId = cell.y * grid_size.x + cell.x
      grid[cellId] = value
      cell.x += 1
    cell.y += 1
    cell.x = cellFrom.x


def find_free_place_on_grid(grid : EidList; grid_size : int2; require_size : int2; var cell_start : int2&)
  var gridIdxsX : array<int>
  for i in range(grid_size.x - require_size.x + 1)
    gridIdxsX |> push(i)
  gridIdxsX |> shuffle()

  for y in range(grid_size.y - require_size.y + 1)
    for x in gridIdxsX
      let cell_end = int2(x, y) + require_size
      if is_cells_free(grid, grid_size, int2(x, y), cell_end)
        cell_start = int2(x, y)
        return true
  return false


def get_mods_box(item_eid : EntityId; item_animchar : AnimcharBaseComponent; gun_mods__curModInSlots : Object) : BBox3
  var box = BBox3()
  for gunMod in gun_mods__curModInSlots
    let gunModEid = get_Eid(gunMod.value) ?? INVALID_ENTITY_ID
    query(gunModEid) <| $ [es] (animchar_render aka mod_animchar_render : AnimcharRendComponent;
                                slot_attach__slotId : int;
                                var animchar : AnimcharBaseComponent;
                                var animchar_node_wtm : AnimcharNodesMat44&;
                                var animchar_render__root_pos : vec4f&)
      if slot_attach__slotId < 0
        return
      var tmpTm : mat44f
      if !animchar_initAttachmentTmAndNodeWtm(item_animchar, slot_attach__slotId, tmpTm)
        logerr("Bad attachment {gunModEid} to item {item_eid} to slot_id {slot_attach__slotId}")
      let wtmOfs = *item_animchar.nodeTree |> geomtree_getWtmOfs()
      animchar_setTmWithOfs(animchar, tmpTm, wtmOfs)
      animchar_recalc_wtm(animchar)
      animchar_copy_nodes(animchar, animchar_node_wtm, animchar_render__root_pos)
      var modBox : bbox3f
      calc_world_box(mod_animchar_render, modBox, animchar_node_wtm, false)
      let modBbox3 = BBox3(modBox)
      bbox3_add(box, modBbox3)
  return box


def try_place_on_gunwall(item_eid : EntityId;
                         gunwall_eid : EntityId) : bool
  var success = false
  query(item_eid) <| $ [es] (racked_weapon__recreateOnRack : string;
                             item__recreateInInventory : string;
                             racked_weapon__rackTemplate : string;
                             racked_weapon__transform : float3x4;
                             racked_weapon__rackRendinsts : Array;
                             gun_mods__curModInSlots : Object const?;
                             animchar_render : AnimcharRendComponent;
                             item_on_rack__gunwallEid : EntityId = INVALID_ENTITY_ID;
                             var animchar : AnimcharBaseComponent;
                             var animchar_node_wtm : AnimcharNodesMat44&;
                             var animchar_render__root_pos : vec4f&;
                             var racked_weapon__isWeaponOnRack : bool&;
                             var racked_weapon__rackEids : EidList)
    if item_on_rack__gunwallEid != INVALID_ENTITY_ID
      return
    animchar_set_tm(animchar, racked_weapon__transform, true)
    animchar_recalc_wtm(animchar)
    animchar_copy_nodes(animchar, animchar_node_wtm, animchar_render__root_pos)
    var itemBox : bbox3f
    calc_world_box(animchar_render, itemBox, animchar_node_wtm, false)
    let itemBoxCenter = (itemBox.bmax.xyz + itemBox.bmin.xyz) / 2.f
    var modedItemBox = BBox3(itemBox)
    if gun_mods__curModInSlots != null
      let modsBbox = get_mods_box(item_eid, animchar, *gun_mods__curModInSlots)
      bbox3_add(modedItemBox, modsBbox)

    let modedItemSize = modedItemBox.width.xy
    let rootShift = itemBoxCenter.xy - modedItemBox.center.xy
    var cellStart = int2(0, 0)
    var cellCount : int2
    query(gunwall_eid) <| $ [es] (gunwall__cellDim : int2;
                                  gunwall__cellSize : float2;
                                  gunwall__size : float3;
                                  gunwall__tm : float3x4;
                                  var gunwall__cells : EidList)
      cellCount = int2(ceili(safediv(modedItemSize.x, gunwall__cellSize.x)), ceili(safediv(modedItemSize.y, gunwall__cellSize.y)))
      if cellCount.x == 0 || cellCount.y == 0
        return
      success = find_free_place_on_grid(gunwall__cells, gunwall__cellDim, cellCount, cellStart)
      if success
        var tm = gunwall__tm
        tm[3] += gunwall__tm[1] * gunwall__size.y / 2.f - gunwall__tm[0] * gunwall__size.x / 2.f // set pos to the left top of gunwall
        tm[3] += gunwall__tm[0] * (float(cellStart.x) + float(cellCount.x) / 2.f) * gunwall__cellSize.x - gunwall__tm[1] * (float(cellStart.y) + float(cellCount.y) / 2.f) * gunwall__cellSize.y
        tm[3] += gunwall__tm[0] * rootShift.x + gunwall__tm[1] * rootShift.y

        item_eid |> removeSubTemplate(item__recreateInInventory)
        addSubTemplate(item_eid, racked_weapon__recreateOnRack) <| $(var init)
          init |> set("item_on_rack__gunwallEid", gunwall_eid)
          init |> set("item_on_rack__cellCoord", cellStart)
          init |> set("item_on_rack__cellDim", cellCount)
          init |> set("transform", tm * racked_weapon__transform)
          init |> set("slot_attach__visible", true)
        set_grid_value(gunwall__cells, gunwall__cellDim, cellStart, cellStart + cellCount, item_eid)
        for i in range(length(racked_weapon__rackRendinsts))
          let rack = racked_weapon__rackRendinsts[i] as Object
          let rackTM = get_TMatrix(rack, "tm") ?? IDENT_TM
          let rackName = get_string(rack, "rendinst", "")
          let rackEid = createEntity(racked_weapon__rackTemplate) <| $(init)
            init |> set("ri_extra__name", rackName)
            init |> set("transform", tm * rackTM)
          racked_weapon__rackEids |> push(rackEid)
          racked_weapon__isWeaponOnRack = true
  return success


def try_rack_weapon(weapon : EntityId)
  find_query() <| $ [es(REQUIRE=gunwall__tm)] (eid : EntityId)
    let success = try_place_on_gunwall(weapon, eid)
    return success


def try_rack_unracked_weapons()
  query() <| $ [es(REQUIRE=stash_inventory__heroEid)] (itemContainer : EidList)
    for item in itemContainer
      query(item) <| $ [es] (racked_weapon__isWeaponOnRack : bool; item_on_rack__gunwallEid : EntityId = INVALID_ENTITY_ID)
        if item_on_rack__gunwallEid == INVALID_ENTITY_ID && !racked_weapon__isWeaponOnRack
          try_rack_weapon(item)


[es(tag=gameClient, on_appear, track=item__containerOwnerEid)]
def update_weapon_rack(evt : Event;
                       eid : EntityId;
                       item__containerOwnerEid : EntityId;
                       racked_weapon__isWeaponOnRack : bool;
                       racked_weapon__recreateOnRack : string)
  if has(item__containerOwnerEid, "stash_inventory__heroEid") && !racked_weapon__isWeaponOnRack
    try_rack_weapon(eid)
  else
    removeSubTemplate(eid, racked_weapon__recreateOnRack)


[es(tag=gameClient, track=gun_mods__curModInSlots, REQUIRE=gun_mods__curModInSlots)]
def unrack_weapon_on_mods_changed(evt : Event;
                                  eid : EntityId;
                                  racked_weapon__recreateOnRack : string)
  removeSubTemplate(eid, racked_weapon__recreateOnRack)


[es(tag=gameClient, on_disappear, REQUIRE=racked_weapon__recreateOnRack)]
def delete_weapon_from_rack(evt : Event;
                            item_on_rack__cellCoord : int2;
                            item_on_rack__cellDim : int2;
                            var item_on_rack__gunwallEid : EntityId&;
                            var slot_attach__visible : bool&;
                            var racked_weapon__isWeaponOnRack : bool&;
                            var racked_weapon__rackEids : EidList;
                            slot_attach__attachedTo : EntityId = INVALID_ENTITY_ID)
  if !slot_attach__attachedTo
    slot_attach__visible = false
  query(item_on_rack__gunwallEid) <| $ [es] (gunwall__cellDim : int2; var gunwall__cells : EidList)
    set_grid_value(gunwall__cells, gunwall__cellDim, item_on_rack__cellCoord, item_on_rack__cellCoord + item_on_rack__cellDim, INVALID_ENTITY_ID)

  item_on_rack__gunwallEid = INVALID_ENTITY_ID

  for rack in racked_weapon__rackEids
    destroyEntity(rack)
  racked_weapon__rackEids |> clear()
  racked_weapon__isWeaponOnRack = false
  try_rack_unracked_weapons()


[es(tag=gameClient, track=itemContainer, REQUIRE=stash_inventory__heroEid)]
def sync_racked_items_with_stash(evt : Event; itemContainer : EidList)
  var usedRacks : table<uint>
  var itemWithNoRacks : array<EntityId>
  for item in itemContainer
    let hasRack = find_query() <| $ [es] (eid, racked_item__itemEid : EntityId)
      if racked_item__itemEid == item
        usedRacks |> insert(uint(eid))
        return true
      return false
    if !hasRack
      itemWithNoRacks |> push(item)

  query() <| $ [es] (eid, racked_item__slotEid : EntityId)
    if !key_exists(usedRacks, uint(eid))
      query(racked_item__slotEid) <| $ [es] (var racked_item_slot__rackedItemEid : EntityId&)
        racked_item_slot__rackedItemEid = INVALID_ENTITY_ID
      destroyEntity(eid)

  for item in itemWithNoRacks
    query(item) <| $ [es] (item__id : int; animchar__res : string)
      find_query() <| $ [es] (racked_item_slot__itemId : int;
                              transform : float3x4;
                              eid : EntityId;
                              var racked_item_slot__rackedItemEid : EntityId&)
        if racked_item_slot__itemId == item__id && racked_item_slot__rackedItemEid == INVALID_ENTITY_ID
          query(eid) <| $ [es] (racked_item_slot__noRacksItemTemplate : string)
            racked_item_slot__rackedItemEid = createEntity(racked_item_slot__noRacksItemTemplate) <| $(init)
              init |> set("racked_item__itemEid", item)
              init |> set("racked_item__slotEid", eid)
              init |> set("animchar__res", animchar__res)
              init |> set("transform", transform)
            usedRacks |> insert(uint(racked_item_slot__rackedItemEid))
          return true
        return false

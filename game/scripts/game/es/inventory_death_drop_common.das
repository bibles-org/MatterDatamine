module inventory_death_drop_common shared
require ecs
require strings
require ecs.safe
require math.base
require pathfinder
require ecs.common
require DagorRandom
require DagorSystem
require Dacoll
require game.es.ecs_common
require game.es.inventory_drop_common
require game.es.grav_zones_common
require game.es.ai.agent_position_mapping_common
require active_matter.game.utils.poly_area


struct DropLootDescription
  templateName : string
  position : float3
  height : float


def private drop_item(owner_eid : EntityId; item_description : DropLootDescription)
  var itemTm = IDENT_TM
  itemTm[3] = item_description.position
  drop_item_on_ground(itemTm)

  let templ = getOrBuildTemplateByName(item_description.templateName)
  if templ == null
    logerr("[DEATH DROP] Can't find template to drop: <{item_description.templateName}>")
    return
  var itemTemplate = item_description.templateName
  let recreateOnGroundTemplate = getTemplateComponent(*templ, "item__recreateOnGround") ?? "item_in_world"
  itemTemplate = itemTemplate |> add_sub_template_name(recreateOnGroundTemplate)
  createEntity(itemTemplate) <| $(var init)
    init |> set("transform", itemTm)
    init |> set("item__containerOwnerEid", INVALID_ENTITY_ID)
    init |> set("item__lastContainerOwnerEid", owner_eid)
    init |> set("item__isOnGround", true)


def private arrange_loot_navmesh(radius : float; grav_tm : float3x4; var loot_description : array<DropLootDescription>) : void
  if empty(loot_description)
    return
  let lootCount = float(length(loot_description))
  let startDegree = rnd_float(0.0, TWOPI)
  var s, c : float
  let extents = float3(radius, FLT_MAX, radius)
  for i in iter_range(loot_description)
    sincos(startDegree + float(i) * TWOPI / lootCount, s, c)
    let newPos = loot_description[i].position + (grav_tm[0] * s + grav_tm[2] * c) * radius

    let mappingZone1 = navmesh_mapping_find_best_zone_for_position(loot_description[i].position)
    let mappingZone2 = navmesh_mapping_find_best_zone_for_position(newPos)
    if mappingZone1 == mappingZone2
      let mappedPos1 = navmesh_map_position_in_zone(loot_description[i].position, mappingZone1)
      var mappedPos2 = navmesh_map_position_in_zone(newPos, mappingZone1)
      traceray_navmesh(mappedPos1, mappedPos2, extents, mappedPos2)
      loot_description[i].position = navmesh_unmap_position_in_zone(mappedPos2, mappingZone1)
      validate_gameplay_position(loot_description[i].position) <| $()
        return <- "mappedPos2={mappedPos2}, mappingZone1={mappingZone1}"


def arrange_loot_in_place(radius : float; grav_tm : float3x4; var loot_description : array<DropLootDescription>) : void
  if empty(loot_description)
    return
  let lootCount = float(length(loot_description))
  let startDegree = rnd_float(0.0, TWOPI)
  var s, c : float
  for i in iter_range(loot_description)
    sincos(startDegree + float(i) * TWOPI / lootCount, s, c)
    let h = rnd_float(0.0, loot_description[i].height)
    let traceFrom = loot_description[i].position + grav_tm[1] * h
    let dir = grav_tm[0] * s + grav_tm[2] * c
    var t = radius
    var norm : float3
    traceray_normalized(traceFrom, dir, t, norm)
    if t < radius
      t = max(.0, t - 0.2)
    loot_description[i].position = traceFrom + dir * t


def drop_death_drop_loot(eid : EntityId)
  query(eid) <| $ [es] (transform : float3x4;
                        human_inventory__deathDrop : Array;
                        human_inventory__deathDropLootRad = 0.6)
    let gravTm = get_grav_tm(transform[3])
    let traceFrom = transform[3] + gravTm[1] * 0.01
    var t = 2.0
    var norm : float3
    traceray_normalized(traceFrom, -gravTm[1], t, norm)
    var dropOriginPos = transform[3] - gravTm[1] * t
    var ref : dtPolyRef
    var area : uint8
    var navmeshCastSuccess = false
    let firstDropOriginPos = dropOriginPos
    if project_to_nearest_navmesh_point(dropOriginPos, float3(human_inventory__deathDropLootRad), ref)
      get_poly_area(ref, area)
      if area != uint8(int(AMPolyArea.POLYAREA_WALKABLE_ISLE))
        let traceDir = normalize(dropOriginPos - firstDropOriginPos)
        var tt = length(dropOriginPos - firstDropOriginPos)
        if !traceray_normalized(dropOriginPos, traceDir, tt, norm)
          navmeshCastSuccess = true

    if !navmeshCastSuccess
      dropOriginPos = firstDropOriginPos

    var lootToDrop : array<DropLootDescription>
    for lootRecord in human_inventory__deathDrop
      let itemChance = (lootRecord as Object)?.dropChance ?? 1.0
      if itemChance <= gfrnd()
        continue
      let itemTemplate = (lootRecord as Object)?.itemTemplate ?? ""
      let dropHeight = min(t, (lootRecord as Object)?.dropHeight ?? .0)
      if !empty(itemTemplate)
        lootToDrop |> push(DropLootDescription(templateName = itemTemplate, position = dropOriginPos, height = dropHeight))
    if navmeshCastSuccess
      arrange_loot_navmesh(human_inventory__deathDropLootRad, gravTm, lootToDrop)
    else
      arrange_loot_in_place(human_inventory__deathDropLootRad, gravTm, lootToDrop)
    for loot in lootToDrop
      drop_item(eid, loot)
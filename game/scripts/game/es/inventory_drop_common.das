module inventory_drop_common shared
require ecs
require ecs.common
require ecs.safe
require net
require math.base
require math.random
require DagorRandom
require DagorMath
require game.es.grav_zones_common
require game.events.events_game
require strings
require Dacoll
require PhysMat
require inventory
require DagorSystem
require DngNet
require game.events.events
require game.events.inventory_events


def align_item(pos : float3;
               norm : float3;
               var tm : float3x4&)
  let rotQ = quat(norm, rnd_float(0.0, TWOPI))
  tm[1] = norm
  tm[0] = get_normal(tm[1])
  tm[0] = rotQ * tm[0]
  tm[2] = normalize(cross(tm[0], tm[1]))
  tm[3] = pos


def align_item(pos : float3;
               var aligned_tm : float3x4&)
  let gravDir = get_grav_dir(pos)
  let from = pos - gravDir * 0.05f
  var t = 1.0f
  var norm = float3()
  if !traceray_normalized(from, gravDir, t, norm)
    norm = -gravDir
  align_item(pos, norm, aligned_tm)


def drop_item_on_ground(var pos_tm : float3x4&)
  let gravDir = get_grav_dir(pos_tm[3])
  var height = 300.f
  let dropOffset = -gravDir * 0.5f
  var norm = float3()
  var pos = pos_tm[3] + dropOffset
  var pmid = -1
  let matId = get_material_id("itemDropRayMat")
  var riDesc = RendInstDesc()
  if traceray_normalized(pos, gravDir, height, pmid, norm, ETF_DEFAULT, riDesc, matId)
    pos += height * gravDir
  else
    let lmeshHeight = traceht_lmesh(pos)
    if lmeshHeight > -1e5f
      pos.y = lmeshHeight
  align_item(pos, norm, pos_tm)


struct SimpleItemDesc
  id : int
  eid : EntityId
  ownerEid : EntityId
  tm : float3x4
  templOverride : string
  addTemplate : string
  skipArrange : bool
  ignoreChestAndDropOnGround : bool
  gunSlot : int // gunSlot == -1 for not equipped guns and not gun items


def get_item_template_drop_tm(item_template : Template)
  let dropTms = getTemplateComponent(item_template, "drop_tms")
  if dropTms != null
    let dropTmsArray = get_ecs_TMatrixList(dropTms)
    if dropTmsArray != null && length(*dropTmsArray) > 0
      let idx = rnd_int(0, length(*dropTmsArray) - 1)
      return (*dropTmsArray)[idx]

  let dropTm = getTemplateComponent(item_template, "dropTm")
  if dropTm != null
    return dropTm ?? IDENT_TM

  return IDENT_TM


def get_drop_tm(item_eid : EntityId; pos : float3)
  var res = IDENT_TM
  res[3] = pos
  drop_item_on_ground(res)
  query(item_eid) <| $ [es] (dropTm : float3x4)
    res = res * dropTm
  query(item_eid) <| $ [es] (drop_tms : TMatrixList)
    res = res * drop_tms[rnd_int(0, length(drop_tms) - 1)]
  return res


def private find_drop_pos_in_grid(drop_pos, owner_pos : float3; radius, grid_step : float; rnd_count : int; immediately_acceptable_dot = 0.8)
  var excellentSpots : array<tuple<float3; float3; float3>>
  var bestPos : float3
  var bestNorm : float3
  var bestDot = -1.0
  let gravDir = get_grav_dir(owner_pos)
  let matId = get_material_id("itemDropRayMat")
  let dropVec = drop_pos - owner_pos
  let dropOffset = -gravDir * 0.5f
  let vertComponent = -gravDir * dot(dropVec, -gravDir)
  let gridVec1 = normalize(dropVec - vertComponent)
  let gridVec2 = cross(gridVec1, gravDir)
  let gridHalfSize = int(radius / grid_step)
  let limitingRadiusSq = square(radius / grid_step)
  for i in range(gridHalfSize * 2)
    if length(excellentSpots) >= rnd_count
      break
    for k in range(gridHalfSize * 2)
      if square(float(gridHalfSize - i)) + square(float(gridHalfSize - k)) > limitingRadiusSq
        continue //outside of the circle

      let p = owner_pos + vertComponent + (gridVec1 * float(gridHalfSize - i) + float(gridHalfSize - k) * gridVec2) * grid_step

      var height = 300.f
      var norm = float3()
      var pos = p + dropOffset
      var pmid = -1
      var riDesc = RendInstDesc()
      if traceray_normalized(pos, gravDir, height, pmid, norm, ETF_DEFAULT, riDesc, matId)
        let groundPos = pos + height * gravDir
        let thisDot = dot(-gravDir, norm)
        if thisDot > immediately_acceptable_dot
          excellentSpots |> push(tuple(groundPos, norm, p))
          if length(excellentSpots) >= rnd_count
            break
        if thisDot > bestDot
          bestPos = groundPos
          bestDot = thisDot
          bestNorm = norm
      elif bestPos == float3()
        let lmeshHeight = traceht_lmesh(pos)
        if lmeshHeight > -1e5f
          pos.y = lmeshHeight
          bestPos = pos
          bestNorm = -gravDir
  shuffle(excellentSpots)
  //Ensure we don't drop items through a wall
  let traceFrom = owner_pos + vertComponent
  for espot in excellentSpots
    var norm : float3
    let v = espot._2 - traceFrom
    var t = length(v)
    let dir = v * safeinv(t)
    if !traceray_normalized(traceFrom, dir, t, norm)
      return espot._0, espot._1
  return bestPos, bestNorm


def private find_good_drop_tm(drop_pos, owner_pos : float3; radius, grid_step : float; rnd_count : int; item_drop_tm : float3x4 const?; item_drop_tms : TMatrixList const?)
  var res = IDENT_TM
  if radius == .0 || grid_step == .0 || grid_step >= radius * 2.0
    res[3] = drop_pos
    drop_item_on_ground(res)
  else
    let (pos, norm) = find_drop_pos_in_grid(drop_pos, owner_pos, radius, grid_step, rnd_count)
    align_item(pos, norm, res)
  if item_drop_tms != null
    res = res * (*item_drop_tms)[rnd_int(0, length(*item_drop_tms) - 1)]
  elif item_drop_tm != null
    res = res * *item_drop_tm
  return res


// drop from inventories and slots
def drop_item(item_eid, hero_eid : EntityId)
  var toContainerEid = INVALID_ENTITY_ID

  query(item_eid) <| $ [es] (var item__isOnGround : bool&;
                             var item__lastContainerOwnerEid, item__humanOwnerEid, item__containerOwnerEid : EntityId&;
                             var gun__owner : EntityId?;
                             var slot_attach__attachedTo : EntityId?;
                             dropTm : float3x4 const?;
                             drop_tms : TMatrixList const?)
    var ownerPos : float3
    var dropPosition : float3
    var dropRadius : float
    var dropGridStep : float = 0.3
    var dropRndCount : int = 7
    query(hero_eid) <| $ [es] (transform : float3x4;
                               human_inventory__dropLootOffset = float3(0);
                               human_inventory__dropGridStep = 0.3;
                               human_inventory__dropRndCount = 7;
                               player_on_base_components__stashEid : EntityId = INVALID_ENTITY_ID)
      ownerPos = transform[3]
      dropPosition = transform * human_inventory__dropLootOffset
      dropRadius = length(human_inventory__dropLootOffset.xz)
      toContainerEid = player_on_base_components__stashEid
      dropGridStep = human_inventory__dropGridStep
      dropRndCount = human_inventory__dropRndCount

    if slot_attach__attachedTo != null
      *slot_attach__attachedTo = INVALID_ENTITY_ID

    if toContainerEid != INVALID_ENTITY_ID
      query(toContainerEid) <| $ [es] (inventory__humanOwnerEid : EntityId)
        item__lastContainerOwnerEid = item__containerOwnerEid
        item__humanOwnerEid = inventory__humanOwnerEid
        item__containerOwnerEid = toContainerEid
        if gun__owner != null
          *gun__owner = inventory__humanOwnerEid
      item__isOnGround = false
    else
      item__lastContainerOwnerEid = item__containerOwnerEid
      item__humanOwnerEid = INVALID_ENTITY_ID
      item__containerOwnerEid = INVALID_ENTITY_ID
      if gun__owner != null
        *gun__owner = INVALID_ENTITY_ID
      item__isOnGround = true

    send_net_event(item_eid, EventOnDropItem(
        actorEid = hero_eid,
        oldInventoryEid = item__lastContainerOwnerEid,
        newInventoryEid = toContainerEid,
        transform = (!toContainerEid) ? find_good_drop_tm(dropPosition, ownerPos, dropRadius, dropGridStep, dropRndCount, dropTm, drop_tms) : IDENT_TM))

  return toContainerEid


def drop_item_phys(item_eid : EntityId;
                   transform : float3x4)
  query(item_eid) <| $ [es] (var item__isOnGround : bool&;
                             var item__lastContainerOwnerEid, item__humanOwnerEid, item__containerOwnerEid : EntityId&;
                             var gun__owner : EntityId?;
                             var slot_attach__attachedTo : EntityId?;
                             dropTm : float3x4 const?;
                             drop_tms : TMatrixList const?)
    if slot_attach__attachedTo != null
      *slot_attach__attachedTo = INVALID_ENTITY_ID

    let humanOwnerEid = item__humanOwnerEid
    item__lastContainerOwnerEid = item__containerOwnerEid
    item__humanOwnerEid = INVALID_ENTITY_ID
    item__containerOwnerEid = INVALID_ENTITY_ID
    if gun__owner != null
      *gun__owner = INVALID_ENTITY_ID
    item__isOnGround = true

    var tm = transform
    if drop_tms != null
      tm = transform * (*drop_tms)[rnd_int(0, length(*drop_tms) - 1)]
    elif dropTm != null
      tm = transform * *dropTm

    send_net_event(item_eid, EventOnDropItemPhys(
        actorEid = humanOwnerEid,
        transform = tm))


def create_item_on_ground(item_template : string; transform : float3x4;
                          init_block : block<(var init_obj : ComponentsInitializer) : void>)
  let itemTempl = getOrBuildTemplateByName(item_template)
  if itemTempl == null
    logerr("[INVENTORY] Can't find template for item: <{item_template}>")
    return INVALID_ENTITY_ID

  var itemTemplate = item_template

  let onGroundSubTemplate = getTemplateComponent(*itemTempl, "item__recreateOnGround") ?? ""
  if onGroundSubTemplate != ""
    itemTemplate = add_sub_template_name(itemTemplate, onGroundSubTemplate)

  let itemEid = createEntity(itemTemplate) <| $(var init)
    init |> set("item__containerOwnerEid", INVALID_ENTITY_ID)
    init |> set("item__lastContainerOwnerEid", INVALID_ENTITY_ID)
    init |> set("item__isOnGround", true)
    init |> set("transform", transform)
    invoke(init_block, init)

  print("[INVENTORY] Item <{itemEid}> ({itemTemplate}) start creating on ground")
  return itemEid


def create_item_on_ground(item_template : string; transform : float3x4)
  return create_item_on_ground(item_template, transform) <| $ [unused_argument(init)] (init) {}

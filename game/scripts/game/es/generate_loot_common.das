module generate_loot_common shared
require ecs
require level
require Dacoll
require ecs.safe
require math.base
require DagorMath
require gameObject
require math.random
require DagorSystem
require DagorRandom
require game.events.events_game
require game.es.transform_common
require game.es.grav_zones_common
require game.es.monster_gen_common
require game.es.custom_region_common
require game.es.riextra_common
require active_matter.game.es.regions_common
require active_matter.game.es.loot_preset_common


def map_game_obj_node_idx(ni : uint)
  return int(ni / 0x100) //haxx. I don't know why and when this works but so far it does


def create_loot(template_name : string; tm : float3x4)
  if empty(template_name)
    logerr("[Object Generator] Try generate item with empty template!")
    return

  let position = float2(tm[3].x, tm[3].z)
  let regionName = get_region_name_by_pos(position)

  let eid = createEntity("{template_name}+item_generated") <| $(init)
    init |> set("transform", tm)
    init |> set("spawnedInRegion", regionName)
  sendEvent(eid, EventOnItemGenerated())


struct PlacedItemData
  pos : float3
  grav : float3


def get_item_template_default_bbox()
  return BBox3(float3(), 0.3) // approx safe bbox


def get_item_template_bbox(item_template : Template)

  let riExtraName = getTemplateComponent(item_template, "ri_extra__name") ?? ""
  if riExtraName != ""
    let rendinstIdx = get_rigen_extra_res_idx(riExtraName)
    if rendinstIdx < 0
      // TODO: rendinst is not loaded yet, but we can't load it here now
      // ("Attempt to load game resource in main thread" error)
      return get_item_template_default_bbox()

    let collres = get_ri_gen_extra_collres(rendinstIdx)
    if collres == null
      logerr("[Object generator] rendinst '{riExtraName}' has no collres! rendinstIdx={rendinstIdx}")
      return get_item_template_default_bbox()

    return BBox3(collres.vFullBBox)

  // TODO: support for animchar bboxes
  return get_item_template_default_bbox()


def place_item(orig_vol_tm : float3x4;
               scale_block_vert_spawn : float;
               margin : float3;
               create_items_in_place : bool;
               fixed_tm : bool;
               compensate_DropTm : bool;
               tm_mod : float3x4;
               item_template_name : string;
               item_template : Template;
               can_stand_upright : bool;
               var seed : int&)
  let itemBbox = get_item_template_bbox(item_template)
  let itemBboxSize = itemBbox.width

  var tm := orig_vol_tm
  var outPos = orig_vol_tm[3]
  let gravDir = get_grav_dir(orig_vol_tm[3])
  if !fixed_tm
    var longestAxis = 0
    var longestLen = 0.0
    var upmostAxis = 0
    var upmostDot = 0.0
    var canStandUpright = can_stand_upright
    var volTm = orig_vol_tm
    for i in range(3)
      let umd = dot(volTm[i], -gravDir)
      if abs(umd) > abs(upmostDot)
        upmostDot  = umd
        upmostAxis = i
      let lenSq = length_sq(volTm[i])
      if lenSq > longestLen
        let lenMargin = square(1.1)
        longestLen = lenSq * lenMargin
        longestAxis = i

    var upmostIfCan = upmostAxis
    var downMargin = margin[1]
    if longestAxis == upmostAxis
      if (max(length_sq(volTm[(upmostAxis + 1) % 3]),
              length_sq(volTm[(upmostAxis + 2) % 3])) >
              square(margin.x) * scale_block_vert_spawn)
        canStandUpright = false

      if !canStandUpright
        longestAxis = (length_sq(volTm[(upmostAxis + 1) % 3]) > length_sq(volTm[(upmostAxis + 2) % 3])
                      ? ((upmostAxis + 1) % 3)
                      : ((upmostAxis + 2) % 3))
      else
        let rotVolTm = volTm * tm_mod
        upmostIfCan = (length_sq(rotVolTm[(longestAxis + 1) % 3]) < length_sq(rotVolTm[(longestAxis + 2) % 3])
                      ? ((longestAxis + 1) % 3)
                      : ((longestAxis + 2) % 3))
        downMargin = margin[0]

    var marginOrient = float3()
    marginOrient[0] = margin[longestAxis]
    marginOrient[1] = margin[upmostIfCan]
    marginOrient[2] = margin[3 - longestAxis - upmostIfCan]
    for i in range(3)
      if marginOrient[i] != 0.0
        let len = length(volTm[i])
        volTm[i] = volTm[i] * safediv(max(0.0, len - marginOrient[i]), len)

    var downAxis = (upmostDot < 0.0 ? 1.0 : -1.0) * orig_vol_tm[upmostAxis]
    let origVolumeHeight = length(downAxis)
    downAxis *= safeinv(origVolumeHeight)
    let volumeHeight = length(volTm[upmostAxis])
    var lootPos = volTm[3]
    var bestDist = FLT_MAX
    let tries = create_items_in_place ? 0 : 10
    for _i in range(tries)
      // Setup random position on "horz" axis
      var topPos = float3()
      topPos[upmostAxis] = volTm[upmostAxis].y > 0.0 ? 0.5 : -0.5

      topPos = volTm * topPos
      var t = origVolumeHeight * 2.0
      var norm = float3()
      traceray_normalized(topPos, downAxis, t, norm, ETF_DEFAULT)

      let dist = abs(t - origVolumeHeight)

      if dist < bestDist
        lootPos = topPos + downAxis * (t - downMargin)
        if dist < 0.1
          break
        bestDist = dist

    var upAxis = upmostAxis
    if longestAxis == upmostAxis
      upAxis = upmostIfCan

    tm[0] = orig_vol_tm[longestAxis]
    tm[1] = orig_vol_tm[upAxis]
    orthonormalize(tm)


    let horzAxis0 = (upmostAxis + 1) % 3
    let horzAxis1 = (upmostAxis + 2) % 3
    let horzAxis0VolumeLength = length(orig_vol_tm[horzAxis0])
    let horzAxis1VolumeLength = length(orig_vol_tm[horzAxis1])
    let horzAxis0ItemLength = itemBboxSize[horzAxis0]
    let horzAxis1ItemLength = itemBboxSize[horzAxis1]

    if horzAxis0VolumeLength > horzAxis0ItemLength
      let horzAxis0Delta = horzAxis0VolumeLength - horzAxis0ItemLength
      let horzAxis0Offset = _frnd(seed) * horzAxis0Delta - horzAxis0VolumeLength * 0.5 - itemBbox.boxMin[horzAxis0]
      lootPos += tm[horzAxis0] * horzAxis0Offset

    if horzAxis1VolumeLength > horzAxis1ItemLength
      let horzAxis1Delta = horzAxis1VolumeLength - horzAxis1ItemLength
      let horzAxis1Offset = _frnd(seed) * horzAxis1Delta - horzAxis1VolumeLength * 0.5 - itemBbox.boxMin[horzAxis1]
      lootPos += tm[horzAxis1] * horzAxis1Offset

    tm[3] = lootPos

    outPos = lootPos - downAxis * volumeHeight * 0.5
  tm = tm * tm_mod
  if compensate_DropTm
    let dropTm = getTemplateComponent(item_template, "dropTm") ?? IDENT_TM
    tm = tm * inverse(dropTm)
  create_loot(item_template_name, tm)

  return <- PlacedItemData(pos = outPos, grav = gravDir)


def simple_place_additional_items(item_arr : array<string>;
                                  genPos : PlacedItemData;
                                  var seed : int&;
                                  dist_from_item : float2 = float2(0.05, 0.15))
  for additionalItem in item_arr
    let tmBasis = build_grav_tm(float3(), genPos.grav)
    var horzOffsVec : float3
    sincos(_frnd(seed) * TWOPI, horzOffsVec.z, horzOffsVec.x)
    let offsDir = rotate(tmBasis, horzOffsVec)

    let offsLen = _rnd_float(seed, dist_from_item.x, dist_from_item.y)

    var norm = float3()
    var t = offsLen
    traceray_normalized(genPos.pos, offsDir, t, norm, ETF_DEFAULT)
    let offsPos = genPos.pos + offsDir * (t - 0.01)

    t = 5.0
    traceray_normalized(offsPos, genPos.grav, t, norm, ETF_DEFAULT)
    let closestPos = offsPos + genPos.grav * (t - 0.01)
    var addTm = tmBasis
    addTm[3] = closestPos
    create_loot(additionalItem, addTm)


def loot_preset_generator(volumes : array<float3x4>;
                          loot_generator__lootPreset : string;
                          loot_generator__seed : int const?;
                          loot_generator__projAttempts : int;
                          loot_generator__gridStep : float;
                          loot_generator__gameObjType : string;
                          loot_generator__allowVolumesOverflow : bool;
                          loot_generator__createItemsInPlace = false;
                          loot_generator__fixedTm = false;
                          loot_generator__compensateDropTm = false)
  var seed = loot_generator__seed ?? get_rnd_seed()
  var box = BBox3()
  for vol in volumes
    box |> bbox3_add(vol[3])
  let step = loot_generator__gridStep
  let invStep = 1.0 / step
  let boxWidth3 = box.width
  let boxWidth = float2(boxWidth3.x, boxWidth3.z)
  let gridSize = int2(ceil(boxWidth.x * invStep + 0.5),
                      ceil(boxWidth.y * invStep + 0.5))
  var grid : array<array<int>>
  grid |> resize(gridSize.x * gridSize.y)
  for i in iter_range(volumes)
    let vol = volumes[i]
    let pos = vol[3] - box.boxMin
    let gp = float2(pos.x, pos.z) * invStep
    let gridPos = int2(gp)
    grid[gridPos.x + gridPos.y * gridSize.x] |> push(i)

  var closedList : array<int>
  var exhaustedList : array<int>
  var openList : array<int>
  for i in iter_range(grid)
    if !empty(grid[i])
      openList |> push(i)

  print("[Object Generator] Seed <{seed}> for <{loot_generator__gameObjType}>, non-empty {length(openList)}")

  var usedIdxs : array<int>
  var lootGenPoints : array<float3>
  var numberCreated : int
  if empty(loot_generator__lootPreset)
    return <- usedIdxs
  else
    loot_preset_generate(loot_generator__lootPreset) <| $(itemsArray)
      let itemTemplateName = itemsArray[0]

      var itemTemplate = getTemplateByName(itemTemplateName)
      if itemTemplate == null
        itemTemplate = buildTemplateByName(itemTemplateName)
      if itemTemplate == null
        error("[Object Generator] <{loot_generator__gameObjType}>: Invalid item template: {itemTemplateName}!")
        return

      var additionalTemplates : array <string>
      for i in range(1, length(itemsArray))
        additionalTemplates |> push(itemsArray[i])
      if !loot_generator__allowVolumesOverflow && numberCreated >= length(volumes)
        return

      if empty(openList)
        swap(openList, closedList)
      if empty(openList)
        swap(openList, exhaustedList)

      var gridIdx = _rnd(seed) % length(openList)
      var lootBoxIdxInGrid = _rnd(seed) % length(grid[openList[gridIdx]])
      var projIdx = grid[openList[gridIdx]][lootBoxIdxInGrid]
      var bestScore = 0.0
      var k = 0
      while k < loot_generator__projAttempts
        let potentialGrid = _rnd(seed) % length(openList)
        let potentialLootbox = _rnd(seed) % length(grid[openList[potentialGrid]])
        let potentialProj = grid[openList[potentialGrid]][potentialLootbox]
        let testVolTm = volumes[potentialProj]

        var score = FLT_MAX
        for pos in lootGenPoints
          score = min(score, length_sq(pos - testVolTm[3]))

        if score > bestScore
          projIdx = potentialProj
          lootBoxIdxInGrid = potentialLootbox
          gridIdx = potentialGrid
          bestScore = score
        ++k

      if gridIdx >= 0
        if !loot_generator__allowVolumesOverflow
          grid[openList[gridIdx]] |> erase(lootBoxIdxInGrid)
        if length(grid[openList[gridIdx]]) > 0
          if length(grid[openList[gridIdx]]) > 1
            closedList |> push(openList[gridIdx])
          else
            exhaustedList |> push(openList[gridIdx])
        openList |> erase(gridIdx)

      let spawnedPos = place_item(volumes[projIdx],
                                  2.5,
                                  float3(0.0, 0.0, 0.0),
                                  loot_generator__createItemsInPlace,
                                  loot_generator__fixedTm,
                                  loot_generator__compensateDropTm,
                                  IDENT_TM,
                                  itemTemplateName,
                                  *itemTemplate,
                                  false,
                                  seed)
      usedIdxs |> push(projIdx)
      lootGenPoints |> push(spawnedPos.pos)
      numberCreated++

      simple_place_additional_items(additionalTemplates, spawnedPos, seed)

  print("[Object Generator] Generated <{numberCreated}> entities in <{length(volumes)}> volumes in <{loot_generator__gameObjType}>")
  return <- usedIdxs


def is_loot_point_in_forbidden_zone(pos : float3)
  return find_query() <| $ [es(REQUIRE=loot_generator_forbidden_zone)] (transform : float3x4;
                                                                        sphere_zone__radius = 0.0)
    return is_point_in_box_or_sphere_zone(pos, transform[3], inverse(transform), sphere_zone__radius)


def is_loot_point_in_forbidden_zone(loot_generator_eid : EntityId; pos : float3)
  if has(loot_generator_eid, "loot_generator_monster_gen") && is_point_in_monster_gen_forbidden_zone(pos)
    return true

  return is_loot_point_in_forbidden_zone(pos)


def collect_loot_volumes_in_zone(loot_generator_eid : EntityId;
                                 loot_generator__gameObjType : string)
  var volumes : tuple<nodes : array<uint>; tms : array<float3x4>>

  var zonePos = float3(0.0, 0.0, 0.0)
  var zoneRadSq = VERY_BIG_NUMBER
  find_query() <| $ [es(REQUIRE=moving_zone__targetPos)] (sphere_zone__radius : float;
                                                          transform : float3x4)
    zonePos = transform[3]
    zoneRadSq = square(sphere_zone__radius)
    return true

  print("[Object Generator] Generate objects in zone with center <{zonePos}> and square radius <{zoneRadSq}>")

  var totalPoints = 0
  find_query() <| $ [es] (game_objects : GameObjects)
    let scene = get_scene_game_objects_by_name(game_objects, loot_generator__gameObjType)
    if scene != null
      let nodesAliveCount = int(*scene |> tiled_scene_getNodesAliveCount())
      totalPoints += nodesAliveCount
      var hasRegistry = false
      find_query() <| $ [es] (used_game_objects__type : string; used_game_objects__map : BoolList)
        if used_game_objects__type == loot_generator__gameObjType
          hasRegistry = true
          *scene |> tiled_scene_iterate() <| $(ni : uint)
            if !used_game_objects__map[map_game_obj_node_idx(ni)]
              let mat = *scene |> tiled_scene_getNode(ni)
              if length_sq(mat.col3.xyz - zonePos) < zoneRadSq && !is_loot_point_in_forbidden_zone(loot_generator_eid, mat.col3.xyz)
                var tm : float3x4
                tm[0] = mat.col0.xyz
                tm[1] = mat.col1.xyz
                tm[2] = mat.col2.xyz
                tm[3] = mat.col3.xyz
                volumes.nodes |> push(ni)
                volumes.tms |> push(tm)
          return true
        return false

      if !hasRegistry
        *scene |> tiled_scene_iterate() <| $(ni : uint)
          let mat = *scene |> tiled_scene_getNode(ni)
          if length_sq(mat.col3.xyz - zonePos) < zoneRadSq && !is_loot_point_in_forbidden_zone(loot_generator_eid, mat.col3.xyz)
            var tm : float3x4
            tm[0] = mat.col0.xyz
            tm[1] = mat.col1.xyz
            tm[2] = mat.col2.xyz
            tm[3] = mat.col3.xyz
            volumes.nodes |> push(ni)
            volumes.tms |> push(tm)
    return true

  print("[Object Generator] Amount of <{loot_generator__gameObjType}> object points is <{length(volumes.nodes)}> from <{totalPoints}>")
  return <- volumes


def collect_loot_volumes_in_box(loot_generator_eid : EntityId;
                                transform : float3x4;
                                loot_generator__gameObjType : string;
                                allow_forbidden_zones : bool)
  var volumes : tuple<nodes : array<uint>; tms : array<float3x4>>
  let itm = inverse(transform)
  let box = BBox3(float3(-0.5, -0.5, -0.5), float3(0.5, 0.5, 0.5))

  print("[Object Generator] Generate objects in matrix <{transform}>")

  find_query() <| $ [es] (game_objects : GameObjects)
    let scene = get_scene_game_objects_by_name(game_objects, loot_generator__gameObjType)
    if scene != null
      var cullBox : bbox3f
      let cullBoxTransformed = transform * box
      let min = cullBoxTransformed.boxMin
      let max = cullBoxTransformed.boxMax
      cullBox.bmin = float4(min.x, min.y, min.z, 1.0)
      cullBox.bmax = float4(max.x, max.y, max.z, 1.0)

      var hasRegistry = false
      find_query() <| $ [es] (used_game_objects__type : string; used_game_objects__map : BoolList)
        if used_game_objects__type == loot_generator__gameObjType
          hasRegistry = true
          *scene |> tiled_scene_boxCull(cullBox, 0u, 0u) <| $(node_index : uint; m : mat44f)
            if !used_game_objects__map[map_game_obj_node_idx(node_index)]
              var mat : float3x4
              mat[0] = m.col0.xyz
              mat[1] = m.col1.xyz
              mat[2] = m.col2.xyz
              mat[3] = m.col3.xyz
              if box & (itm * mat[3])
                if allow_forbidden_zones || !is_loot_point_in_forbidden_zone(loot_generator_eid, m.col3.xyz)
                  volumes.nodes |> push(node_index)
                  volumes.tms |> push(mat)
          return true
        return false

      if !hasRegistry
        *scene |> tiled_scene_boxCull(cullBox, 0u, 0u) <| $(node_index : uint; m : mat44f)
          var mat : float3x4
          mat[0] = m.col0.xyz
          mat[1] = m.col1.xyz
          mat[2] = m.col2.xyz
          mat[3] = m.col3.xyz
          if box & (itm * mat[3])
            if allow_forbidden_zones || !is_loot_point_in_forbidden_zone(loot_generator_eid, m.col3.xyz)
              volumes.nodes |> push(node_index)
              volumes.tms |> push(mat)
    return true

  print("[Object Generator] Amount of <{loot_generator__gameObjType}> object points is <{length(volumes.nodes)}>")
  return <- volumes


def register_used_game_objects(used_idxes : array<int>; node_idxes : array<uint>; game_obj_type : string)
  find_query() <| $ [es] (used_game_objects__type : string; var used_game_objects__map : BoolList)
    if used_game_objects__type == game_obj_type
      for idx in used_idxes
        used_game_objects__map[map_game_obj_node_idx(node_idxes[idx])] = true
      return true
    return false
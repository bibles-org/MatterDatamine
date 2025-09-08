require ecs
require ecs.safe
require strings
require math
require math.base
require math.random
require DagorConsole
require pathfinder
require DagorSystem
require DagorRandom
require active_matter.game.es.anomalies.anomaly_zones_common
require game.es.level_common
require game.events.events_active_matter
require game.es.grav_zones_common
require Dacoll


let
  neighboursDir = fixed_array<int3>(
  int3(1, 0, 0),
  int3(0, 1, 0),
  int3(0, 0, 1),
  int3(-1, 0, 0),
  int3(0, -1, 0),
  int3(0, 0, -1)
)


enum NeighboursDir
  XPLUS
  YPLUS
  ZPLUS
  XMINUS
  YMINUS
  ZMINUS


def NeighboursDir(i : int)
  if i == 0
    return NeighboursDir.XPLUS
  if i == 1
    return NeighboursDir.YPLUS
  if i == 2
    return NeighboursDir.ZPLUS
  if i == 3
    return NeighboursDir.XMINUS
  if i == 4
    return NeighboursDir.YMINUS
  if i == 5
    return NeighboursDir.ZMINUS
  assert(i >= 0 && i < 6)
  return NeighboursDir.XPLUS


def get_opposite(dir : NeighboursDir) : NeighboursDir
  if dir == NeighboursDir.XPLUS
    return NeighboursDir.XMINUS
  if dir == NeighboursDir.YPLUS
    return NeighboursDir.YMINUS
  if dir == NeighboursDir.ZPLUS
    return NeighboursDir.ZMINUS
  if dir == NeighboursDir.XMINUS
    return NeighboursDir.XPLUS
  if dir == NeighboursDir.YMINUS
    return NeighboursDir.YPLUS
  if dir == NeighboursDir.ZMINUS
    return NeighboursDir.ZPLUS
  assert(false, "unknown dir")
  return NeighboursDir.XPLUS

def get_connections_num(n : VoxelNeighbours) : int
  return ((n.con_xplus ? 1 : 0)
        + (n.con_yplus ? 1 : 0)
        + (n.con_zplus ? 1 : 0)
        + (n.con_xminus ? 1 : 0)
        + (n.con_yminus ? 1 : 0)
        + (n.con_zminus ? 1 : 0))

bitfield VoxelNeighbours
  con_xplus
  con_yplus
  con_zplus

  con_xminus
  con_yminus
  con_zminus
  active

struct VoxelData
  flags : VoxelNeighbours
  pos : float3
  hasDistToWall : bool
  distToWall : float
  wallNorm : float3
  userData : uint8


struct ClusterVoxelData
  voxels : array<VoxelData>
  size : int3
  sizeMinusOne : int3
  gridStep : float
  minWPos : float3

struct PotentialCenter
  cell : int3
  key : int
  connectionsNum : int

def inside_box(pos : float3; min : float3; max : float3)
  return (pos.x >= min.x && pos.y >= min.y && pos.z >= min.z
       && pos.x <= max.x && pos.y <= max.y && pos.z <= max.z)


def get_flag(data : VoxelData; dir : NeighboursDir) : bool
  return (uint(data.flags) & (1u << uint(dir))) != 0u


def set_flag(var data : VoxelData; dir : NeighboursDir) : void
  data.flags |= bitfield(1u << uint(dir))


def unset_flag(var data : VoxelData; dir : NeighboursDir) : void
  data.flags &= bitfield(~(1u << uint(dir)))


def get_cell_by_wpos(data : ClusterVoxelData; wpos : float3) : int3
  let offset = wpos - data.minWPos
  let cellsOffset = offset / float3(data.gridStep)
  return int3(roundi(cellsOffset.x), roundi(cellsOffset.y), roundi(cellsOffset.z))


def get_cell_wpos(data : ClusterVoxelData; pos : int3)
  return data.minWPos + float3(pos) * data.gridStep


def get_key_unsafe(data : ClusterVoxelData; pos : int3) : int
  return pos.x + pos.y * data.size.x + pos.z * data.size.x * data.size.y


def get_key(data : ClusterVoxelData; pos : int3) : int
  let res = pos.x + pos.y * data.size.x + pos.z * data.size.x * data.size.y
  return clamp(res, 0, length(data.voxels))


def get_key(data : ClusterVoxelData; pos : int3; dir : NeighboursDir) : int
  return get_key_unsafe(data, get_cell(data, pos, dir))


def get_cell(data : ClusterVoxelData; pos : int3; dir : NeighboursDir) : int3
  let res = pos + neighboursDir[int(dir)]
  return int3(0) |> max <| min(data.sizeMinusOne, res)

def init_dist_to_wall(var cluster : ClusterVoxelData; cell : int3; key : int)
  assume voxel = cluster.voxels[key]
  let center = cluster |> get_cell_wpos(cell)

  let halfBox = float3(cluster.gridStep * 0.5)
  let halfGridStepSq = square(cluster.gridStep * 0.5)

  voxel.hasDistToWall = true

  query_navmesh_projections(center, halfBox, /*points num*/15) <| $(points; polys)
    if length(points) == 0
      return
    let voxelMin = center - halfBox
    let voxelMax = center + halfBox
    var distToWall = -1.
    var pos : float3
    var wallNorm : float3
    for navPos, navPoly in points, polys
      if !is_polygon_accessible(navPoly)
        continue
      if navPos |> inside_box(voxelMin, voxelMax)
        var norm : float3
        let dist = get_distance_to_wall(navPos, 1., 1., norm)
        if dist > distToWall
          pos = navPos
          distToWall = dist
          wallNorm = norm
    if distToWall >= 0f
      voxel.pos = pos
      voxel.distToWall = distToWall
      voxel.wallNorm = wallNorm
      voxel.flags |= VoxelNeighbours.active
      return
    // fallback logic, no points inside box, check inside sphere
    distToWall = -1.
    for navPos in points
      if distance_sq(navPos, center) <= halfGridStepSq
        var norm : float3
        let dist = get_distance_to_wall(navPos, 1., 1., norm)
        if dist > distToWall
          pos = navPos
          distToWall = dist
          wallNorm = norm
    if distToWall >= 0f
      voxel.pos = pos
      voxel.distToWall = distToWall
      voxel.wallNorm = wallNorm
      voxel.flags |= VoxelNeighbours.active
      return

def init_cluster(var cluster : ClusterVoxelData)
  verify(cluster.gridStep > 0f)
  verify(cluster.size.x > 0 && cluster.size.y > 0 && cluster.size.z > 0)
  cluster.sizeMinusOne = cluster.size - int3(1)

  cluster.voxels |> resize(cluster.size.x * cluster.size.y * cluster.size.z)
  let halfBox = float3(cluster.gridStep * 0.5)
  let halfGridStepSq = square(cluster.gridStep * 0.5)
  // activate voxels
  for x in range(0, cluster.size.x)
    for y in range(0, cluster.size.y)
      for z in range(0, cluster.size.z)
        let cell = int3(x, y, z)
        let key = cluster |> get_key(cell)
        assume voxel = cluster.voxels[key]
        let center = cluster |> get_cell_wpos(cell)
        // search navmesh position inside the voxel
        query_navmesh_projections(center, halfBox, /*points num*/15) <| $(points; polys)
          if length(points) == 0
            return
          var filteredPoints : array<float3>
          reserve(filteredPoints, length(points))
          for navPos, navPoly in points, polys
            if is_polygon_accessible(navPoly)
              push(filteredPoints, navPos)

          let initialDistance = halfGridStepSq + 0.1
          var distSqToCenter = initialDistance
          var pos : float3
          for navPos in filteredPoints
            let distSq = distance_sq(navPos, center)
            if distSq < distSqToCenter
              pos = navPos
              distSqToCenter = distSq
          if distSqToCenter < initialDistance
            voxel.pos = pos
            voxel.flags |= VoxelNeighbours.active
            return

  // check connectivity
  using() <| $(var path_corridor : dtPathCorridor)
    path_corridor |> init_path_corridor()
    let extents = float3(halfBox.x)
    for x in range(0, cluster.size.x)
      for y in range(0, cluster.size.y)
        for z in range(0, cluster.size.z)
          let cell = int3(x, y, z)
          let key = cluster |> get_key(cell)
          assume voxel = cluster.voxels[key]
          if !voxel.flags.active
            continue
          for dir, idx in each_enum(NeighboursDir.XPLUS), count()
            let neighbourCell = cluster |> get_cell(cell, dir)
            if neighbourCell == cell // cluster border was reached
              continue
            let neighbourKey = cluster |> get_key(neighbourCell)
            assume neighbour = cluster.voxels[neighbourKey]
            if !neighbour.flags.active
              continue

            if idx < 3
              // check connectivity in 3 positive directions
              using(voxel.pos, neighbour.pos, extents) <| $(var inp : CorridorInput#)
                inp.includeFlags |= int(PolyFlag.POLYFLAG_JUMP)
                if (path_corridor |> set_path_corridor(inp, null)) == FindPathResult.FPR_FULL
                  voxel |> set_flag(dir)
            elif neighbour |> get_flag(get_opposite(dir))
              // readback connectivity in 3 negative directions
              voxel |> set_flag(dir)


def fix_cluster(var cluster : ClusterVoxelData)
  // fixup some connections
  for x in range(0, cluster.size.x)
    for y in range(0, cluster.size.y)
      for z in range(0, cluster.size.z)
        let cell = int3(x, y, z)
        let key = cluster |> get_key(cell)
        assume voxel = cluster.voxels[key]
        if voxel.flags.active
          continue
        let downKey = cluster |> get_key(cell, NeighboursDir.YMINUS)
        if !cluster.voxels[downKey].flags.active
          continue

        for sideDir in fixed_array(NeighboursDir.YPLUS, NeighboursDir.XPLUS, NeighboursDir.XMINUS,
                         NeighboursDir.ZPLUS, NeighboursDir.ZMINUS)
          let sideKey = cluster |> get_key(cell, sideDir)
          if cluster.voxels[sideKey].flags.active && cluster.voxels[sideKey].pos.x < FLT_MAX
            // on of side and lower cells are active, this cell can be activated too
            voxel.flags |= VoxelNeighbours.active // just activate cell, without connections
            voxel.pos = float3(FLT_MAX)
            break

struct BranchData
  name : string
  eid : EntityId
  userData : uint8
  headCell : int3
  branchLength : int
  cells : array<int3>
  leafs : table<int3>
  spawnPresets : Object const?
  spawnGroups : Array const?


def construct_branches(centerCell : int3; maxBranchLength : int; var branches : array<BranchData>; var cluster : ClusterVoxelData; var randomSeed : int&)
  for branch in branches
    for cell in branch.cells
      cluster.voxels[cluster |> get_key(cell)].userData = uint8(0)
    branch.cells |> clear()
    branch.cells |> reserve(maxBranchLength)
    branch.headCell = centerCell

  var triesWithoutAdvance = 6
  for _ in range(maxBranchLength)
    var wasAdvance = false
    for branch in branches
      if length(branch.cells) >= branch.branchLength
        continue
      if advance_branch(branch.cells, cluster, randomSeed, branch.headCell, branch.userData)
        branch.headCell = branch.cells[length(branch.cells) - 1]
        wasAdvance = true
      else
        // search cell inside branch with 3+ connections to start new branch from it
        var cellIdx = length(branch.cells) - 2
        while cellIdx >= 0
          let cell = branch.cells[cellIdx]
          let key = cluster |> get_key(cell)
          if get_connections_num(cluster.voxels[key].flags) >= 3
            branch.headCell = cell
            break
          cellIdx -= 1

        if cellIdx >= 0 && advance_branch(branch.cells, cluster, randomSeed, branch.headCell, branch.userData)
          branch.headCell = branch.cells[length(branch.cells) - 1]
          wasAdvance = true
        else
          // restart branch from center
          branch.headCell = centerCell
          if advance_branch(branch.cells, cluster, randomSeed, branch.headCell, branch.userData)
            branch.headCell = branch.cells[length(branch.cells) - 1]
            wasAdvance = true

    if !wasAdvance
      triesWithoutAdvance -= 1
      if triesWithoutAdvance <= 0 // no more cells to advance
        break

[es(tag=server, on_disappear, REQUIRE=anomaly_zone__spawnTraitTemplate)]
def anomaly_zone_destroy(evt : Event; eid : EntityId)
  cleanup_zone_children(eid)


[es(tag=server, on_appear, on_event=(EventNavmeshIslandsMarked, CmdGenerateAnomalyZone))]
def anomaly_zone_appear(evt : Event; eid : EntityId; transform : float3x4;
                        nmesh_voxel__gridStep : float;
                        nmesh_voxel__gridSize : int3;
                        anomaly_zone__branchTemplates : StringList;
                        anomaly_zone__branchesGrowIterations : int;
                        var anomaly_zone__generated : bool&;
                        var nmesh_voxel__randomSeed : int&;
                        anomaly_zone__dryRun = false;
                        anomaly_zone__spawnTraitTemplate : string = "";
                        anomaly_zone__brancheLengthMult = 1.;
                        anomaly_zone__spawnCountMult = 1.;
                        nmesh_voxel__debugDraw = false;
                        nmesh_voxel__debugTime = 40000;
                        nmesh_voxel__debugDrawBranches = false)
  let isNavmeshIslandMarkerAtWork = find_query() <| $ [es(REQUIRE=navmesh_isle_marker)] () => true
  if isNavmeshIslandMarkerAtWork || anomaly_zone__generated
    return
  if !pathfinder_is_loaded()
    error("Cannot generate anomaly zone while pathfinder is not loaded")

  var randomSeed = nmesh_voxel__randomSeed
  if randomSeed == 0
    randomSeed = grnd()
    nmesh_voxel__randomSeed = randomSeed
  anomaly_zone__generated = true
  // TODO: recreate to disable this system
  let startPos = transform[3]
  print("{eid}: {getEntityTemplateName(eid)} start at @ {startPos} rnd_seed={nmesh_voxel__randomSeed}")

  /// init cluster
  var cluster : ClusterVoxelData
  cluster.size = nmesh_voxel__gridSize
  cluster.gridStep = nmesh_voxel__gridStep
  cluster.minWPos = startPos - float3(nmesh_voxel__gridSize) * 0.5 * cluster.gridStep
  init_cluster(cluster)
  fix_cluster(cluster)

  print("{eid}: {getEntityTemplateName(eid)} @ {startPos} cluster was inited. size={cluster.size}")
  if nmesh_voxel__debugDraw
    print("{eid}: {getEntityTemplateName(eid)} @ {startPos} draw cluster data")
    draw_cluster(cluster, nmesh_voxel__debugTime)

  let sides = fixed_array(NeighboursDir.XPLUS, NeighboursDir.XMINUS, NeighboursDir.ZPLUS, NeighboursDir.ZMINUS)

  /// search center 'boss' voxel
  var potentialCenterCell = cluster |> get_cell_by_wpos(startPos)
  var potentialCenterKey = cluster |> get_key(potentialCenterCell)

  var potentialCenters : array<PotentialCenter>

  // move down to reach border
  var maxIterations = nmesh_voxel__gridSize.y + 1
  reserve(potentialCenters, maxIterations + length(sides))
  while maxIterations-- > 0
    let nextCell = cluster |> get_cell(potentialCenterCell, NeighboursDir.YMINUS)
    if nextCell == potentialCenterCell
      break // border was reached
    potentialCenterCell = nextCell
    potentialCenterKey = cluster |> get_key(potentialCenterCell)

  // move up and collect all potential centers
  maxIterations = nmesh_voxel__gridSize.y + 1
  var firstCell = true
  while maxIterations-- > 0
    if !firstCell // check first cell once, only when moving up
      let nextCell = cluster |> get_cell(potentialCenterCell, NeighboursDir.YPLUS)
      if nextCell == potentialCenterCell
        break // border was reached
      potentialCenterCell = nextCell
      potentialCenterKey = cluster |> get_key(potentialCenterCell)
    firstCell = false

    if !cluster.voxels[potentialCenterKey].flags.active
      continue // inactive voxel
    let connectionsNum = get_connections_num(cluster.voxels[potentialCenterKey].flags)
    if connectionsNum == 0
      continue // dead end

    potentialCenters |> emplace(PotentialCenter(cell = potentialCenterCell, key = potentialCenterKey, connectionsNum = connectionsNum))

    for sideDir in sides
      if !get_flag(cluster.voxels[potentialCenterKey], sideDir) // no connection
        continue
      let sideCell = cluster |> get_cell(potentialCenterCell, sideDir)
      if sideCell == potentialCenterCell
        continue // border was reached
      let sideKey = cluster |> get_key(sideCell)
      if !cluster.voxels[sideKey].flags.active // innactive
        continue
      let sideConnectionsNum = get_connections_num(cluster.voxels[sideKey].flags)
      if sideConnectionsNum == 0
        continue
      potentialCenters |> emplace(PotentialCenter(cell = sideCell, key = sideKey, connectionsNum = sideConnectionsNum))

  if length(potentialCenters) == 0
    logwarn("{eid}: {getEntityTemplateName(eid)} @ {startPos} no potential centers found, add nearest side cells as potential centers")
    maxIterations = nmesh_voxel__gridSize.y + 1
    while maxIterations-- > 0
      let nextCell = cluster |> get_cell(potentialCenterCell, NeighboursDir.YMINUS)
      if nextCell == potentialCenterCell
        break // border was reached
      potentialCenterCell = nextCell
      potentialCenterKey = cluster |> get_key(potentialCenterCell)

      for sideDir in sides
        let sideCell = cluster |> get_cell(potentialCenterCell, sideDir)
        if sideCell == potentialCenterCell
          continue // border was reached
        let sideKey = cluster |> get_key(sideCell)
        if !cluster.voxels[sideKey].flags.active // inactive
          continue
        let sideConnectionsNum = get_connections_num(cluster.voxels[sideKey].flags)
        // if sideConnectionsNum == 0
        //   continue
        potentialCenters |> emplace(PotentialCenter(cell = sideCell, key = sideKey, connectionsNum = sideConnectionsNum))

  potentialCenters |> sort() <| $(lhs, rhs)
    if lhs.cell.y != rhs.cell.y
      if potentialCenterCell.y == lhs.cell.y
        return true
      if potentialCenterCell.y == rhs.cell.y
        return false
    return lhs.connectionsNum > rhs.connectionsNum

  if length(anomaly_zone__branchTemplates) > 6
    logwarn("{eid}: {getEntityTemplateName(eid)} @ {startPos} unsupported amount of branches {length(anomaly_zone__branchTemplates)}, max is 6")

  // parse branches data
  var branches : array<BranchData>
  var maxBranchLength = 0
  parse_braches_data(anomaly_zone__branchTemplates, anomaly_zone__brancheLengthMult, randomSeed, maxBranchLength, branches)

  let volume = nmesh_voxel__gridSize.x * nmesh_voxel__gridSize.y * nmesh_voxel__gridSize.z
  var branchesVolume = 0
  for branch in branches
    branchesVolume += branch.branchLength
  if branchesVolume > volume
    logwarn("{eid}: {getEntityTemplateName(eid)} @ {startPos} branches volume {branchesVolume} is greater than total volume {volume}")

  let moveCenterTries = min(10, length(potentialCenters) - 1)
  var potentialCenterIdx = -1
  let seedBeforeBranch = randomSeed
  var bestCenterIdx = -1
  var bestCenterCellsNum = -1

  while potentialCenterIdx < moveCenterTries

    potentialCenterIdx += 1
    let centerKey = potentialCenters[potentialCenterIdx].key
    let centerCell = potentialCenters[potentialCenterIdx].cell

    assume centerVoxel = cluster.voxels[centerKey]
    if !centerVoxel.flags.active
      logwarn("{eid}: {getEntityTemplateName(eid)} @ {startPos} INTERNAL ERROR: potential center is innactive (key:{centerKey})")
      continue

    centerVoxel.userData = uint8(1) // boss cell

    randomSeed = seedBeforeBranch
    construct_branches(centerCell, maxBranchLength, branches, cluster, randomSeed)

    centerVoxel.userData = uint8(0) // drop boss cell

    var cellsNum = 0
    for branch in branches
      cellsNum += length(branch.cells)
    if cellsNum > bestCenterCellsNum
      bestCenterIdx = potentialCenterIdx
      bestCenterCellsNum = cellsNum

  if bestCenterIdx == -1
    logwarn("{eid}: {getEntityTemplateName(eid)} @ {startPos} unable to find best center")
    return

  // regen branches with best center
  let centerKey = potentialCenters[bestCenterIdx].key
  let centerCell = potentialCenters[bestCenterIdx].cell
  print("{eid}: {getEntityTemplateName(eid)} @ {startPos} best center: {centerCell}({bestCenterIdx}) total cells: {bestCenterCellsNum}")
  assume centerVoxel = cluster.voxels[centerKey]
  centerVoxel.userData = uint8(1) // boss cell
  randomSeed = seedBeforeBranch
  construct_branches(centerCell, maxBranchLength, branches, cluster, randomSeed)

  if nmesh_voxel__debugDrawBranches
    for branch in branches
      if length(branch.cells) > 0
        var prevPos = cluster |> get_cell_wpos(branch.cells[0])
        for cell in branch.cells
          let key = cluster |> get_key(cell)
          let cellPos = cluster |> get_cell_wpos(cell)
          draw_debug_line_buffered(prevPos, cellPos, E3DCOLOR(userDataColors?[cluster.voxels[key].userData] ?? 0xFF0000), nmesh_voxel__debugTime)
          cluster |> draw_voxel(cluster.voxels[key], cell, nmesh_voxel__debugTime)
          prevPos = cellPos

    cluster |> draw_voxel(centerVoxel, centerCell, nmesh_voxel__debugTime)


  for branch in branches
    print("{eid}: {getEntityTemplateName(eid)} @ {startPos} branch '{branch.name}' len={length(branch.cells)}")

  /// grow branches (game of live)
  for _ in range(anomaly_zone__branchesGrowIterations)
    for x in range(0, cluster.size.x)
      for y in range(0, cluster.size.y)
        for z in range(0, cluster.size.z)
          let cell = int3(x, y, z)
          let key = cluster |> get_key(cell)
          assume voxel = cluster.voxels[key]
          if !voxel.flags.active || voxel.userData != uint8(0)
            continue

          for branch in branches
            let userData = branch.userData
            var sameNeighbours = 0
            // collect similar cells around (ignore connectivity)
            for direction in each_enum(NeighboursDir.XPLUS)
              let neighbourCell = cluster |> get_cell(cell, direction)
              if neighbourCell != cell && get_flag(voxel, direction) && cluster.voxels[get_key(cluster, neighbourCell)].userData == userData
                sameNeighbours++

            if sameNeighbours == 0
              continue

            let chance = sameNeighbours == 1 ? 0.05 /* 1/20 */ : 0.125 /* 1/8 */
            // TODO: "kill cell" when sameNeighbours > 2?
            if _frnd(randomSeed) < chance
              voxel.userData = userData
              branch.leafs |> insert(cell)
              branch.cells |> push(cell)
              if nmesh_voxel__debugDrawBranches
                cluster |> draw_voxel(voxel, cell, nmesh_voxel__debugTime)
              break

  var totalCells = 0
  for branch in branches
    print("{eid}: {getEntityTemplateName(eid)} @ {startPos} branch with leafs '{branch.name}' leafs num={length(branch.leafs)}")
    totalCells += length(branch.cells)
    if length(branch.cells) == 0
      logwarn("{eid}: {getEntityTemplateName(eid)} @ {startPos} branch '{branch.name}' is empty. Bad initial position?")
  if totalCells == 0
    logwarn("{eid}: {getEntityTemplateName(eid)} @ {startPos} all branches are empty. Bad initial position?")

  /// spawn entites
  for branch in branches
    let cellsNum = length(branch.cells)
    if cellsNum == 0
      continue
    var presets : table<string; SpawnPreset>
    *branch.spawnPresets |> parse_spawn_presets(presets)
    var cellsRatio : array<float>
    cellsRatio |> resize(cellsNum)
    let spawnGroupsData = branch.spawnGroups
    if spawnGroupsData == null
      logwarn("{eid}: {getEntityTemplateName(eid)} @ {startPos} branch '{branch.name}' without spawn group. Skip it")
      continue
    var ignoreCells : table<int3>
    for spawnGroupData in *spawnGroupsData
      let spawnGroup = spawnGroupData as Object
      let presetName = (*spawnGroup).preset ?? ""
      if !key_exists(presets, presetName)
        logwarn("{eid}: {getEntityTemplateName(eid)} @ {startPos} branch '{branch.name}' has unknown preset name '{presetName}'. Skip it")
        continue
      let zoneMinSize = (*spawnGroup).zoneMinSize ?? int3(1, 1, 1)
      if zoneMinSize.x < 1 || zoneMinSize.x > 4 || zoneMinSize.y < 1 || zoneMinSize.y > 4 || zoneMinSize.z < 1 || zoneMinSize.z > 4
        logwarn("{eid}: {getEntityTemplateName(eid)} @ {startPos} branch '{branch.name}' contains unsupported zoneMinSize value {zoneMinSize}. Supported values are 1, 2, 3 or 4")
      let spawnCountRange = (*spawnGroup).spawnCount ?? int2(10, 10)
      let spawnCount = ceili(float(_rnd_int(randomSeed, spawnCountRange.x, spawnCountRange.y)) * anomaly_zone__spawnCountMult)
      let occupyCells = (*spawnGroup).occupyCells ?? true
      let randomizeCenter = (*spawnGroup).randomizeCenter ?? float3(0)
      let spawnOffset = float3(_rnd_float(randomSeed, -randomizeCenter.x, randomizeCenter.x),
                               _rnd_float(randomSeed, -randomizeCenter.y, randomizeCenter.y),
                               _rnd_float(randomSeed, -randomizeCenter.z, randomizeCenter.z))
      let cellChancePow = (*spawnGroup).cellChancePow ?? 0.
      var totalRatio = 0.
      if cellChancePow != 0.
        for ratio, cell in cellsRatio, branch.cells
          ratio = pow(1. / (1. + length_sq(float3(cell - centerCell))), cellChancePow)
          totalRatio += ratio

      presets |> get(presetName) <| $(preset)
        if preset.projectToNavmesh && length_sq(randomizeCenter) > 0.0001
          logwarn("{eid}: {getEntityTemplateName(eid)} @ {startPos} branch '{branch.name}' preset '{presetName}' has randomizeCenter value {randomizeCenter} but projectToNavmesh is true. This is not supported")
        var spawned = 0
        var spawnedEntities = 0
        var tries = 2 * spawnCount * (spawnCount + 1)
        // usually truedCells is empty or very small, so it's more efficient to use array instead of a table
        var triedCells : array<int3>
        while spawned < spawnCount && --tries > 0 && length(ignoreCells) < cellsNum
          var idx = cellsNum
          if cellChancePow == 0.
            idx = _rnd_int(randomSeed, 0, cellsNum - 1)
          else
            var weight = _frnd(randomSeed) * totalRatio
            for i, ratio in iter_range(cellsRatio), cellsRatio
              weight -= ratio
              if weight < 0.
                idx = i
                break
          let cell = branch.cells[idx]
          if key_exists(ignoreCells, cell) ||  has_value(triedCells, cell)
            continue
          var isValidCell = true
          for checkDir in range(3)
            let minSize = zoneMinSize[checkDir]
            if minSize < 2 || minSize > 4
              continue
            let dir = NeighboursDir(checkDir)
            let dirCell = cluster |> get_cell(cell, dir)
            // todo: search only active cells?
            if dirCell == cell || !has_value(branch.cells, dirCell) || key_exists(ignoreCells, dirCell)
              isValidCell = false
              break
            if minSize >= 3
              let oppositeDir = dir |> get_opposite()
              let oppositeCell = cluster |> get_cell(cell, oppositeDir)
              if oppositeCell == cell || !has_value(branch.cells, oppositeCell) || key_exists(ignoreCells, oppositeCell)
                isValidCell = false
                break
            elif minSize == 4
              let dir2Cell = cluster |> get_cell(dirCell, dir)
              if dir2Cell == dirCell || !has_value(branch.cells, dir2Cell) || key_exists(ignoreCells, dir2Cell)
                isValidCell = false
                break
          if !isValidCell
            continue

          let key = cluster |> get_key(cell)
          assume voxel = cluster.voxels[key]
          if preset.projectToNavmesh && voxel.pos.x >= FLT_MAX
            // ignore spawn on navmesh for non walkable voxels
            push(triedCells, cell)
            continue
          if preset.minDistanceToWall != null
            if !voxel.hasDistToWall
              cluster |> init_dist_to_wall(cell, key)

            if (*preset.minDistanceToWall) > voxel.distToWall
              var wallNorm = voxel.wallNorm
              var distToWall = voxel.distToWall
              var resPos = voxel.pos
              var traces = 5
              // move pos away from the wall
              while traces-- > 0 && (*preset.minDistanceToWall) > distToWall
                let smallStep = length_sq(wallNorm) < 0.01 // normal is zero (sometimes) or previous iteration doesn't move position
                if smallStep
                  var s, c : float
                  sincos(_frnd(randomSeed) * TWOPI, s, c)
                  wallNorm = float3(c, 0., s)
                let offset = smallStep ? 0.25 : (*preset.minDistanceToWall) - distToWall
                let wishPos = resPos + wallNorm * offset
                let from = resPos
                let extents = float3(0.5)
                var navPoly = INVALID_POLY_REF
                if !pathfinder::traceray_navmesh(resPos, wishPos, extents, resPos, navPoly)
                  break
                if !is_polygon_accessible(navPoly)
                  break
                if distance_sq(from, resPos) < 0.0001
                  // randomize next normal, this direction doesn't change anything
                  wallNorm = float3()
                  continue
                distToWall = get_distance_to_wall(resPos, 1., 1., wallNorm)
              if (*preset.minDistanceToWall) > distToWall
                push(triedCells, cell)
                continue
              voxel.pos = resPos
              voxel.wallNorm = wallNorm
              voxel.distToWall = distToWall

          var boxMin = cell
          var boxMax = cell
          for checkDir in range(3)
            let minSize = zoneMinSize[checkDir]
            if minSize < 2 || minSize > 4
              continue
            let dir = NeighboursDir(checkDir)
            let dirCell = cluster |> get_cell(cell, dir)
            boxMin = min(boxMin, dirCell)
            boxMax = max(boxMax, dirCell)
            if minSize >= 3
              let oppositeDir = dir |> get_opposite()
              let oppositeCell = cluster |> get_cell(cell, oppositeDir)
              boxMin = min(boxMin, oppositeCell)
              boxMax = max(boxMax, oppositeCell)
            if minSize == 4
              let dir2Cell = cluster |> get_cell(dirCell, dir)
              boxMin = min(boxMin, dir2Cell)
              boxMax = max(boxMax, dir2Cell)


          let boxSize = float3((boxMax - boxMin) + int3(1)) * cluster.gridStep
          let boxWCenter = cluster |> get_cell_wpos((boxMax + boxMin) / 2)
          var wasSpawned = false
          for spawnPreset in preset.items
            if spawnPreset.spawnOnLeafs != null
              if (*spawnPreset.spawnOnLeafs) != key_exists(branch.leafs, cell)
                continue
            var itemTm = IDENT_TM
            if spawnPreset.scaleToBox
              itemTm[0] = float3(boxSize.x, 0., 0.)
              itemTm[1] = float3(0., boxSize.y, 0.)
              itemTm[2] = float3(0., 0., boxSize.z)
            if spawnPreset.inflateBox != null
              for j in range(3)
                let axisLen = length(itemTm[j])
                itemTm[j] *= safediv(axisLen + (*spawnPreset.inflateBox)[j], axisLen)
            if spawnPreset.targetScale != null
              for j in range(3)
                let axisLen = length(itemTm[j])
                itemTm[j] *= safediv((*spawnPreset.targetScale)[j], axisLen)
            itemTm[3] = spawnPreset.projectToNavmesh ? voxel.pos : boxWCenter + spawnOffset * boxSize
            let down = get_grav_dir(transform[3])
            var t = 1.0
            var norm : float3
            if spawnPreset.projectToNavmesh && traceray_normalized(itemTm[3], down, t, norm, ETF_DEFAULT)
              itemTm[3] += down * t
            if spawnPreset.alignToBottom && !spawnPreset.projectToNavmesh
              let offset = (length(itemTm[1]) - boxSize.y) * 0.5
              itemTm[3] += float3(0., offset, 0.)

            if spawnPreset.spawnIndoor != null
              if (*spawnPreset.spawnIndoor) != level_common::is_pos_indoor(itemTm[3]) // use actual spawn pos for check
                continue

            if !wasSpawned
              wasSpawned = true
              spawned += 1

              if occupyCells
                ignoreCells |> insert(cell)
                for checkDir in range(3)
                  let minSize = zoneMinSize[checkDir]
                  if minSize < 2 || minSize > 4
                    continue
                  let dir = NeighboursDir(checkDir)
                  let dirCell = cluster |> get_cell(cell, dir)
                  ignoreCells |> insert(dirCell)
                  if minSize >= 3
                    let oppositeDir = dir |> get_opposite()
                    let oppositeCell = cluster |> get_cell(cell, oppositeDir)
                    ignoreCells |> insert(oppositeCell)
                  if minSize == 4
                    let dir2Cell = cluster |> get_cell(dirCell, dir)
                    ignoreCells |> insert(dir2Cell)

            if !anomaly_zone__dryRun
              spawnedEntities += 1
              let templateName = (!empty(anomaly_zone__spawnTraitTemplate)
                ? spawnPreset.templateName |> add_sub_template_name(anomaly_zone__spawnTraitTemplate)
                : spawnPreset.templateName)
              if spawnPreset.syncCreation
                createEntitySync(templateName) <| $(var ini)
                  ini |> set("transform", itemTm)
                  ini |> set("anomaly_zone__ownerZoneEid", eid)
              else
                createEntity(templateName) <| $(var ini)
                  ini |> set("transform", itemTm)
                  ini |> set("anomaly_zone__ownerZoneEid", eid)

        let freeCells = cellsNum - length(ignoreCells)
        print("{eid}: {getEntityTemplateName(eid)} @ {startPos} branch '{branch.name}' preset '{presetName}' spawns {spawned}/{spawnCount}({spawnCountRange}) entities={spawnedEntities} zoneMinSize={zoneMinSize} freeCells={freeCells}")

  /// cleanup
  for branch in branches
    branch.eid |> destroyEntity()


def parse_braches_data(anomaly_zone__branchTemplates : StringList; anomaly_zone__brancheLengthMult : float;
                       var randomSeed : int&; var maxBranchLength : int&; var branches : array<BranchData>&)
  reserve(branches, length(anomaly_zone__branchTemplates))
  for branchTemplate in anomaly_zone__branchTemplates
    let templateName = string(branchTemplate)
    let eid = createEntitySync(templateName) // create sync to query data immediately
    let ok = query(eid) <| $ [es(REQUIRE=(anomaly_zone__spawnPresets, anomaly_zone__spawnGroups))] (anomaly_zone__branchLength : int2;
                                                                                                    anomaly_zone__spawnPresets : Object const?;
                                                                                                    anomaly_zone__spawnGroups : Array const?)
      let branchLength = ceili(float(_rnd_int(randomSeed, anomaly_zone__branchLength.x, anomaly_zone__branchLength.y)) * anomaly_zone__brancheLengthMult)
      maxBranchLength = max(maxBranchLength, branchLength)

      branches |> emplace <| BranchData(name = templateName, eid = eid,
                                          userData = uint8(length(branches) + 2),// starts from 1 + boss cell
                                          branchLength = branchLength,
                                          spawnPresets = anomaly_zone__spawnPresets,
                                          spawnGroups = anomaly_zone__spawnGroups)
    if !ok
      logerr("wrong template '{branchTemplate}'. unable to find preset data")
      eid |> destroyEntity()


// add one new cell to branch
def advance_branch(var cells : array<int3>; var cluster : ClusterVoxelData; var randomSeed : int&; currentCell : int3;
                   user_data : uint8) : bool

  let key = cluster |> get_key(currentCell)
  assume voxel = cluster.voxels[key]
  // search new direction
  var foundDir = false
  var nextDir : NeighboursDir
  for _ in range(10)
    nextDir = NeighboursDir(_rnd_int(randomSeed, 0, 5))
    if !get_flag(voxel, nextDir)
      continue
    let dirKey = cluster |> get_key(currentCell, nextDir)
    if cluster.voxels[dirKey].userData != uint8(0u)
      continue
    cluster.voxels[dirKey].userData = user_data
    cells |> push(cluster |> get_cell(currentCell, nextDir))
    foundDir = true
    break
  if !foundDir
    // fallback logic, just search walkable direction
    for dir in each_enum(NeighboursDir.XPLUS)
      if !get_flag(voxel, dir)
        continue
      let dirKey = cluster |> get_key(currentCell, dir)
      if cluster.voxels[dirKey].userData != uint8(0u)
        continue
      cluster.voxels[dirKey].userData = user_data
      cells |> push(cluster |> get_cell(currentCell, dir))
      nextDir = dir
      foundDir = true
      break

  return foundDir


// -- debug render

require DagorDebug3D

def draw_cluster(cluster : ClusterVoxelData; draw_time : int)
  for x in range(0, cluster.size.x)
    for y in range(0, cluster.size.y)
      for z in range(0, cluster.size.z)
        let cell = int3(x, y, z)
        cluster |> draw_voxel(cluster.voxels[cluster |> get_key(cell)], cell, draw_time)


let userDataColors = fixed_array<uint>(
  0xFFFFFFFF,
  0xFFFFFFFF,
  0xFFFF0000,
  0xFF0000FF,
  0xFFFF00FF,
  0xFFFFFF00,
  0xFF00FFFF,
  0xFFFFFFFF
)


def draw_voxel(cluster : ClusterVoxelData; voxel : VoxelData; cell : int3; drawTime : int)
  if !voxel.flags.active
    return
  let boxOffset = float3(cluster.gridStep * 0.49)
  let center = cluster |> get_cell_wpos(cell)
  let color = !voxel.flags.active ? E3DCOLOR(0xFFFF0000) : voxel.userData != uint8(0u) ? E3DCOLOR(userDataColors?[int(voxel.userData)] ?? 0xFF0000) : E3DCOLOR(0xFF00FF00)
  draw_debug_box_buffered(center - boxOffset, center + boxOffset, color, drawTime)
  if voxel.pos.x < FLT_MAX
    draw_debug_tehedron_buffered(voxel.pos, 0.2, color, drawTime)
    draw_debug_line_buffered(center, voxel.pos, E3DCOLOR(0x440000FF), drawTime)

  for dir in each_enum(NeighboursDir.XPLUS)
    let connected = voxel |> get_flag(dir)
    let conColor = connected ? E3DCOLOR(0xFF00FF00) : E3DCOLOR(0xFFFF0000)
    draw_debug_line_buffered(center, center + float3(neighboursDir[int(dir)]) * 0.2, conColor, drawTime)

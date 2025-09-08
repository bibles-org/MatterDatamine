require ecs
require app
require math.base
require game.events.events_active_matter
require game.es.protected_am_core_common
require game.events.events
require pathfinder
require math.random
require game.es.level_common
require game.es.grav_zones_common
require Grid
require DagorMath
require Dacoll
require DagorSystem


[es(tag=server, on_appear)]
def protected_am_core_init(evt : Event;
                           protected_am_core__roundsCountMax : int;
                           transform : float3x4;
                           protected_am_core__patrolPath : Point3List;
                           var protected_am_core__originPos : float3&;
                           var protected_am_core__state : int&;
                           var protected_am_core__fightForbiddenUntilTime : float&;
                           var protected_am_core__roundsCount : int&;
                           var protected_am_core__patrolGeneratePathOnSetup : bool&)
  protected_am_core__state = int(ProtectedAmCoreState.SETUP_PATROL)
  protected_am_core__originPos = transform[3]
  project_to_nearest_navmesh_point(protected_am_core__originPos, 1.0)
  protected_am_core__fightForbiddenUntilTime = get_sync_time() + 3.0
  protected_am_core__roundsCount = protected_am_core__roundsCountMax
  protected_am_core__patrolGeneratePathOnSetup = (length(protected_am_core__patrolPath) == 0)


[es(tag=server, track=protected_am_core__state)]
def protected_am_core_track_state(evt : Event;
                                  eid aka core_eid : EntityId;
                                  am_core__maxHpRng : float2;
                                  protected_am_core__roundsCountMax : int;
                                  am_core__maxHpStep : float;
                                  protected_am_core__fightHeight : float;
                                  transform : float3x4;
                                  protected_am_core__patrolling : Tag const?;
                                  var protected_am_core__fightArenaPos : float3&;
                                  var protected_by_warriors__origin : float3&;
                                  var protected_am_core__state : int&;
                                  var hitpoints__maxHp : float&;
                                  var am_core__protectiveSphereEnabled : bool&;
                                  var protected_by_warriors__enabled : bool&;
                                  var am_core_damage_sphere_controller__damageSphereEnabled : bool&;
                                  var hitpoints__hp : float&;
                                  var am_core__fragmentsLimit : int&;
                                  var protected_am_core__lastEnemyAgroTime : float&;
                                  var protected_am_core__roundsCount : int&;
                                  var am_core__moveTo : float3&;
                                  var am_core__protectiveSphereAttached : bool&;
                                  var am_core_damage_sphere_controller__attached : bool&;
                                  var protected_am_core__patrolSpeed : float&)
  var protectiveSphereEnabled = false
  var warrionsEnabled = false
  var damageSphereEnabled = false

  let patrollingTemplate = "protected_am_core_patrolling"
  if protected_am_core__state != int(ProtectedAmCoreState.PATROL) && protected_am_core__patrolling != null
    removeSubTemplate(core_eid, patrollingTemplate)

  if protected_am_core__state == int(ProtectedAmCoreState.SETUP_PATROL)
    hitpoints__hp = 0.0
    am_core__fragmentsLimit = 0
    am_core__protectiveSphereAttached = true
    am_core_damage_sphere_controller__attached = true
    protected_am_core__patrolSpeed = 0.0
  elif protected_am_core__state == int(ProtectedAmCoreState.PATROL)
    hitpoints__hp = 0.0
    am_core__fragmentsLimit = 0
    am_core__protectiveSphereAttached = true
    am_core_damage_sphere_controller__attached = true
    addSubTemplate(core_eid, patrollingTemplate)
  elif protected_am_core__state == int(ProtectedAmCoreState.STARTING_FIGHT)
    protectiveSphereEnabled = true
    warrionsEnabled = true
    damageSphereEnabled = true

    am_core__protectiveSphereAttached = false
    am_core_damage_sphere_controller__attached = false

    hitpoints__maxHp = am_core__maxHpRng.x
    hitpoints__maxHp -= am_core__maxHpStep // to counteract am_core_warming_up_act
    hitpoints__hp = hitpoints__maxHp
    am_core__fragmentsLimit = 1000
    protected_am_core__roundsCount = protected_am_core__roundsCountMax
    protected_am_core__lastEnemyAgroTime = get_sync_time()

    protected_am_core__fightArenaPos = transform[3]
    protected_by_warriors__origin = protected_am_core__fightArenaPos

    var height = 50.0
    if tracedown_normalized(transform[3], height, ETF_DEFAULT)
      let groundY = transform[3].y - height
      am_core__moveTo.y = groundY + protected_am_core__fightHeight

    protected_am_core__state = int(ProtectedAmCoreState.FIGHT)

  elif protected_am_core__state == int(ProtectedAmCoreState.FIGHT)
    protectiveSphereEnabled = true
    warrionsEnabled = true
    damageSphereEnabled = true
  elif protected_am_core__state == int(ProtectedAmCoreState.ENDING_FIGHT)
    protectiveSphereEnabled = true

    hitpoints__hp = 0.0
    am_core__fragmentsLimit = 0
  elif protected_am_core__state == int(ProtectedAmCoreState.DEAD)
    protected_am_core__roundsCount = 0
    hitpoints__hp = 0.0

  am_core__protectiveSphereEnabled = protectiveSphereEnabled
  protected_by_warriors__enabled = warrionsEnabled
  am_core_damage_sphere_controller__damageSphereEnabled = damageSphereEnabled


[es(tag=server, after=loot_drop_system_create_loot)]
def protected_am_core_loot_dropped(evt : EventDropLootRequest;
                                   eid aka core_eid : EntityId;
                                   am_core__createOnDestroyTemplate : string;
                                   transform aka core_transform : float3x4;
                                   var protected_am_core__roundsCount : int&)
  --protected_am_core__roundsCount
  if protected_am_core__roundsCount <= 0
    destroyEntity(core_eid)
    createEntity(am_core__createOnDestroyTemplate) <| $(var init : ComponentsInitializer)
      init |> set("ownerEid", eid)
      init |> set("transform", core_transform)
    broadcastEvent(EventAmCoreExhausted(eid = eid))


def has_am_core_target_in_radius(pos : float3;
                                 radius : float)
  let sphere = BSphere3(pos, radius)
  let enemyEid = find_entity_in_grid(ecs_hash("humans"), sphere, GridEntCheck.POS) <| $(target_eid : EntityId)
    var success = false
    query(target_eid) <| $ [es(REQUIRE_NOT=deadEntity, REQUIRE=(ai_target, human_net_phys))] (transform aka target_transform : float3x4)
      let targetPos = target_transform[3] + float3(0.0, 0.5, 0.0)
      let delta = targetPos - pos
      let distSq = length_sq(delta)
      if distSq > 1e-3
        let dist = sqrt(distSq)
        let dir = delta / dist
        var norm : float3
        var t = dist
        if traceray_normalized(pos, dir, t, norm)
          return
      success = true
    return success
  return enemyEid != INVALID_ENTITY_ID


def is_patrol_point_valid(pos : float3;
                          indoor_threshold = 0.5)
  var waterLevel = 0.0
  let hasWater = traceht_water(pos, waterLevel)
  if hasWater && waterLevel > pos.y
    return false

  if level_common::is_pos_indoor(pos, indoor_threshold)
    return false

  return true


[es(tag=server, REQUIRE=protected_am_core__patrolling, before=(protected_am_core_update, am_core_phys_snapshots))]
def protected_am_core_patrolling(act : ParallelUpdateFrameDelayed;
                                 protected_am_core__patrolPath : Point3List;
                                 protected_am_core__patrolSpeedMinMax : float2;
                                 protected_am_core__patrolHeight : float;
                                 protected_am_core__patrolPathMode : int;
                                 transform : float3x4;
                                 var protected_am_core__patrolPathForward : bool&;
                                 var protected_am_core__patrolSpeed : float&;
                                 var protected_am_core__patrolPathPointIndex : int&;
                                 var protected_am_core__state : int&;
                                 var protected_am_core__velocity : float3&)
  let pathNodesCount = length(protected_am_core__patrolPath)
  assume patrolPathPointIndex = protected_am_core__patrolPathPointIndex
  if patrolPathPointIndex < 0 || protected_am_core__patrolPathPointIndex >= pathNodesCount

    if pathNodesCount == 0
      protected_am_core__state = int(ProtectedAmCoreState.SETUP_PATROL)
      return

    if protected_am_core__patrolPathMode == int(ProtectedAmCorePatrolPathMode.PING_PONG)
      patrolPathPointIndex = patrolPathPointIndex < 0 ? 0 : pathNodesCount - 1
      protected_am_core__patrolPathForward = !protected_am_core__patrolPathForward
    elif protected_am_core__patrolPathMode == int(ProtectedAmCorePatrolPathMode.LOOP)
      patrolPathPointIndex = patrolPathPointIndex < 0 ? pathNodesCount - 1 : 0
    else
      protected_am_core__state = int(ProtectedAmCoreState.SETUP_PATROL)
      return

  let patrolPoint = protected_am_core__patrolPath[patrolPathPointIndex] + float3(0.0, protected_am_core__patrolHeight, 0.0)

  let isLastPatrolPoint = ((protected_am_core__patrolPathForward && patrolPathPointIndex == (pathNodesCount - 1)) ||
                           (!protected_am_core__patrolPathForward && patrolPathPointIndex == 0))

  if isLastPatrolPoint && protected_am_core__patrolPathMode != int(ProtectedAmCorePatrolPathMode.LOOP)
    protected_am_core__patrolSpeed = approach(protected_am_core__patrolSpeed, protected_am_core__patrolSpeedMinMax.x, act.dt, 0.5)
  else
    protected_am_core__patrolSpeed = approach(protected_am_core__patrolSpeed, protected_am_core__patrolSpeedMinMax.y, act.dt, 0.5)

  let dir = patrolPoint - transform[3]
  let dlenSq = length_sq(dir)
  let distToleranceSq = square(2.0)
  if dlenSq <= distToleranceSq
    protected_am_core__patrolPathForward ? patrolPathPointIndex++ : patrolPathPointIndex--
    if patrolPathPointIndex >= 0 && patrolPathPointIndex < pathNodesCount
      if !is_patrol_point_valid(protected_am_core__patrolPath[patrolPathPointIndex], 0.1)
        protected_am_core__state = int(ProtectedAmCoreState.SETUP_PATROL)
        return
  else
    let force = (dir / sqrt(dlenSq)) * protected_am_core__patrolSpeed
    protected_am_core__velocity += force * act.dt


[es(tag=server, after=protected_am_core_patrolling, before=(protected_am_core_update, am_core_phys_snapshots))]
def protected_am_core_phys(act : ParallelUpdateFrameDelayed;
                           protected_am_core__damping : float2;
                           protected_am_core__state : int;
                           var protected_am_core__velocity : float3&;
                           var transform : float3x4;
                           var am_core__moveTo : float3&)
  transform[3] += protected_am_core__velocity * act.dt
  let damping = float3(protected_am_core__damping.x, protected_am_core__damping.y, protected_am_core__damping.x)
  protected_am_core__velocity *= float3(1.0) / (float3(1.0) + damping * act.dt)

  if protected_am_core__state == int(ProtectedAmCoreState.PATROL)
    am_core__moveTo = transform[3]


[es(tag=server, REQUIRE=protected_am_core__patrolling)]
def protected_am_core_on_projectile_hit(evt : EventOnProjectileHit;
                                        protected_am_core__activateFightOnProjectileHit : bool = true;
                                        var protected_am_core__state : int&)
  if protected_am_core__state == int(ProtectedAmCoreState.PATROL)
    if protected_am_core__activateFightOnProjectileHit
      protected_am_core__state = int(ProtectedAmCoreState.STARTING_FIGHT)


def detail_protected_am_core_path(segment_length : float;
                                  var patrol_path : Point3List;
                                  var patrol_path_point_index : int&)
  if length(patrol_path) == 0
    return

  let segmentLengthSq = square(segment_length)

  var newPathPointIndex = -1
  using() <| $(var newPath : Point3List)
    for i in range(length(patrol_path) - 1)
      let prevPointIdx = i
      let curPointIdx = i + 1

      let prevPoint = patrol_path[prevPointIdx]
      let curPoint = patrol_path[curPointIdx]

      if patrol_path_point_index == i
        newPathPointIndex = length(newPath)

      newPath |> push(prevPoint)

      let curSegmentDelta = curPoint - prevPoint
      let curSegmentLengthSq = length_sq(curSegmentDelta)
      if curSegmentLengthSq > segmentLengthSq
        let curSegmentLength = sqrt(curSegmentLengthSq)
        let toCurPointDir = curSegmentDelta / curSegmentLength

        let newPointsCount = int(curSegmentLength / segment_length) - 1
        var newPoint = prevPoint
        for _ in range(newPointsCount)
          newPoint += toCurPointDir * segment_length
          newPath |> push(newPoint)

    if newPathPointIndex == -1
      newPathPointIndex = length(newPath)
    newPath |> push(patrol_path[length(patrol_path) - 1])

    patrol_path := newPath
    patrol_path_point_index = newPathPointIndex


def randomize_protected_am_core_path_height(var patrol_path : Point3List;
                                            height_perlin_factor : float;
                                            eid : EntityId)
  // Randomize height by perlin noise
  for patrolPointIdx in iter_range(patrol_path)
    assume patrolPoint = patrol_path[patrolPointIdx]
    assume perlinFactor = height_perlin_factor
    let salt = float(int(256u * uint(eid)) % 32000) / 32000.0
    let perlinOffset = max(0.0, perlin_noise1(float(patrolPointIdx) * 38.57 + salt) * perlinFactor)

    let gravityDirection = get_grav_dir(patrolPoint)
    patrolPoint -= gravityDirection * perlinOffset


[es(tag=server, no_order)]
def protected_am_core_update(act : ParallelUpdateFrameDelayed;
                             eid aka core_eid : EntityId;
                             protected_am_core__fightArenaPos : float3;
                             protected_am_core__triggerFightRadius : float;
                             protected_am_core__updateInterval : float;
                             protected_am_core__noAgroCalmTime : float;
                             protected_am_core__fightForbiddenInterval : float;
                             protected_am_core__originPos : float3;
                             protected_am_core__patrolRadius : float;
                             protected_by_warriors__agroRadius : float;
                             protected_am_core__patrolGeneratePathOnSetup : bool;
                             protected_am_core__patrolPathFindWaypointsDist : float;
                             protected_am_core__patrolHeightPerlinFactor : float = 10.0;
                             var protected_am_core__patrolPathMode : int&;
                             var protected_am_core__patrolPathPointIndex : int&;
                             var transform aka core_transform : float3x4;
                             var protected_am_core__updateAt : float&;
                             var protected_am_core__state : int&;
                             var protected_am_core__lastEnemyAgroTime : float&;
                             var protected_am_core__fightForbiddenUntilTime : float&;
                             var am_core__protectiveSphereEnabled : bool&;
                             var protected_am_core__patrolPath : Point3List;
                             var am_core__moveTo : float3&)
  if protected_am_core__updateAt > act.curTime
    return

  protected_am_core__updateAt = act.curTime + protected_am_core__updateInterval

  if protected_am_core__state == int(ProtectedAmCoreState.SETUP_PATROL)
    if !are_grav_zones_loaded()
      return
    protected_am_core__patrolPathPointIndex = 0

    if protected_am_core__patrolPathFindWaypointsDist > 0.0
      let findWaypointsDistSq = square(protected_am_core__patrolPathFindWaypointsDist)
      var closestWaypointsEid = INVALID_ENTITY_ID
      var closestWaypointIndex = -1
      var closestWaypointDistSq = FLT_MAX
      query() <| $ [es] (eid aka waypoints_eid : EntityId;
                         transform aka waypoints_transform : float3x4;
                         navmesh_waypoints__waypoints : Point3List;
                         navmesh_waypoints__localSpace : bool;
                         navmesh_waypoints__projectedWaypoints : Point3List const?)
        assume waypoints = (navmesh_waypoints__projectedWaypoints != null ? *navmesh_waypoints__projectedWaypoints : navmesh_waypoints__waypoints)
        if distance_sq(core_transform[3], waypoints_transform[3]) > findWaypointsDistSq
          return

        for waypointIdx in iter_range(waypoints)
          var waypointPosition = waypoints[waypointIdx]
          if navmesh_waypoints__projectedWaypoints == null && navmesh_waypoints__localSpace
            waypointPosition = waypoints_transform * waypointPosition
          let distToWaypointSq = distance_sq(core_transform[3], waypointPosition)
          if distToWaypointSq < closestWaypointDistSq
            closestWaypointsEid = waypoints_eid
            closestWaypointIndex = waypointIdx
            closestWaypointDistSq = distToWaypointSq
      var waypointsFound = false
      query(closestWaypointsEid) <| $ [es] (transform aka waypoints_transform : float3x4;
                                            navmesh_waypoints__waypoints : Point3List;
                                            navmesh_waypoints__localSpace : bool;
                                            navmesh_waypoints__projectedWaypoints : Point3List const?;
                                            navmesh_waypoints__looped : bool)
        if navmesh_waypoints__projectedWaypoints != null
          protected_am_core__patrolPath := *navmesh_waypoints__projectedWaypoints
        else
          protected_am_core__patrolPath := navmesh_waypoints__waypoints
          if navmesh_waypoints__localSpace
            for waypointPosition in protected_am_core__patrolPath
              waypointPosition = waypoints_transform * waypointPosition
        protected_am_core__patrolPathPointIndex = closestWaypointIndex
        protected_am_core__patrolPathMode = (navmesh_waypoints__looped ? int(ProtectedAmCorePatrolPathMode.LOOP)
                                                                       : int(ProtectedAmCorePatrolPathMode.PING_PONG))
        waypointsFound = true

        detail_protected_am_core_path(3.0,
                                      protected_am_core__patrolPath,
                                      protected_am_core__patrolPathPointIndex)

        randomize_protected_am_core_path_height(protected_am_core__patrolPath,
                                                protected_am_core__patrolHeightPerlinFactor,
                                                core_eid)

      if waypointsFound
        protected_am_core__state = int(ProtectedAmCoreState.PATROL)
        return

    if protected_am_core__patrolGeneratePathOnSetup
      protected_am_core__patrolPath |> clear()
      let rndPatrolPointOffset = rnd_dir2() * rnd_float(0.5, 1.0) * protected_am_core__patrolRadius
      var rndPatrolPoint = protected_am_core__originPos + float3(rndPatrolPointOffset.x, 0.0, rndPatrolPointOffset.y)
      project_to_nearest_navmesh_point(rndPatrolPoint, 1.0)
      if !is_patrol_point_valid(rndPatrolPoint, 2.5)
        return

      let extents = float3(1.5, FLT_MAX, 1.5)

      var startPathPoint = core_transform[3]
      var height = 10.0
      if tracedown_normalized(startPathPoint, height, ETF_ALL)
        startPathPoint.y = transform[3].y - height
      project_to_nearest_navmesh_point(startPathPoint, 1.0)

      var isStartPathPointValid = true
      using(protected_am_core__originPos, startPathPoint, extents) <| $(var req : pathfinder::FindRequest#)
        var closestPathNode : float3
        let originToCurPointPath = find_path(req, 2.0, 2.0) <| $(data)
          if length(data) > 0
            closestPathNode = data[length(data) - 1]
        if originToCurPointPath == FindPathResult.FPR_PARTIAL
          startPathPoint = closestPathNode
          return

        if originToCurPointPath != FindPathResult.FPR_FULL
          isStartPathPointValid = false
      if !isStartPathPointValid
        return

      using(startPathPoint, rndPatrolPoint, extents) <| $(var req : pathfinder::FindRequest#)
        let resPath = find_path(req, 2.0, 2.0) <| $(data)
          let pointsCount = length(data)
          if pointsCount > 1 && pointsCount < 1000
            let checkPointIndex0 = int(float(pointsCount) * 0.25)
            let checkPointIndex1 = int(float(pointsCount) * 0.5)
            let checkPointIndex2 = int(float(pointsCount) * 0.75)
            if (is_patrol_point_valid(data[checkPointIndex0]) &&
                is_patrol_point_valid(data[checkPointIndex1]) &&
                is_patrol_point_valid(data[checkPointIndex2]))
              for p in data
                protected_am_core__patrolPath |> push(p)
        if resPath == FindPathResult.FPR_FAILED
          protected_am_core__patrolPath |> clear()
        else
          if length(protected_am_core__patrolPath) > 0

            randomize_protected_am_core_path_height(protected_am_core__patrolPath,
                                                    protected_am_core__patrolHeightPerlinFactor,
                                                    core_eid)

            protected_am_core__state = int(ProtectedAmCoreState.PATROL)
    else
      protected_am_core__state = int(ProtectedAmCoreState.PATROL)

  elif protected_am_core__state == int(ProtectedAmCoreState.PATROL)
    if protected_am_core__fightForbiddenUntilTime < act.curTime
      if has_am_core_target_in_radius(core_transform[3], protected_am_core__triggerFightRadius)
        protected_am_core__state = int(ProtectedAmCoreState.STARTING_FIGHT)
  elif protected_am_core__state == int(ProtectedAmCoreState.FIGHT)
    if has_am_core_target_in_radius(protected_am_core__fightArenaPos, protected_by_warriors__agroRadius)
      protected_am_core__lastEnemyAgroTime = act.curTime
    elif protected_am_core__lastEnemyAgroTime != 0.0
      let timePassedFromLastAgro = act.curTime - protected_am_core__lastEnemyAgroTime
      if timePassedFromLastAgro >= protected_am_core__noAgroCalmTime
        protected_am_core__state = int(ProtectedAmCoreState.ENDING_FIGHT)
        protected_am_core__fightForbiddenUntilTime = act.curTime + protected_am_core__fightForbiddenInterval
  elif protected_am_core__state == int(ProtectedAmCoreState.ENDING_FIGHT)
    am_core__moveTo = protected_am_core__fightArenaPos
    let distanceSq = distance_sq(core_transform[3], protected_am_core__fightArenaPos)
    if distanceSq < square(1e-1)
      core_transform[3] = protected_am_core__fightArenaPos
      protected_am_core__state = int(ProtectedAmCoreState.PATROL)

    if distanceSq < square(3.0)
      am_core__protectiveSphereEnabled = false


[es(tag=server, track=isAlive, after=am_core_enter_protective_mode_server)]
def protected_am_core_track_alive(evt : Event;
                                  isAlive : bool;
                                  am_core__fragmentsLimit : int;
                                  var protected_am_core__state : int&)
  if !isAlive
    if am_core__fragmentsLimit <= 0 && protected_am_core__state == int(ProtectedAmCoreState.FIGHT)
      protected_am_core__state = int(ProtectedAmCoreState.DEAD)

options always_export_initializer = true

require app
require ecs
require ecs.common
require strings
require DagorSystem
require BehNodes
require DagorDataBlock
require DagorRandom
require Dacoll
require Grid
require GridCollision
require pathfinder
require math.base
require math.random
require math.linear
require DagorMath
require DagorDebug3D
require game.utils.team
require walkerai
require DngWalkerai
require HumanPhys
require GamePhys
require DngHuman
require DngNet
require DngDm
require CollisionTraces
require debug.logerr_once
require game.es.changed_common
require danetlibs.pathfinder.main.pathfinder_common
require danetlibs.navmesh_phys.main.ai.nphys_nodes_common
require game.es.flanking_ai_common
require game.es.protected_am_core_common
require game.es.level_common
require game.es.ecs_common
require game.es.grav_zones_common
require game.es.flashlights.flashlight_common
require game.es.am_nphys_common
require NavmeshMapping
require game.es.ai.agent_position_mapping_common
require danetlibs.navmesh_phys.main.ai.nphys_common
require game.es.monster_common
require game.events.events_active_matter
require game.events.events_game
require game.es.riextra_damage_common



[beh_node(name="checkAlive")]
class CheckAlive : BehNodeAdapter
  targetParam : string
  @hidden targetParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("targetParam", targetParam, targetParamHash, thisNode)

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    let eid = beh_tree_eid(owner)
    let targetParamRef = eid |> get_Eid(targetParam, targetParamHash)
    if targetParamRef != null
      query(*targetParamRef) <| $ [es] (isAlive : bool)
        res = isAlive ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED
    return res


[beh_node(name="checkAliveBb")]
class CheckAliveBb : BehNodeAdapter
  targetParam : int

  def override loadFromBlk(var data : DataBlock)
    let paramName = data |> datablock_getStr("target", "")
    if paramName == ""
      logerr("checkAliveBb: \"target\" not specified")
      return
    targetParam = owner.blackBoard |> get_or_create(paramName, int(uint(INVALID_ENTITY_ID)))

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    let targetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(targetParam)))
    query(targetEid) <| $ [es] (isAlive : bool)
      if isAlive
        result = EBehResult.ER_SUCCESS
    return result


[beh_node(name="checkInsideAnotherDimension")]
class CheckInsideAnotherDimension : BehNodeAdapter
  targetParam : string
  @hidden targetParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("targetParam", targetParam, targetParamHash, thisNode)

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    let eid = beh_tree_eid(owner)
    let targetParamRef = eid |> get_Eid(targetParam, targetParamHash)
    if targetParamRef != null
      query(*targetParamRef) <| $ [es] (another_dimension_visitor__inside : bool)
        res = another_dimension_visitor__inside ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED
    return res


class AbstractAmIsEntityLookingAtPos : BehNodeAdapter
  sectorAngle : float = PI

  def override loadFromBlk(var data : DataBlock)
    sectorAngle = data |> datablock_getReal("sectorAngle", rad_to_deg(sectorAngle))
    sectorAngle = deg_to_rad(sectorAngle)

  def fetchPosAndDirection(eid : EntityId;
                           var pos : float3&;
                           var dir : float3&)
    pos = float3(FLT_MAX, FLT_MAX, FLT_MAX)
    query(eid) <| $ [es] (transform : float3x4)
      pos = transform[3]
      dir = normalize(float3(transform[0].x, 0.0, transform[0].z))

  def abstract getTargetPos(eid : EntityId) : float3

  [unused_argument(dt)] def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    var srcPos = float3(FLT_MAX, FLT_MAX, FLT_MAX)
    var dir = float3(FLT_MAX, FLT_MAX, FLT_MAX)
    fetchPosAndDirection(eid, srcPos, dir)
    if srcPos == float3(FLT_MAX, FLT_MAX, FLT_MAX) || dir == float3(FLT_MAX, FLT_MAX, FLT_MAX)
      return EBehResult.ER_FAILED
    let targetPos = getTargetPos(eid)
    if targetPos == float3(FLT_MAX, FLT_MAX, FLT_MAX)
      return EBehResult.ER_FAILED

    let toTargetDelta = targetPos - srcPos
    let toTargetDir = normalize(float3(toTargetDelta.x, 0.0, toTargetDelta.z))
    let d = dot(dir, toTargetDir)
    return (1.0 - d) * PI <= sectorAngle ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="amIsTargetLookingAtPos")]
class AmIsTargetLookingAtPos : AbstractAmIsEntityLookingAtPos
  targetParam : string
  @hidden targetParamHash : uint
  posParam : string
  @hidden posParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    AbstractAmIsEntityLookingAtPos`loadFromBlk(self, data)
    data |> load_ecs_param("targetParam", targetParam, targetParamHash, thisNode)
    data |> load_ecs_param("posParam", posParam, posParamHash, thisNode)

  def override fetchPosAndDirection(eid : EntityId;
                                    var pos : float3&;
                                    var dir : float3&)
    pos = float3(FLT_MAX, FLT_MAX, FLT_MAX)

    let targetParamRef = eid |> get_Eid(targetParam, targetParamHash)
    if targetParamRef == null
      logerr_once("{eid}: amIsTargetLookingAtPos can't to find target '{targetParam}:{targetParamHash}' {*thisNode |> beh_node_hierarchy_name(true)}")

    if !doesEntityExist(*targetParamRef)
      logerr_once("{eid}: amIsTargetLookingAtPos entity {*targetParamRef} is not exists! {*thisNode |> beh_node_hierarchy_name(true)}")

    query(*targetParamRef) <| $ [es] (transform : float3x4)
      pos = transform[3]
      dir = normalize(float3(transform[0].x, 0.0, transform[0].z))

  def override getTargetPos(eid : EntityId) : float3
    return get_Point3(eid, posParam, posParamHash) ?? float3(FLT_MAX, FLT_MAX, FLT_MAX)


[beh_node(name="amIsTargetLookingInMyDirection")]
class AmIsTargetLookingInMyDirection : AbstractAmIsEntityLookingAtPos
  targetParam : string
  @hidden targetParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    AbstractAmIsEntityLookingAtPos`loadFromBlk(self, data)
    data |> load_ecs_param("targetParam", targetParam, targetParamHash, thisNode)

  def override fetchPosAndDirection(eid : EntityId;
                                    var pos : float3&;
                                    var dir : float3&)
    pos = float3(FLT_MAX, FLT_MAX, FLT_MAX)

    let targetParamRef = eid |> get_Eid(targetParam, targetParamHash)
    if targetParamRef == null
      logerr_once("{eid}: amIsTargetLookingInMyDirection can't to find target '{targetParam}:{targetParamHash}' {*thisNode |> beh_node_hierarchy_name(true)}")

    if !doesEntityExist(*targetParamRef)
      logerr_once("{eid}: amIsTargetLookingInMyDirection entity {*targetParamRef} is not exists! {*thisNode |> beh_node_hierarchy_name(true)}")

    query(*targetParamRef) <| $ [es] (transform : float3x4)
      pos = transform[3]
      dir = normalize(float3(transform[0].x, 0.0, transform[0].z))

  def override getTargetPos(eid : EntityId) : float3
    var pos = float3(FLT_MAX, FLT_MAX, FLT_MAX)
    query(eid) <| $ [es] (transform : float3x4)
      pos = transform[3]
    return pos


[beh_node(name="nPhysTeleport")]
class NPhysTeleport : BehNodeAdapter
  posParam : string
  @hidden posParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("posParam", posParam, posParamHash, thisNode)

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    let targetPosRef = eid |> get_Point3(posParam, posParamHash)
    if targetPosRef == null
      logerr_once("{eid}: nPhysCorridorMoveToPos unable to find target position '{posParam}:{posParamHash}' {*thisNode |> beh_node_hierarchy_name(true)}")
      return EBehResult.ER_FAILED

    return nphys_teleport_to_position(eid, *targetPosRef) ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="nPhysTeleportAlongTargetLookDir")]
class NPhysTeleportAlongTargetLookDir : BehNodeAdapter
  targetParam : string
  @hidden targetParamHash : uint
  distance : float2

  def override loadFromBlk(var data : DataBlock)
    distance = data |> datablock_getPoint2("distance", distance)
    data |> load_ecs_param("targetParam", targetParam, targetParamHash)

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    let eid = beh_tree_eid(owner)
    let targetEid = get_Eid(eid, targetParam, targetParamHash) ?? INVALID_ENTITY_ID
    query(targetEid) <| $ [es] (transform aka target_transform : float3x4)
      let targetPos = target_transform[3]
      let targetLookDir = target_transform[0]
      let teleportPos = targetPos + targetLookDir * rnd_float(distance.x, distance.y)
      if nphys_teleport_to_position(eid, teleportPos)
        result = EBehResult.ER_SUCCESS
    return result

def is_location_secluded(pos : float3; successes_required : float; check_length : float)
  let sphere = BSphere3(pos, check_length)
  let anotherHuman = find_entity_in_grid(ecs_hash("humans"), sphere, GridEntCheck.BOUNDING) <| $ [unused_argument(targetPos), unused_argument(targetEid)] (targetEid : EntityId; targetPos : float3)
    return true
  if anotherHuman != INVALID_ENTITY_ID
    return false

  var dirs : array<float3>
  dirs |> push(float3(0, 1, 0))
  var s, c, rndShift : float

  rndShift = gfrnd() * TWOPI
  for i in range(5)
    sincos(rndShift + TWOPI * float(i) / 5.0, s, c)
    dirs |> push(normalize(float3(c, 0.85, s)))
  rndShift += PI / 20.0
  for i in range(10)
    sincos(rndShift + TWOPI * float(i) / 10.0, s, c)
    dirs |> push(normalize(float3(c, 0.65, s)))
  rndShift += PI / 20.0
  for i in range(5)
    sincos(rndShift + TWOPI * float(i) / 5.0, s, c)
    dirs |> push(normalize(float3(c, 0.4, s)))

  var successes = 0
  for i, dir in iter_range(dirs), dirs
    if rayhit_normalized(pos, dir, check_length, ETF_DEFAULT, -1)
      successes++
    if successes > int(float(length(dirs)) * successes_required) || successes + length(dirs) - i < int(float(length(dirs)) * successes_required)
      break
  return successes > int(float(length(dirs)) * successes_required)


[beh_node(name="teleportNestingSwarmNest")]
class TeleportNestingSwarmNest : BehNodeAdapter

  def override update(dt : float) : EBehResult
    let ownerEid = beh_tree_eid(owner)
    var result = EBehResult.ER_FAILED
    query(ownerEid) <| $ [es] (swarm_warrior__nests : EidList;
                               swarm_warrior__teleportationSeclusionSuccessesRequired : float;
                               swarm_warrior__teleportationSeclusioncheckLength : float;
                               swarm_warrior__teleportationRadius : float;
                               swarm_warrior__teleportationElevation : float;
                               swarm_warrior__teleportationTemplate : string;
                               swarm_warrior__teleportationHolderTemplate : string;
                               swarm_warrior__teleportationFailuresMax : int;
                               var swarm_warrior__teleportDesire : float&;
                               var swarm_warrior__teleportationFailuresCount : int&)
      if length(swarm_warrior__nests) == 0
        return //shouldn't ever happen
      if swarm_warrior__teleportationFailuresCount > swarm_warrior__teleportationFailuresMax
        return //This spot is bad, it's pointless to try to find teleportations spots, don't waste resources
      let randNestIdx = grnd() % length(swarm_warrior__nests)
      query(swarm_warrior__nests[randNestIdx]) <| $ [es] (transform : float3x4)
        var resPos : float3
        if find_random_point_inside_circle(transform[3], swarm_warrior__teleportationRadius, swarm_warrior__teleportationRadius * 0.5, resPos)
          resPos.y += swarm_warrior__teleportationElevation
          if is_location_secluded(resPos, swarm_warrior__teleportationSeclusionSuccessesRequired, swarm_warrior__teleportationSeclusioncheckLength)
            let holderEid = createEntity(swarm_warrior__teleportationHolderTemplate) <| $(initl)
              var tm = IDENT_TM
              tm[3] = resPos
              initl |> set("nesting_swarm_place_holder__nestEid", swarm_warrior__nests[randNestIdx])
              initl |> set("transform", tm)
            addSubTemplate(swarm_warrior__nests[randNestIdx], swarm_warrior__teleportationTemplate) <| $(initl)
              initl |> set("nesting_swarm_teleportation__holderEid", holderEid)
            swarm_warrior__teleportDesire = 0.0
            swarm_warrior__teleportationFailuresCount = 0
            result = EBehResult.ER_SUCCESS
          else
            swarm_warrior__teleportationFailuresCount++
            if swarm_warrior__teleportationFailuresCount > swarm_warrior__teleportationFailuresMax
              logerr_once("Nesting swarm at {transform[3]} can't find places to teleport to")

    return result


[beh_node(name="polenStormAttack")]
class PolenStormAttack : BehNodeAdapter

  def override init() : void
    let ownerEid = beh_tree_eid(owner)
    query(ownerEid) <| $ [es] (polen_storm__duration : float2;
                               var polen_storm__registry : IPoint3List;
                               var polen_storm__endsAt : float&)
      polen_storm__endsAt = get_sync_time() + rnd_float(polen_storm__duration)
      clear(polen_storm__registry)

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    let ownerEid = beh_tree_eid(owner)
    query(ownerEid) <| $ [es] (polen_storm__cloudTemplate : string;
                               walker_agent__targetEid : EntityId;
                               polen_storm__endsAt : float;
                               polen_storm__expansionStages : int;
                               polen_storm__duration : float2;
                               transform : float3x4;
                               var polen_storm__focus : float3&;
                               var polen_storm__registry : IPoint3List;
                               var polen_storm__tm : float3x4)
      result = EBehResult.ER_RUNNING
      if polen_storm__endsAt < get_sync_time()
        clear(polen_storm__registry)
        result = EBehResult.ER_SUCCESS

      if length(polen_storm__registry) == 0
        polen_storm__registry |> push(int3(0))
        query(walker_agent__targetEid) <| $ [es] (ai_target : Target)
          let dir = normalize(ai_target.targetPos - transform[3])
          let lookQuat = dir_to_quat(dir)
          make_tm(lookQuat, transform[3], polen_storm__tm)
          polen_storm__focus = ai_target.targetPos
          createEntity(polen_storm__cloudTemplate) <| $(initializer)
            initializer |> set("polen_cloud__ownerEid", ownerEid)
            initializer |> set("transform", transform)
            initializer |> set("polen_cloud__expansionStagesLeft", polen_storm__expansionStages)
            initializer |> set("game_effect__destroyAt", get_sync_time() + rnd_float(polen_storm__duration))

    return result


[beh_node(name="resupplySwarmWarrior")]
class ResupplySwarmWarrior : BehNodeAdapter

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    let ownerEid = beh_tree_eid(owner)
    query(ownerEid) <| $ [es] (swarm_supply__targetEid : EntityId;
                               swarm_supply__amount : int;
                               swarm_supply__nestEid : EntityId)
      query(swarm_supply__targetEid) <| $ [es] (swarm_warrior__startingBoidsCount : int; var swarm_cluster__serverCount : int&)
        swarm_cluster__serverCount = min(swarm_warrior__startingBoidsCount, swarm_cluster__serverCount + swarm_supply__amount)
      query(swarm_supply__nestEid) <| $ [es] (var nesting_swarm_nest__supplyEids : EidList)
        let idx = find_index(nesting_swarm_nest__supplyEids, ownerEid)
        if idx != -1
          nesting_swarm_nest__supplyEids |> erase(idx)
      destroyEntity(ownerEid)
      result = EBehResult.ER_SUCCESS
    return result

[beh_node(name="dementorStrideTo")]
class DementorStrideTo : BehNodeAdapter
  pos : string
  @hidden posHash : uint
  target : string
  @hidden targetHash : uint
  acceptableDistance : float

  timeRunning : float
  newStrideAt : float
  strideDir : float3
  currentDir : float3
  targetPos : float3
  targetEid : EntityId

  def override loadFromBlk(var data : DataBlock) : void
    pos = datablock_getStr(data, "pos", "")
    posHash = ecs_hash(pos)
    target = datablock_getStr(data, "target", "")
    targetHash = ecs_hash(target)
    let distanceName = datablock_getStr(data, "distance", "default")
    acceptableDistance = get_float(beh_tree_eid(owner), distanceName, ecs_hash(distanceName)) ?? 1.0

  def override init()
    timeRunning = 0.0
    newStrideAt = 0.0
    query(beh_tree_eid(owner)) <| $ [es] (transform : float3x4)
      currentDir = transform[0]
      if !empty(pos)
        targetPos = get_Point3(beh_tree_eid(owner), pos, posHash) ?? float3()
      if !empty(target)
        targetEid = get_Eid(beh_tree_eid(owner), target, targetHash) ?? INVALID_ENTITY_ID

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (flyer__collisionSpeedMulti : float;
                                          flyer__directionViscosity : float;
                                          flyer__speed : float;
                                          var transform : float3x4;
                                          var flyer__wishLookDir : float3&;
                                          var flyer__velocityDir : float3&)
      result = EBehResult.ER_RUNNING
      let meToTarget = self->getTargetPosition() - transform[3]
      let dst = length(meToTarget)
      if dst <= acceptableDistance
        result = EBehResult.ER_SUCCESS
        return

      let modifiedDt = flyer__collisionSpeedMulti * dt
      timeRunning += modifiedDt
      if newStrideAt <= timeRunning
        self->setNextStride(transform[3], meToTarget, dst)

      currentDir = normalize(approach(currentDir, strideDir, modifiedDt, flyer__directionViscosity))
      transform[3] += currentDir * flyer__speed * modifiedDt
      flyer__wishLookDir = meToTarget / dst
      flyer__velocityDir = currentDir
    return result

  def getTargetPosition() : float3
    var result : float3
    var success = false
    if targetEid != INVALID_ENTITY_ID
      query(targetEid) <| $ [es] (transform : float3x4; ai_target : Target const?)
        result = ai_target != null ? ai_target.targetPos : transform[3]
        success = true
      if !success
        //This can happen if the target is removed from the world before its death or earlier than regularCheck time after its death
        logwarn("eid:{beh_tree_eid(owner)} Invalid target in the dementorStrideTo node: {targetEid}({getEntityTemplateName(targetEid)})")
    if !success
      result = targetPos

    query(beh_tree_eid(owner)) <| $ [es] (flyer__preferredHeight : float)
      if flyer__preferredHeight > 0.0
        let posXZ = result.xz
        let minHeight = traceht_lmesh(posXZ) + flyer__preferredHeight
        if minHeight > result.y
          result.y = minHeight

    return result

  def setNextStride(myPos, meToTarget : float3; distance_to_target : float)
    query(beh_tree_eid(owner)) <| $ [es] (stride__lengthAt100, stride__lengthAt0 : float2;
                                          stride__focus, stride__worstDot, flyer__speed, flyer__preferredHeight : float)
      let strideLengthFrom = lerp(stride__lengthAt0.x, stride__lengthAt100.x, distance_to_target / 100.0)
      let strideLengthTo = lerp(stride__lengthAt0.y, stride__lengthAt100.y, distance_to_target / 100.0)
      var strideLength = rnd_float(strideLengthFrom, strideLengthTo)
      var rndDir = normalize(float3(gfrnd() - 0.5, gfrnd() - 0.5, gfrnd() - 0.5))
      let targetDir = normalize(meToTarget)
      if dot(targetDir, rndDir) < stride__worstDot
        rndDir *= -1.0
      strideDir = targetDir * stride__focus + rndDir * (1.0 - stride__focus)
      var strideEndpoint = myPos + strideDir * strideLength
      let posXZ = strideEndpoint.xz
      let minHeight = traceht_lmesh(posXZ) + flyer__preferredHeight
      if minHeight > strideEndpoint.y
        strideEndpoint.y = minHeight + gfrnd() * strideLength * 0.5
      let newStride = strideEndpoint - myPos
      strideLength = length(newStride)
      if strideLength > 0.0
        strideDir = newStride / strideLength
        newStrideAt = timeRunning + strideLength / flyer__speed

  def override drawDebug(children : bool)
    query(beh_tree_eid(owner)) <| $ [es] (transform : float3x4)
      draw_debug_line_buffered(transform[3], self->getTargetPosition(), E3DCOLOR(0xFFFFFF00), 1)


[beh_node(name="setLookDirFromSpawnSequence")]
class SetLookDirFromSpawnSequence : BehNodeAdapter

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (spawn_sequence__dir : float3; var human_net_phys : HumanActor)
      result = EBehResult.ER_SUCCESS
      human_net_phys.phys.producedCT |> human_control_state_set_wish_look_dir(spawn_sequence__dir)
      human_net_phys.phys.producedCT |> human_control_state_set_wish_shoot_dir(spawn_sequence__dir)
    return result


[beh_node(name="findSafePos")]
class FindSafePos : BehNodeAdapter
  posParam : string
  @hidden posParamHash : uint
  enemyParam : string
  @hidden enemyParamHash : uint
  defaultPosParam : string
  @hidden defaultPosParamHash : uint

  checkRadius : float = 5.f
  numRays : int = 10
  checkOffset : float3 = float3(0.f, 1.5f, 0.f)
  overwrite : bool = false

  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("posParam", posParam, posParamHash)
    data |> load_ecs_param("enemyParam", enemyParam, enemyParamHash)
    data |> load_ecs_param("defaultPosParam", defaultPosParam, defaultPosParamHash)
    checkRadius = data |> datablock_getReal("radius", checkRadius)
    numRays = data |> datablock_getInt("numRays", numRays)
    checkOffset = data |> datablock_getPoint3("checkOffset", checkOffset)
    overwrite = data |> datablock_getBool("overwrite", overwrite)

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED

    let eid = beh_tree_eid(owner)
    let enemyParamRef = eid |> get_Eid(enemyParam, enemyParamHash)

    query(eid) <| $ [es] (transform : float3x4;
                          agent_obstacles : AgentObstacles)
      let currentPos = transform[3]

      let defaultPosRef = eid |> get_Point3(defaultPosParam, defaultPosParamHash)
      var safePos = defaultPosParam != "" ? *defaultPosRef : currentPos

      if enemyParamRef != null && doesEntityExist(*enemyParamRef)
        query(*enemyParamRef) <| $ [es] (human__aimTm : float3x4;
                                         isAlive : bool = true)
          if !isAlive
            res = EBehResult.ER_SUCCESS
            return

          let shootPos = human__aimTm[3]
          var dir : float3
          var t : float
          var norm : float3

          //check default
          if (distance_sq(shootPos, safePos) > FLT_EPSILON &&
              distance_sq(currentPos, safePos) > FLT_EPSILON && !overwrite)
            dir = safePos + checkOffset - shootPos
            t = length(dir)
            dir /= t
            if traceray_normalized(shootPos, dir, t, norm, ETF_DEFAULT)
              res = EBehResult.ER_SUCCESS
              return
          // find other pos
          var farPos = shootPos
          for _ in range(numRays)
            find_random_point_inside_circle(currentPos, checkRadius, 1.0, safePos)
            var inObstacle = false
            for obstacle in agent_obstacles.obstacles
              inObstacle ||= test_is_inside_obstacle(safePos, obstacle)
            if inObstacle
              continue
            if (distance_sq(shootPos, safePos) > FLT_EPSILON &&
                distance_sq(currentPos, safePos) > FLT_EPSILON)
              dir = safePos + checkOffset - shootPos
              t = length(dir)
              dir /= t
              if traceray_normalized(shootPos, dir, t, norm, ETF_DEFAULT)
                res = EBehResult.ER_SUCCESS
                return
              elif distance_sq(shootPos, safePos) > distance_sq(shootPos, farPos)
                farPos = safePos
          if distance_sq(shootPos, farPos) > FLT_EPSILON
            safePos = farPos
          else
            safePos = currentPos
      else
        res = EBehResult.ER_SUCCESS

      if !has(eid, posParam, posParamHash)
        logerr_once("{eid}: entity without output param '{posParam}:{posParamHash}' / {*thisNode |> beh_node_hierarchy_name(true)}")
      setOptional(eid, posParam, posParamHash, safePos)
    return res


[beh_node(name="findPlayer")]
class FindPlayer : BehNodeAdapter
  findHuman : bool = true
  findAi : bool = true

  def override loadFromBlk(var data : DataBlock)
    findHuman = data |> datablock_getBool("findHuman", findHuman)
    findAi = data |> datablock_getBool("findAi", findAi)

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    let ownerEid = beh_tree_eid(owner)
    query(ownerEid) <| $ [es] (transform : float3x4;
                               find_player__radius : float;
                               find_player__ignoreEids : EidList;
                               var find_player__resultEid : EntityId&)
      let sphere = BSphere3(transform[3], find_player__radius)
      find_player__resultEid = find_entity_in_grid(ecs_hash("humans"), sphere, GridEntCheck.BOUNDING) <| $ [unused_argument(targetPos)] (targetEid : EntityId; targetPos : float3)
        if has_value(find_player__ignoreEids, targetEid)
          return false
        var querySuccessful = false
        query(targetEid) <| $ [es(REQUIRE=heroForPlayer)] (am_militant_bot : Tag const?)
          querySuccessful = (am_militant_bot != null && findAi) || (am_militant_bot == null && findHuman)
        return querySuccessful
      if find_player__resultEid != INVALID_ENTITY_ID
        res = EBehResult.ER_SUCCESS
    return res


[beh_node(name="tryBotherHumanPlayer")]
class TryVisitHumanPlayer : BehNodeAdapter
  targetParam : string
  @hidden targetParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("targetParam", targetParam, targetParamHash)

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    let ownerEid = beh_tree_eid(owner)
    query(ownerEid) <| $ [es] (transform : float3x4;
                               find_player__radius : float;
                               find_player__ignoreEids : EidList)
      let sphere = BSphere3(transform[3], find_player__radius)
      let curTime = get_sync_time()
      let militantEid = find_entity_in_grid(ecs_hash("humans"), sphere, GridEntCheck.BOUNDING) <| $ [unused_argument(targetPos)] (targetEid : EntityId; targetPos : float3)
        if has_value(find_player__ignoreEids, targetEid)
          return false
        var querySuccessful = false
        query(targetEid) <| $ [es(REQUIRE_NOT=am_militant_bot)] (find_player_target__cooldown : float; var find_player_target__lastSuccessAt : float&)
          if curTime - find_player_target__lastSuccessAt > find_player_target__cooldown
            find_player_target__lastSuccessAt = curTime
            querySuccessful = true
        return querySuccessful
      var eidRef = beh_tree_eid(owner) |> getRW_Eid(targetParam, targetParamHash)
      if eidRef != null && militantEid != INVALID_ENTITY_ID
        *eidRef = militantEid
        res = EBehResult.ER_SUCCESS
    return res


[beh_node(name="stormZoneExists")]
class StormZoneExists : BehNodeAdapter

  def override update(dt : float) : EBehResult
    let res = find_query() <| $ [es(REQUIRE=moving_zone__sourcePos)] ()
      return true
    return res ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="hasMeleeWeaponEquipped")]
class HasMeleeWeaponEquipped : BehNodeAdapter
  targetParam : string
  @hidden targetParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("targetParam", targetParam, targetParamHash)

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED

    let eid = beh_tree_eid(owner)
    let targetRef = eid |> get_Eid(targetParam, targetParamHash)
    if targetRef != null
      query(*targetRef) <| $ [es] (human_net_phys : HumanActor)
        if human_net_phys.phys.currentState.weapEquipState.curSlot == HUWeaponSlots.EWS_MELEE
          res = EBehResult.ER_SUCCESS
    return res


[beh_node(name="updateFlashlightState")]
class UpdateFlashlightState : BehNodeAdapter
  ambientLightToEnable : float = 0.3
  ambientLightToEnableIndoor : float = 0.86
  chanceToEnableIndoor : float = 0.35

  def override loadFromBlk(var data : DataBlock)
    ambientLightToEnable = data |> datablock_getReal("ambientLightToEnable", ambientLightToEnable)
    ambientLightToEnableIndoor = data |> datablock_getReal("ambientLightToEnableIndoor", ambientLightToEnableIndoor)
    chanceToEnableIndoor = data |> datablock_getReal("chanceToEnableIndoor", chanceToEnableIndoor)

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)

    query(agentEid) <| $ [es] (attaches_list : EidList;
                               human_weap__currentGunEid : EntityId;
                               transform aka agent_transform : float3x4;
                               ai_target_visibility_controller__currentLightByDayTime = 1.0)
      assume currentLightByDayTime = ai_target_visibility_controller__currentLightByDayTime

      let isDarkIndoor = is_pos_indoor(agent_transform[3]) && currentLightByDayTime <= ambientLightToEnableIndoor
      let isDarkAmbient = currentLightByDayTime <= ambientLightToEnable

      let r = find_flashlight(attaches_list, human_weap__currentGunEid) <| $ [es, unused_argument(flashlight_eid)] (flashlight_eid : EntityId;
                                                                                                                    var is_on : bool&)
        let flashlightIsRequired = isDarkAmbient || (isDarkIndoor && (is_on || gfrnd() < chanceToEnableIndoor))

        is_on = flashlightIsRequired
        return true

    return EBehResult.ER_SUCCESS


[beh_node(name="findNearestTransPortal")]
class FindNearestTransPortal : BehNodeAdapter
  targetParam : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    targetParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetParam", ""), 0)

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    var bestEid = INVALID_ENTITY_ID
    query(agentEid) <| $ [es] (transform aka agent_transform : float3x4)
      var bestDstSq = FLT_MAX
      query() <| $ [es(REQUIRE=trans_portal)] (transform aka portal_transform : float3x4; eid : EntityId)
        let dstSq = distance_sq(agent_transform[3], portal_transform[3])
        if dstSq < bestDstSq
          bestDstSq = dstSq
          bestEid = eid
    owner.blackBoard |> set(targetParam, int(uint(bestEid)))
    return bestEid != INVALID_ENTITY_ID ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="minionCreatureFindDanger")]
class MinionCreatureFindDanger : BehNodeAdapter
  targetParam : int
  radiusParam : int
  idleCheck : bool = false

  def override loadFromBlk(var data : DataBlock)
    targetParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "paramName", "enemy"), int(uint(INVALID_ENTITY_ID)))
    radiusParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "radiusParamName", "enemyRadius"), 25.0)

    idleCheck = data |> datablock_getBool("idleCheck", idleCheck)

  def override update(dt : float) : EBehResult

    let ownerEid = beh_tree_eid(owner)
    let radius = owner.blackBoard |> datablock_getReal(radiusParam)

    let curTime = get_sync_time()

    sendEventImmediate(ownerEid, CmdTraceAgentDangers(forceRetrace = true))

    var bestTarget = INVALID_ENTITY_ID
    var bestTargetScore = 0.0
    query(ownerEid) <| $ [es] (agent_dangers : AgentDangers;
                               minion_creature__masterEid aka current_minion_creature__masterEid : EntityId;
                               walker_agent__targetEid aka current_walker_agent__targetEid : EntityId;
                               minion_creature_alternate_targets__attackTargetTime : float const?;
                               minion_creature_alternate_targets__ignoreTargetTime : float const?;
                               minion_creature_alternate_targets__maxAttackersPerTarget : int const?;
                               var minion_creature_alternate_targets__ignoreLastTargetFromTo : float2?;
                               var minion_creature__lastDangerEid : EntityId&)
      assume attackTargetTime = minion_creature_alternate_targets__attackTargetTime
      assume ignoreTargetTime = minion_creature_alternate_targets__ignoreTargetTime
      assume ignoreLastTargetFromTo = minion_creature_alternate_targets__ignoreLastTargetFromTo
      assume maxAttackersPerTarget = minion_creature_alternate_targets__maxAttackersPerTarget

      var minionsPerTarget : table<uint; int>
      query() <| $ [es] (eid aka other_minion_eid : EntityId;
                         minion_creature__masterEid aka other_minion_creature__masterEid : EntityId;
                         walker_agent__targetEid aka other_walker_agent__targetEid : EntityId)
        if other_minion_eid == ownerEid
          return

        if other_minion_creature__masterEid == current_minion_creature__masterEid
          minionsPerTarget[uint(other_walker_agent__targetEid)]++

      var lastDangerIsDangerous = false

      for danger in agent_dangers.dangers

        var isGoodTarget = true

        var dangerMeter = danger.dangerMeter

        // Enemy with attack mark
        let enemyAttackMarkPriority = get_minion_danger_attack_mark_priority(current_minion_creature__masterEid,
                                                                             danger.eid)
        if enemyAttackMarkPriority > 0
          dangerMeter += float(enemyAttackMarkPriority) * 100.0

        if radius > 0.0 && danger.distance > radius && enemyAttackMarkPriority == 0
          continue

        if danger.eid == minion_creature__lastDangerEid
          lastDangerIsDangerous = true

        let minionsOnThisTarget = minionsPerTarget.get_value(uint(danger.eid))

        if maxAttackersPerTarget != null
          if minionsOnThisTarget >= *maxAttackersPerTarget
            continue
          elif minionsOnThisTarget > 1 && enemyAttackMarkPriority == 0
            dangerMeter *= 0.25
            isGoodTarget = false


        if danger.eid == minion_creature__lastDangerEid
          if ignoreLastTargetFromTo != null
            if (*ignoreLastTargetFromTo).x <= curTime && curTime <= (*ignoreLastTargetFromTo).y

              let cannotIgnoreThisTarget = enemyAttackMarkPriority > 0 && minionsOnThisTarget <= 1
              if !cannotIgnoreThisTarget
                continue


        if isGoodTarget
          if current_walker_agent__targetEid == danger.eid || minion_creature__lastDangerEid == danger.eid
            if bestTargetScore <= 1.0
              bestTarget = danger.eid
              bestTargetScore = dangerMeter
              continue

        if dangerMeter > 0.0 && dangerMeter > bestTargetScore
          bestTargetScore = dangerMeter
          bestTarget = danger.eid


      if !idleCheck
        if bestTarget != INVALID_ENTITY_ID
          minion_creature__lastDangerEid = bestTarget

          if ignoreLastTargetFromTo != null && attackTargetTime != null && ignoreTargetTime != null
            *ignoreLastTargetFromTo = float2(curTime + *attackTargetTime, curTime + *attackTargetTime + *ignoreTargetTime)
        elif !lastDangerIsDangerous
          minion_creature__lastDangerEid = INVALID_ENTITY_ID

    owner.blackBoard |> set(targetParam, int(uint(bestTarget)))

    return bestTarget != INVALID_ENTITY_ID ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="minionCreatureIsWalkMarkExists")]
class MinionCreatureIsWalkMarkExists : BehNodeAdapter
  def override update(dt : float) : EBehResult
    let ownerEid = beh_tree_eid(owner)
    return is_minion_walk_mark_exists(ownerEid) ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="minionCreatureFindStandPos")]
class MinionCreatureFindStandPos : BehNodeAdapter
  posParam : string
  @hidden posParamHash : uint
  walkMarksOnly : bool = false

  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("posParam", posParam, posParamHash, thisNode)

  def override update(dt : float) : EBehResult
    let ownerEid = beh_tree_eid(owner)

    let pos = find_minion_stand_pos(ownerEid)
    if pos == float3()
      return EBehResult.ER_FAILED

    setOptional(ownerEid, posParam, posParamHash, pos)
    return EBehResult.ER_SUCCESS


[beh_node(name="mimicStartCrawl")]
class MimicStartCrawl : BehNodeAdapter
  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    let ownerEid = beh_tree_eid(owner)
    query(ownerEid) <| $ [es] (am_mimic__crawlTempl : string; transform : float3x4; navmesh_phys__maxWalkSpeed : float)
      addSubTemplate(ownerEid, am_mimic__crawlTempl) <| $(var initialize)
        initialize |> set("position", transform[3])
        initialize |> set("surface_crawler__seed", grnd())
        initialize |> set("surface_crawler__speed", navmesh_phys__maxWalkSpeed)
        initialize |> set("surface_crawler__dir", transform[0])
        initialize |> set("surface_crawler__norm", transform[1])
        initialize |> set("surface_crawler__head", transform[3])
        initialize |> set("surface_crawler__active", true)
      res = EBehResult.ER_SUCCESS
    return res


[beh_node(name="amMimicAttack")]
class AmMimicAttack : BehNodeAdapter
  targetParam : string
  @hidden targetParamHash : uint

  def override init()
    let ownerEid = beh_tree_eid(owner)
    query(ownerEid) <| $ [es] (var am_mimic_attack__instances : EidList)
      for e in am_mimic_attack__instances
        destroyEntity(e)
      clear(am_mimic_attack__instances)

  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("target", targetParam, targetParamHash, thisNode)

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    let ownerEid = beh_tree_eid(owner)
    query(ownerEid) <| $ [es] (transform aka s_transform : float3x4;
                               am_mimic_attack__chargeDuration : float;
                               am_mimic_attack__totalDuration : float;
                               am_mimic_attack__aimDuration : float;
                               am_mimic_attack__damage : float;
                               am_mimic_attack__riDamage : float;
                               am_mimic_attack__pushStrength : float;
                               am_mimic_attack__reach : float;
                               team aka s_team : int;
                               am_mimic_attack__template : string;
                               am_mimic_attack__count : int2;
                               am_mimic_attack__gap : float2;
                               var am_mimic_attack__instances : EidList;
                               var am_mimic_attack__lastTime : float&)
      let targetRef = ownerEid |> get_Eid(targetParam, targetParamHash)
      if targetRef != null
        query(*targetRef) <| $ [es] (transform aka t_transform : float3x4;
                                     ai_target : Target const?;
                                     ri_extra : RiExtraComponent const?)
          var allDone = true
          let time = get_sync_time()
          if length(am_mimic_attack__instances) == 0
            allDone = false
            let count = rnd_int(am_mimic_attack__count)
            var startTime = time
            let targetPos = get_am_mimic_target_pos(ri_extra, ai_target, t_transform)
            let dir = normalize(targetPos - s_transform[3])
            for _ in range(count)
              startTime += rnd_float(am_mimic_attack__gap)
              let attackEid = createEntity(am_mimic_attack__template) <| $(var initi)
                initi |> set("am_mimic_attack__dir", dir)
                initi |> set("am_mimic_attack__stamp", startTime)
                initi |> set("am_mimic_attack__aimAt", startTime + am_mimic_attack__aimDuration)
                initi |> set("am_mimic_attack__at", startTime + am_mimic_attack__chargeDuration)
                initi |> set("am_mimic_attack__endAt", startTime + am_mimic_attack__totalDuration)
                initi |> set("am_mimic_attack__am_mimicEid", ownerEid)
              am_mimic_attack__instances |> push(attackEid)
          else
            for aie in am_mimic_attack__instances
              query(aie) <| $ [es] (am_mimic_attack__aimAt, am_mimic_attack__at, am_mimic_attack__endAt : float; var am_mimic_attack__dir : float3&)
                if am_mimic_attack__lastTime < am_mimic_attack__aimAt
                  if am_mimic_attack__aimAt < time
                    let targetPos = get_am_mimic_target_pos(ri_extra, ai_target, t_transform)
                    let legs2Head = targetPos - t_transform[3]
                    let rndDeviation = float3(gfrnd(), .0, gfrnd()) * 0.4
                    let vertDeviation = legs2Head * (1.0 + gfrnd()) * 0.5
                    am_mimic_attack__dir = normalize(t_transform[3] - s_transform[3] + rndDeviation + vertDeviation)
                elif am_mimic_attack__lastTime < am_mimic_attack__at
                  if am_mimic_attack__at < time
                    var success = false
                    var t = am_mimic_attack__reach
                    //draw_debug_arrow_buffered(s_transform[3], s_transform[3] + am_mimic_attack__dir * t, ACINDI, 500)
                    trace_entities_in_grid(ecs_hash("humans"), s_transform[3], am_mimic_attack__dir, t, ownerEid, SortIntersections.NO) <| $(intersections : array<IntersectedEntity>#)
                      for intr in intersections
                        query(intr.eid) <| $ [es] (team aka t_team : int)
                          if t_team != s_team // No firendlies for this one. Just don't damage other am_mimics
                            success = true
                            let dmDesc = DamageDesc(DamageType.DM_MELEE, am_mimic_attack__damage, s_transform[3])
                            apply_damage(intr.eid, ownerEid, dmDesc)
                            sendEvent(intr.eid, CmdPushPhys(vel = am_mimic_attack__dir * am_mimic_attack__pushStrength, push_immunity = 0.0))
                            send_net_event(ownerEid, EventMimicAttack(pos = intr.pos, success = true))
                        if success
                          break
                    if !success
                      t = am_mimic_attack__reach
                      var norm : float3
                      var pmid = -1
                      var riDesc = RendInstDesc()
                      traceray_normalized(s_transform[3], am_mimic_attack__dir, t, pmid, norm, ETF_ALL, riDesc, -1)
                      if riDesc.isValid
                        damage_ri_on_server(riDesc.riExtraHandle, am_mimic_attack__riDamage, s_transform[3], am_mimic_attack__dir, get_sync_time(), ownerEid)
                      send_net_event(ownerEid, EventMimicAttack(pos = s_transform[3] + am_mimic_attack__dir * t, success = riDesc.isValid))
                if am_mimic_attack__endAt > time
                  allDone = false
          am_mimic_attack__lastTime = time
          res = allDone ? EBehResult.ER_SUCCESS : EBehResult.ER_RUNNING
    return res

def get_am_mimic_target_pos(ri_extra : RiExtraComponent const?; ai_target : Target const?; transform : float3x4)
  if ri_extra != null
    let riType = handle_to_ri_type(ri_extra.handle)
    let riCollres = get_ri_gen_extra_collres(int(riType))
    if riCollres == null
      return transform[3]
    else
      var box = BBox3()
      box |> bbox3f_to_scalar_bbox3(riCollres.vFullBBox)
      return transform * box.center
  else
    return ai_target != null ? ai_target.targetPos : transform[3]


[beh_node(name="setIrraticWalkSpeed")]
class SetIrraticWalkSpeed : BehNodeAdapter

  def override init()
    let ownerEid = beh_tree_eid(owner)
    query(ownerEid) <| $ [es] (var irratic_walk__speedSave : float&;
                               var irratic_walk__sprintUntil : float&;
                               var irratic_walk__blockUntil : float&;
                               var navmesh_phys__maxWalkSpeed : float&;
                               irratic_walk__speedRange : float2;
                               irratic_walk__blockDuration : float2;
                               irratic_walk__sprintDuration : float2)
      let time = get_sync_time()
      irratic_walk__speedSave = navmesh_phys__maxWalkSpeed
      if irratic_walk__blockUntil > time
        return
      irratic_walk__sprintUntil = time + rnd_float(irratic_walk__sprintDuration)
      irratic_walk__blockUntil = irratic_walk__sprintUntil + rnd_float(irratic_walk__blockDuration)
      navmesh_phys__maxWalkSpeed = rnd_float(irratic_walk__speedRange)

  def override exit()
    let ownerEid = beh_tree_eid(owner)
    query(ownerEid) <| $ [es] (irratic_walk__speedSave : float; var navmesh_phys__maxWalkSpeed : float&)
      navmesh_phys__maxWalkSpeed = irratic_walk__speedSave


  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    let ownerEid = beh_tree_eid(owner)
    query(ownerEid) <| $ [es] (irratic_walk__sprintUntil : float)
      let time = get_sync_time()
      if irratic_walk__sprintUntil < time
        res = EBehResult.ER_SUCCESS
      else
        res = EBehResult.ER_RUNNING
    return res
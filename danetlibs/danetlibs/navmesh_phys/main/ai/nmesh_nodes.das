options always_export_initializer = true

require ecs
require DagorSystem
require BehNodes
require DagorDataBlock
require pathfinder
require math.base
require DagorMath
require DagorMathUtils
require DagorRandom
require debug.logerr_once
require strings


[beh_node(name="nMeshFindRandomPoint")]
class NMeshFindRandomPoint : BehNodeAdapter
  posParam : string
  @hidden posParamHash : uint
  dist : float2 = float2(1f)

  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("posParam", posParam, posParamHash, thisNode)
    dist = data |> datablock_getPoint2("dist", dist)

  def getAroundPos(eid : EntityId) : float3
    var res : float3
    let found = query(eid) <| $ [es] (transform : float3x4)
      res = transform[3]
    if !found
      logerr_once("{eid}: NMeshFindRandomPoint can't find entity transform {*thisNode |> beh_node_hierarchy_name(true)}")
      return float3()
    return res

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    let eid = beh_tree_eid(owner)
    var resPos : float3
    let aroundPos = self->getAroundPos(eid)
    if find_random_point_inside_circle(aroundPos, rnd_float(dist.x, dist.y), 1., resPos)
      res = EBehResult.ER_SUCCESS
      if !eid |> has(posParam, posParamHash)
        logerr_once("{eid}: entity without output param '{posParam}:{posParamHash}' / {*thisNode |> beh_node_hierarchy_name(true)}")
      setOptional(eid, posParam, posParamHash, resPos)
    return res


[beh_node(name="nMeshFindRandomPointAroundPos")]
class NMeshFindRandomPointAroundPos : NMeshFindRandomPoint
  aroundPos : string
  @hidden aroundPosHash : uint

  def override loadFromBlk(var data : DataBlock)
    NMeshFindRandomPoint`loadFromBlk(self, data)
    data |> load_ecs_param("aroundPos", aroundPos, aroundPosHash, thisNode)

  def override getAroundPos(eid : EntityId) : float3
    let aroundPosRef = eid |> get_Point3(aroundPos, aroundPosHash)
    if aroundPosRef == null
      logerr_once("{eid}: nMeshFindRandomPointAroundPos can't find aroundPos '{aroundPos}:{aroundPosHash}' {*thisNode |> beh_node_hierarchy_name(true)}")
      return float3()
    return *aroundPosRef


[beh_node(name="nMeshFindRandomPointAroundTarget")]
class NMeshFindRandomPointAroundTarget : NMeshFindRandomPoint
  targetParam : string
  @hidden targetParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    NMeshFindRandomPoint`loadFromBlk(self, data)
    data |> load_ecs_param("targetParam", targetParam, targetParamHash, thisNode)

  def override getAroundPos(eid : EntityId) : float3
    let targetParamRef = eid |> get_Eid(targetParam, targetParamHash)
    var res = float3()
    if targetParamRef == null
      logerr_once("{eid}: nMeshFindRandomPointAroundTarget can't to find target '{targetParam}:{targetParamHash}' {*thisNode |> beh_node_hierarchy_name(true)}")
      return res
    query(*targetParamRef) <| $ [es] (transform : float3x4)
      res = transform[3]
    return res


[beh_node(name="nMeshFindPointNearTarget")]
class NMeshFindPointNearTarget : BehNodeAdapter
  posParam : string
  @hidden posParamHash : uint
  targetParam : string
  @hidden targetParamHash : uint
  dist : float2 = float2(1f)
  @hidden distSq : float2 = float2(1f)
  tries : int = 5
  angleRangeSpread : float2 = float2(-0.25 * PI, 0.25 * PI)
  oppositePoint : bool = false
  reusePrevPos : bool = false
  tracerayNavmesh : bool = false
  checkPath : bool = true
  extents : float3 = float3(1)

  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("posParam", posParam, posParamHash, thisNode)
    data |> load_optional_ecs_param("targetParam", targetParam, targetParamHash)
    dist = data |> datablock_getPoint2("dist", dist)
    distSq = float2(square(dist.x), square(dist.y))
    tries = data |> datablock_getInt("tries", tries)
    extents = data |> datablock_getPoint3("extents", extents)
    oppositePoint = data |> datablock_getBool("oppositePoint", oppositePoint)
    reusePrevPos = data |> datablock_getBool("reusePrevPos", reusePrevPos)
    tracerayNavmesh = data |> datablock_getBool("tracerayNavmesh", tracerayNavmesh)
    checkPath = data |> datablock_getBool("checkPath", checkPath)
    angleRangeSpread = data |> datablock_getPoint2("angleRangeSpread", float2(rad_to_deg(angleRangeSpread.x), rad_to_deg(angleRangeSpread.y)))
    angleRangeSpread = float2(deg_to_rad(angleRangeSpread.x), deg_to_rad(angleRangeSpread.y))

  def getTarget(eid : EntityId; from_pos : float3; var pos : float3&; var spread_dir : float3&) : void
    let targetParamRef = eid |> get_Eid(targetParam, targetParamHash)
    if targetParamRef == null
      logerr_once("{eid}: nMeshFindPointNearTarget can't to find target '{targetParam}:{targetParamHash}' {*thisNode |> beh_node_hierarchy_name(true)}")
      return
    query(*targetParamRef) <| $ [es] (transform : float3x4)
      pos = transform[3]
    spread_dir = oppositePoint ? pos - from_pos : from_pos - pos

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    let eid = beh_tree_eid(owner)
    query(eid) <| $ [es] (transform : float3x4;
                          nphys_levitating__elevation = .0;
                          navmesh_phys__climbJumpMaxUpHeight : float const?;
                          navmesh_phys__upDir : float3 = float3(0, 1, 0))
      let fromPos = transform[3] - navmesh_phys__upDir * nphys_levitating__elevation
      var targetPos, dir : float3
      self->getTarget(eid, fromPos, targetPos, dir)
      let baseAngle = atan2(dir.z, dir.x)
      if reusePrevPos
        let prevPos = get_Point3(eid, posParam, posParamHash)
        if prevPos != null
          let distPrevPosSq = distance_sq(*prevPos, targetPos)
          if distPrevPosSq >= distSq.x && distPrevPosSq <= distSq.y
            let dirToTarget = *prevPos - targetPos
            let dirAngle = atan2(dirToTarget.z, dirToTarget.x)
            let angleDelta = angle_diff(dirAngle, baseAngle)
            if angleDelta >= angleRangeSpread.x && angleDelta <= angleRangeSpread.y
              res = EBehResult.ER_SUCCESS
              return
      for _ in range(tries)
        let randAngle = rnd_float(baseAngle + angleRangeSpread.x, baseAngle + angleRangeSpread.y)
        var sine, cosine : float
        sincos(randAngle, sine, cosine)
        var resPos = targetPos + float3(cosine, 0f, sine) * rnd_float(min(dist.x + extents.x, dist.y - extents.x), dist.y - extents.x)
        if !project_to_nearest_navmesh_point(resPos, extents)
          continue

        if tracerayNavmesh
          var hitPos = float3()
          if traceray_navmesh(targetPos, resPos, extents, hitPos)
            let hitDistSq = distance_sq(targetPos, hitPos)
            if hitDistSq < distSq.x || hitDistSq > distSq.y
              continue
            resPos = hitPos

        if checkPath
          var checkPathRes = false
          using(fromPos, resPos, extents) <| $(var req : FindRequest#)
            if navmesh_phys__climbJumpMaxUpHeight != null
              req.includeFlags |= int(PolyFlag.POLYFLAG_JUMP)
            req.maxJumpUpHeight = navmesh_phys__climbJumpMaxUpHeight ?? 0.f
            checkPathRes = check_path(req, extents.x, extents.x)

          if !checkPathRes
            continue
        res = EBehResult.ER_SUCCESS
        if !has(eid, posParam, posParamHash)
          logerr_once("{eid}: entity without output param '{posParam}:{posParamHash}' / {*thisNode |> beh_node_hierarchy_name(true)}")
        setOptional(eid, posParam, posParamHash, resPos)
        break
    return res

[beh_node(name="nMeshFindPointNearSelf")]
class nMeshFindPointNearSelf : NMeshFindPointNearTarget
  [unused_argument(from_pos)] def override getTarget(eid : EntityId; from_pos : float3; var pos : float3 &; var spread_dir : float3 &) : void
    query(eid) <| $ [es] (transform : float3x4)
      spread_dir = transform[0]
      pos = transform[3]

[beh_node(name="nMeshFindDirectionalPointNearTarget")]
class NMeshFindDirectionalPointNearTarget : NMeshFindPointNearTarget
  directionAngle : float = 0f
  direction : float3

  def override loadFromBlk(var data : DataBlock)
    NMeshFindPointNearTarget`loadFromBlk(self, data)
    directionAngle = data |> datablock_getReal("directionAngle", directionAngle)
    sincos(deg_to_rad(directionAngle), direction.z, direction.x)

  [unused_argument(from_pos)] def override getTarget(eid : EntityId; from_pos : float3; var pos : float3 &; var spread_dir : float3 &) : void
    let targetParamRef = eid |> get_Eid(targetParam, targetParamHash)
    if targetParamRef == null
      logerr_once("{eid}: NMeshFindDirectionalPointNearTarget can't to find target '{targetParam}:{targetParamHash}' {*thisNode |> beh_node_hierarchy_name(true)}")
      return
    query(*targetParamRef) <| $ [es] (transform : float3x4)
      pos = transform[3]
      spread_dir = transform |> rotate <| direction
      if oppositePoint
        spread_dir *= -1f


[beh_node(name="checkDistanceToPos")]
class CheckDistanceToPos : BehNodeAdapter
  posParam : string
  @hidden posParamHash : uint
  radiusParam : string
  @hidden radiusParamHash : uint
  radiusSq : float = 0f

  def override loadFromBlk(var data : DataBlock) : void
    data |> load_ecs_param("posParam", posParam, posParamHash, thisNode)
    data |> load_optional_ecs_param("radiusParam", radiusParam, radiusParamHash)
    radiusSq = data |> datablock_getReal("radius", 0f) |> square()

  def override init()
    if !empty(radiusParam)
      let eid = beh_tree_eid(owner)
      radiusSq = square(eid |> get_float(radiusParam, radiusParamHash) ?? 0f)

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    let eid = beh_tree_eid(owner)
    let targetPosRef = eid |> get_Point3(posParam, posParamHash)
    if targetPosRef == null
      logerr_once("{eid}: checkDistanceToPos can't to find target position '{posParam}:{posParamHash}' {*thisNode |> beh_node_hierarchy_name(true)}")
      return res
    query(eid) <| $ [es] (transform : float3x4)
      res = distance_sq(*targetPosRef, transform[3]) <= radiusSq ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED
    return res


[beh_node(name="checkDistanceToTarget")]
class CheckDistanceToTarget : BehNodeAdapter
  targetParam : string
  @hidden targetParamHash : uint
  radiusParam : string
  @hidden radiusParamHash : uint
  radiusSq : float = 0f

  def override loadFromBlk(var data : DataBlock) : void
    data |> load_ecs_param("targetParam", targetParam, targetParamHash, thisNode)
    data |> load_optional_ecs_param("radiusParam", radiusParam, radiusParamHash)
    radiusSq = data |> datablock_getReal("radius", 0f) |> square()

  def override init()
    if !empty(radiusParam)
      let eid = beh_tree_eid(owner)
      radiusSq = square(eid |> get_float(radiusParam, radiusParamHash) ?? 0f)

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    let eid = beh_tree_eid(owner)
    let targetParamRef = eid |> get_Eid(targetParam, targetParamHash)
    if targetParamRef == null
      logerr_once("{eid}: checkDistanceToTarget can't to find target '{targetParam}:{targetParamHash}' {*thisNode |> beh_node_hierarchy_name(true)}")
      return res
    query(*targetParamRef) <| $ [es] (transform : float3x4)
      let targetPos = transform[3]
      query(eid) <| $ [es] (transform : float3x4)
        res = distance_sq(targetPos, transform[3]) <= radiusSq ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED
    return res


class AbstractNMeshTraceray : BehNodeAdapter
  outPosParam : string
  @hidden outPosParamHash : uint
  extents = float3(1)

  def override loadFromBlk(var data : DataBlock) : void
    data |> load_ecs_param("outPosParam", outPosParam, outPosParamHash)

  def getFromPos(eid : EntityId) : float3
    var pos = float3(FLT_MAX, FLT_MAX, FLT_MAX)
    query(eid) <| $ [es] (transform : float3x4)
      pos = transform[3]
    return pos

  [unused_argument(eid)] def getToPos(eid : EntityId) : float3
    return float3(FLT_MAX, FLT_MAX, FLT_MAX)

  [unused_argument(dt)] def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    let fromPos = getFromPos(eid)
    if fromPos == float3(FLT_MAX, FLT_MAX, FLT_MAX)
      return EBehResult.ER_FAILED
    let toPos = getToPos(eid)
    if toPos == float3(FLT_MAX, FLT_MAX, FLT_MAX)
      return EBehResult.ER_FAILED

    var outPos = float3()
    traceray_navmesh(fromPos, toPos, extents, outPos)

    var outPosRef = getRW_Point3(eid, outPosParam, outPosParamHash)
    if outPosRef == null
      logerr_once("{eid}: AbstractNMeshTraceray can't to find out pos '{outPosParam}:{outPosParamHash}' {*thisNode |> beh_node_hierarchy_name(true)}")
      return EBehResult.ER_FAILED

    *outPosRef = outPos
    return EBehResult.ER_SUCCESS


[beh_node(name="nMeshTraceray")]
class NMeshTraceray : AbstractNMeshTraceray
  fromPosParam : string
  @hidden fromPosParamHash : uint
  posParam : string
  @hidden posParamHash : uint

  def override loadFromBlk(var data : DataBlock) : void
    AbstractNMeshTraceray`loadFromBlk(self, data)
    data |> load_optional_ecs_param("fromPosParam", fromPosParam, fromPosParamHash)
    data |> load_ecs_param("posParam", posParam, posParamHash, thisNode)

  def override getFromPos(eid : EntityId) : float3
    return get_Point3(eid, fromPosParam, fromPosParamHash) ?? AbstractNMeshTraceray`getFromPos(self, eid)

  def override getToPos(eid : EntityId) : float3
    return get_Point3(eid, posParam, posParamHash) ?? AbstractNMeshTraceray`getToPos(self, eid)


[beh_node(name="nMeshTracerayTarget")]
class NMeshTracerayTarget : AbstractNMeshTraceray
  fromPosParam : string
  @hidden fromPosParamHash : uint
  targetParam : string
  @hidden targetParamHash : uint

  def override loadFromBlk(var data : DataBlock) : void
    AbstractNMeshTraceray`loadFromBlk(self, data)
    data |> load_optional_ecs_param("fromPosParam", fromPosParam, fromPosParamHash)
    data |> load_ecs_param("targetParam", targetParam, targetParamHash, thisNode)

  def override getFromPos(eid : EntityId) : float3
    return get_Point3(eid, fromPosParam, fromPosParamHash) ?? AbstractNMeshTraceray`getFromPos(self, eid)

  def override getToPos(eid : EntityId) : float3
    var pos = AbstractNMeshTraceray`getToPos(self, eid)
    let targetParamRef = eid |> get_Eid(targetParam, targetParamHash)
    if targetParamRef == null
      logerr_once("{eid}: nMeshTracerayTarget can't to find target '{targetParam}:{targetParamHash}' {*thisNode |> beh_node_hierarchy_name(true)}")
      return pos
    query(*targetParamRef) <| $ [es] (transform : float3x4)
      pos = transform[3]
    return pos

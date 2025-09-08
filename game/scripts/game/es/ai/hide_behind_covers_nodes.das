options always_export_initializer = true
require app
require ecs
require Dacoll
require ecs.safe
require BehNodes
require RendInst
require daslib.algorithm
require math.base
require DagorMath
require ecs.common
require pathfinder
require DagorRandom
require DngHuman
require DagorDataBlock
require debug.logerr_once


def find_behind_cover_pos(danger_pos, cover_pos : float3; cover_rad, owner_rad, add_offset : float)
  var dir = cover_pos - danger_pos
  dir.y = 0.f
  dir = normalize(dir)
  return cover_pos + dir * (cover_rad + owner_rad + add_offset)


[beh_node(name="riCoversFindBestCover")]
class RiCoversFindBestCover : BehNodeAdapter
  posParam : int = -1
  targetUnitParam : int = -1
  searchRadius : float = 5.f
  offsetFromTarget : float = 3.f // offset of center of search circle (in opposite to enemy direction)
  coverToOwnerDistWeight : float = 1.f
  coverToTargetDistWeight : float = 1.f
  chanceOfChoosingBetterCover : float = 0.8
  coverOffset : float = 0.3 // additional offset (if set to 0.f, hide pos will be tight close to the cover)
  tries : int = 50

  def override loadFromBlk(var data : DataBlock)
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", "default"), float3())
    targetUnitParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetUnitParam", "default"), targetUnitParam)
    searchRadius = data |> datablock_getReal("searchRadius", searchRadius)
    offsetFromTarget = data |> datablock_getReal("offsetFromTarget", offsetFromTarget)
    coverToOwnerDistWeight = data |> datablock_getReal("coverToOwnerDistWeight", coverToOwnerDistWeight)
    coverToTargetDistWeight = data |> datablock_getReal("coverToTargetDistWeight", coverToTargetDistWeight)
    coverOffset = data |> datablock_getReal("coverOffset", coverOffset)
    tries = data |> datablock_getInt("tries", tries)

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    var bestPos : float3 = float3(0.f)
    var bestWeight : float = -1.f
    query(beh_tree_eid(owner)) <| $ [es] (transform aka owner_transform : float3x4; human_net_phys : HumanActor;
                                          var bot_with_ri_covers__currentCoverPos : float3&; var bot_with_ri_covers__currentCoverRad : float&)
      find_query() <| $ [es] (dynamic_ri_covers__allowed : UInt32List)
        let targetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(targetUnitParam)))
        query(targetEid) <| $ [es] (transform aka target_transform : float3x4)
          let distToTarget = distance(owner_transform[3], target_transform[3])
          let dirFromTarget = normalize(owner_transform[3] - target_transform[3])
          let searchPos = owner_transform[3] + dirFromTarget * offsetFromTarget
          let searchBox = BBox3(BSphere3(searchPos, min(searchRadius, distToTarget + offsetFromTarget)))
          var i = 0
          rendinst_foreachInBox(searchBox, int(GatherRiTypeFlags.RiGenAndExtra)) <| $ [unused_argument(is_tm)] (desc : RendInstDesc; tm : float3x4; is_tm : bool)
            if i >= tries
              return

            ++i

            let coverName = getRIGenResName(desc)
            if !has_value(dynamic_ri_covers__allowed, ecs_hash(coverName))

              return

            let collres = getRiGenCollisionResource(desc)
            if collres == null
              return

            let collresBMax = collres.boundingBox.boxMax
            let treeRootRad = max(collresBMax.x, collresBMax.z)
            var hidePos = find_behind_cover_pos(target_transform[3], tm[3], treeRootRad, human_net_phys.phys.collRad, coverOffset)
            if project_to_nearest_navmesh_point(hidePos, float3(0.1, 1.0, 0.1))
              let bestToOwnerDist = distance_sq(bestPos, owner_transform[3])
              let curToOwnerDist = distance_sq(hidePos, owner_transform[3])
              let probWeightToOwner = safediv(bestToOwnerDist, (bestToOwnerDist + curToOwnerDist))
              let bestToTargetDistSq = distance_sq(bestPos, target_transform[3])
              let curToTargetDistSq = distance_sq(hidePos, target_transform[3])
              let probWeightToTarget = safediv(curToTargetDistSq, (bestToTargetDistSq + curToTargetDistSq))
              let curWeight = safediv((probWeightToOwner * coverToOwnerDistWeight + probWeightToTarget * coverToTargetDistWeight),
                                      (coverToOwnerDistWeight + coverToTargetDistWeight))
              if curToTargetDistSq > square(offsetFromTarget) && (curWeight > bestWeight && gfrnd() < chanceOfChoosingBetterCover)
                bestPos = hidePos
                bestWeight = curWeight
                owner.blackBoard |> set(posParam, bestPos)
                bot_with_ri_covers__currentCoverPos = tm[3]
                bot_with_ri_covers__currentCoverRad = treeRootRad
                res = EBehResult.ER_SUCCESS
        return true
    return res


[beh_node(name="riCoversFindSafePos")]
class RiCoversFindSafePos : BehNodeAdapter
  posParam : int = -1
  targetUnitParam : int = -1
  coverOffset : float = 0.5 // additional offset (if set to 0.f, hide pos will be tight close to the cover)

  def override loadFromBlk(var data : DataBlock)
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", "default"), float3())
    targetUnitParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetUnitParam", "default"), targetUnitParam)
    coverOffset = data |> datablock_getReal("coverOffset", coverOffset)
    let ownerEid = beh_tree_eid(owner)
    if !has(ownerEid, "bot_with_ri_covers__currentCoverPos")
      logerr("{ownerEid}: riCoversFindSafePos node requires bot_with_ri_covers__currentCoverPos")

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (human_net_phys : HumanActor;
                                          bot_with_ri_covers__currentCoverPos : float3;
                                          bot_with_ri_covers__currentCoverRad : float)
      let targetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(targetUnitParam)))
      query(targetEid) <| $ [es] (transform aka target_transform : float3x4)
        var hidePos = find_behind_cover_pos(target_transform[3], bot_with_ri_covers__currentCoverPos, bot_with_ri_covers__currentCoverRad, human_net_phys.phys.collRad, coverOffset)
        if project_to_nearest_navmesh_point(hidePos, float3(0.5, 1.0, 0.5))
          owner.blackBoard |> set(posParam, hidePos)
          res = EBehResult.ER_SUCCESS
    return res


[beh_node(name="riCoversIsNearSafePos")]
class RiCoversIsNearSafePos : BehNodeAdapter
  maxDist : float = 0.5
  posParam : int = -1

  def override loadFromBlk(var data : DataBlock)
    maxDist = data |> datablock_getReal("maxDist", maxDist)
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", "default"), float3())

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (transform : float3x4)
      let targetPos = owner.blackBoard |> datablock_getPoint3(posParam)
      if distance_sq(targetPos.xz, transform[3].xz) < square(maxDist)
        res = EBehResult.ER_SUCCESS
    return res


[beh_node(name="riCoversSetPeekFromCoverPos")]
class RiCoversSetPeekFromCoverPos : BehNodeAdapter
  posParam : int = -1
  sideOffset : float = 0.4 // additionall to ri radius offset: radius + sideOffset
  backwardOffset : float = 0.5

  def override loadFromBlk(var data : DataBlock)
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", "default"), float3())
    sideOffset = data |> datablock_getReal("sideOffset", sideOffset)
    backwardOffset = data |> datablock_getReal("backwardOffset", backwardOffset)
    let ownerEid = beh_tree_eid(owner)
    if !has(ownerEid, "bot_with_ri_covers__currentCoverPos")
      logerr("{ownerEid}: riCoversSetPeekFromCoverPos node requires bot_with_ri_covers__currentCoverPos")

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (transform : float3x4; bot_with_ri_covers__currentCoverPos : float3)
      var dir = transform[3] - bot_with_ri_covers__currentCoverPos
      var norm = float3(dir.z, 0.f, -dir.x)
      norm -= 2.f * float(rnd_int(0, 1)) * norm
      dir = normalize(dir) * gfrnd() * backwardOffset
      norm += normalize(norm) * gfrnd() * sideOffset
      var pos = bot_with_ri_covers__currentCoverPos + dir + norm
      if project_to_nearest_navmesh_point(pos, float3(0.5, 1.0, 0.5))
        owner.blackBoard |> set(posParam, pos)
        res = EBehResult.ER_SUCCESS
    return res


[beh_node(name="riCoversSaveCurPos")]
class RiCoversSaveCurPos : BehNodeAdapter

  def override loadFromBlk(var data : DataBlock)
    let ownerEid = beh_tree_eid(owner)
    if !has(ownerEid, "bot_with_ri_covers__lastPos")
      logerr("{ownerEid}: riCoversSaveCurPos node requires bot_with_ri_covers__lastPos")

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (transform : float3x4; var bot_with_ri_covers__lastPos : float3&)
      bot_with_ri_covers__lastPos = transform[3]
      res = EBehResult.ER_SUCCESS
    return res


[beh_node(name="riCoversIsNearSavedPos")]
class RiCoversIsNearSavedPos : BehNodeAdapter
  maxDist : float = 1.f

  def override loadFromBlk(var data : DataBlock)
    let ownerEid = beh_tree_eid(owner)
    maxDist = data |> datablock_getReal("maxDist", maxDist)
    if !has(ownerEid, "bot_with_ri_covers__lastPos")
      logerr("{ownerEid}: riCoversIsNearSavedPos node requires bot_with_ri_covers__lastPos")

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (transform : float3x4; bot_with_ri_covers__lastPos : float3)
      if distance_sq(bot_with_ri_covers__lastPos, transform[3]) < square(maxDist)
        res = EBehResult.ER_SUCCESS
    return res


[beh_node(name="setTimer")]
class SetTimer : BehNodeAdapter
  deltaTime : float = 10.f
  target : string
  @hidden targetHash : uint

  def override loadFromBlk(var data : DataBlock)
    deltaTime = data |> datablock_getReal("deltaTime", deltaTime)
    data |> load_ecs_param("target", target, targetHash, thisNode)

  def override update(dt : float) : EBehResult
    let ownerEid = beh_tree_eid(owner)
    var targetRef = ownerEid |> getRW_float(target, targetHash)
    if targetRef == null
      logerr_once("{ownerEid}: setTimer node can't find target '{target}:{targetHash}' {*thisNode |> beh_node_hierarchy_name(true)}")
      return EBehResult.ER_FAILED

    *targetRef = get_sync_time() + deltaTime
    return EBehResult.ER_SUCCESS


[beh_node(name="resetTimer")]
class ResetTimer : BehNodeAdapter
  target : string
  @hidden targetHash : uint

  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("target", target, targetHash, thisNode)

  def override update(dt : float) : EBehResult
    let ownerEid = beh_tree_eid(owner)
    var targetRef = ownerEid |> getRW_float(target, targetHash)
    if targetRef == null
      logerr_once("{ownerEid}: resetTimer node can't find target '{target}:{targetHash}' {*thisNode |> beh_node_hierarchy_name(true)}")
      return EBehResult.ER_FAILED

    *targetRef = -1.f
    return EBehResult.ER_SUCCESS


[beh_node(name="isTimerInProgress")]
class IsTimerInProgress : BehNodeAdapter
  target : string
  @hidden targetHash : uint

  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("target", target, targetHash, thisNode)

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    let ownerEid = beh_tree_eid(owner)
    var targetRef = ownerEid |> get_float(target, targetHash)
    if targetRef == null
      logerr_once("{ownerEid}: isTimerInProgress node can't find target '{target}:{targetHash}' {*thisNode |> beh_node_hierarchy_name(true)}")
      return EBehResult.ER_FAILED

    if *targetRef > get_sync_time()
      res = EBehResult.ER_SUCCESS
    return res

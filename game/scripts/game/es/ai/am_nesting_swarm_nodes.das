options always_export_initializer = true
require ecs
require ecs.safe
require ecs.common
require app
require math
require math.base
require DagorRandom
require DagorMath
require Dacoll
require BehNodes
require DagorSystem
require DagorDataBlock
require DngDm
require GridCollision
require Grid
require pathfinder
require game.es.level_common
require game.es.nesting_swarm_common
require game.events.events
require game.utils.team


[beh_node(name="isSwarmWithinNestRange")]
class IsSwarmWithinNestRange : BehNodeAdapter

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (swarm_warrior__nests : EidList;
                                          swarm_warrior__maxRange : float;
                                          transform aka warrior_transform : float3x4)
      let maxRangeSq = square(swarm_warrior__maxRange)
      for nestEid in swarm_warrior__nests
        var dstSq : float
        query(nestEid) <| $ [es] (transform aka nest_transform : float3x4)
          dstSq = distance_sq(warrior_transform[3], nest_transform[3])
        if dstSq < maxRangeSq
          result = EBehResult.ER_SUCCESS
          break
    return result


[beh_node(name="nestingSwarmSnakeFindDanger")]
class NestingSwarmSnakeFindDanger : BehNodeAdapter
  targetParam : int
  radiusParam : int

  def override loadFromBlk(var data : DataBlock)
    targetParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "paramName", "enemy"), int(uint(INVALID_ENTITY_ID)))
    radiusParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "radiusParamName", "enemyRadius"), 25.0)

  def override update(dt : float) : EBehResult
    let ownerEid = beh_tree_eid(owner)
    let radius = owner.blackBoard |> datablock_getReal(radiusParam)
    let bestTarget = find_nesting_swarm_snake_best_target(ownerEid, radius)
    owner.blackBoard |> set(targetParam, int(uint(bestTarget)))
    return bestTarget != INVALID_ENTITY_ID ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED
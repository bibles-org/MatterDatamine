options always_export_initializer = true

require ecs
require strings
require DagorSystem
require DagorMath
require BehNodes
require DagorDataBlock
require Dacoll
require Grid
require GridCollision
require pathfinder
require debug.logerr_once
require game.es.wandering_core_common


[beh_node(name="initCuriosityCell")]
class InitCuriosityCell : BehNodeAdapter

  def override update(dt : float) : EBehResult
    let agent_eid = beh_tree_eid(owner)
    var res = EBehResult.ER_FAILED
    if init_curiosity_cell(agent_eid)
      res = EBehResult.ER_SUCCESS
    return res


[beh_node(name="findWanderingCoreTarget")]
class FindWanderingCoreTarget : BehNodeAdapter

  def override update(dt : float) : EBehResult
    let agent_eid = beh_tree_eid(owner)
    var res = EBehResult.ER_FAILED
    query(agent_eid) <| $ [es] (wandering_core__agroedSearchTargetRadius : float2;
                                wandering_core__agro : float;
                                wandering_core__agroMax : float;
                                transform aka core_transform : float3x4;
                                var wandering_core__targetEid : EntityId&)
      wandering_core__targetEid = INVALID_ENTITY_ID
      var bestDst = FLT_MAX
      assume searchRad = wandering_core__agroedSearchTargetRadius
      let radius = lerp(searchRad.x, searchRad.y, wandering_core__agro / wandering_core__agroMax)
      let sphere = BSphere3(core_transform[3], radius)
      for_each_entity_in_grid(ecs_hash("humans"), sphere, GridEntCheck.POS) <| $(target_eid : EntityId)
        query(target_eid) <| $ [es(REQUIRE_NOT=deadEntity, REQUIRE=(ai_target, human_net_phys, heroForPlayer))] (transform aka target_transform : float3x4)
          let dstSq = distance_sq(target_transform[3], core_transform[3])
          if dstSq < bestDst
            bestDst = dstSq
            wandering_core__targetEid = target_eid
            res = EBehResult.ER_SUCCESS
    return res


[beh_node(name="findPosInCuriosityCell")]
class FindPosInCuriosityCell : BehNodeAdapter
  posParam : string
  @hidden posParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("posParam", posParam, posParamHash, thisNode)

  def override update(dt : float) : EBehResult
    let agent_eid = beh_tree_eid(owner)
    var res = EBehResult.ER_FAILED
    query(agent_eid) <| $ [es] (curious_core__curiosityCell : int&;
                                transform : float3x4;
                                curious_core__gridCellSize : float;
                                curious_core__gridSizeX : int;
                                curious_core__gridMin : float3)
      var pos = grid_cell_to_pos(curious_core__curiosityCell, transform[3].y, curious_core__gridMin, curious_core__gridCellSize, curious_core__gridSizeX)
      if project_to_nearest_navmesh_point(pos, float3(curious_core__gridCellSize))
        var waterLevel = 0.0
        let hasWater = traceht_water(pos, waterLevel)
        if hasWater && waterLevel > pos.y
          return
        if !has(agent_eid, posParam, posParamHash)
          logerr_once("{agent_eid}: entity without output param '{posParam}:{posParamHash}' / {*thisNode |> beh_node_hierarchy_name(true)}")
        setOptional(agent_eid, posParam, posParamHash, pos)
        res = EBehResult.ER_SUCCESS
    return EBehResult.ER_SUCCESS


require ecs
require app
require HeightmapQueryManager
require gpuReadbackQuery
require GridCollision
require Dacoll
require Grid
require DagorMath
require math.base
require game.es.tweening_common
require game.es.grav_zones_common


[es(tag=gameClient, on_appear, track=server_transform)]
def trigger_client_displacement_compensation(evt : Event;
                                             server_transform : float3x4;
                                             var transform : float3x4;
                                             var displacement_compensation__queryPos : float3&;
                                             var displacement_compensation__queryId : int&)
  if displacement_compensation__queryPos != server_transform[3]
    transform := server_transform
    displacement_compensation__queryId = -1
    query() <| $ [es] (displacement_compensation__radius : float; transform : float3x4; var displacement_compensation__updateAt : float&)
      if distance_sq(transform[3], server_transform[3]) < square(displacement_compensation__radius)
        let qpos = server_transform[3].xyz
        displacement_compensation__queryPos = server_transform[3]
        displacement_compensation__queryId = heightmap_query_start(qpos, get_grav_dir(qpos))
        displacement_compensation__updateAt = get_sync_time() + 0.1 //update in ~2 frames


[es(tag=gameClient, no_order)]
def item_displacement_compensation_es(act : UpdateStageInfoAct;
                                      transform aka human_transform : float3x4;
                                      displacement_compensation__interval : float;
                                      displacement_compensation__radius : float;
                                      var displacement_compensation__updateAt : float&)
  if act.curTime > displacement_compensation__updateAt
    var newQueryTriggered = false
    let sphere = BSphere3(human_transform[3], displacement_compensation__radius)
    for_each_entity_in_grid(ecs_hash("loot"), sphere, GridEntCheck.POS) <| $ [unused_argument(pos)] (item_eid : EntityId; pos : float3)
      query(item_eid) <| $ [es] (server_transform : float3x4;
                                 dropTm : float3x4 const?;
                                 var displacement_compensation__queryPos : float3&;
                                 var displacement_compensation__queryId : int&;
                                 displacement_compensation__compensationTime : float;
                                 var transform aka item_transform : float3x4)
        if displacement_compensation__queryId < 0 && displacement_compensation__queryPos != server_transform[3]
          displacement_compensation__queryPos = server_transform[3]
          displacement_compensation__queryId = heightmap_query_start(server_transform[3], get_grav_dir(server_transform[3]))
          newQueryTriggered = true
        else
          var hmqr = HeightmapQueryResultWrapper()
          let qRes = heightmap_query_value(displacement_compensation__queryId, hmqr)
          if is_gpu_readback_query_successful(qRes)
            displacement_compensation__queryId = -1
            let dropY = dropTm != null ? (*dropTm)[3].y : .0

            let hitNoOffset = displacement_compensation__queryPos + hmqr.hitDistNoOffset * hmqr.normal

            let dstToGroundSq = distance_sq(server_transform[3], hitNoOffset)
            if dstToGroundSq < square(dropY + 0.02) //the server placed the item on the ground
              let hitWithOffsetDeform = displacement_compensation__queryPos + (hmqr.hitDistWithOffsetDeform + 0.01) * hmqr.normal
              let traceDir = -hmqr.normal
              var t = distance(server_transform[3], hitWithOffsetDeform)
              var norm : float3
              let tracePos = server_transform[3] - traceDir * 1e-3
              if t > 0.0 && traceray_normalized(tracePos, traceDir, t, norm, ETF_RI)
                // Item lies on the RI, don't move it
                return

              if displacement_compensation__compensationTime > 0.0
                tween_transform_pos(item_eid, hitWithOffsetDeform, displacement_compensation__compensationTime)
              else
                item_transform[3] = hitWithOffsetDeform
          elif is_gpu_readback_query_failed(qRes)
            displacement_compensation__queryId = -1
    if !newQueryTriggered
      displacement_compensation__updateAt = act.curTime + displacement_compensation__interval
    else
      displacement_compensation__updateAt = act.curTime + 0.1 //update in ~2 frames
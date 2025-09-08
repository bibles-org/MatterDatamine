require ecs
require ecs.common
require DngNet
require game.events.events_game
require game.es.item_equip_common
require game.events.events_active_matter
require game.utils.team
require DagorRandom

[es(tag=server, on_appear)]
def init_corrupted_militant_from_anomaly(evt : Event; anomaly_zone__ownerZoneEid : EntityId; var corrupted_militant__regionTm : float3x4)
  query(anomaly_zone__ownerZoneEid) <| $ [es] (transform : float3x4;
                                               nmesh_voxel__gridStep : float;
                                               nmesh_voxel__gridSize : int3)
    let fltSize = float3(nmesh_voxel__gridSize)
    corrupted_militant__regionTm[0] *= fltSize.x * nmesh_voxel__gridStep
    corrupted_militant__regionTm[1] *= fltSize.y * nmesh_voxel__gridStep
    corrupted_militant__regionTm[2] *= fltSize.z * nmesh_voxel__gridStep
    corrupted_militant__regionTm[3] = transform[3]
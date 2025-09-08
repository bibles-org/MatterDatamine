module monsters_common shared

require ecs
require ecs.common
require ecs.soa_template


enum InvisibleManType
  HUNTER = 0
  GUARD = 1
  EXTRACTION_POINT_DEFENDER = 2


[soa_template]
struct InvisibleManTargetData
  invisible_man_target_data__eid : EntityId
  invisible_man_target_data__spawnTime : float
  invisible_man_target_data__spawnIndex : int
  invisible_man_target_data__spawningCount : int
  invisible_man_target_data__lastSpawnTime : float
  invisible_man_target_data__inactivityCheckTime : float
  invisible_man_target_data__lastMovementStartPos : float3
  invisible_man_target_data__lastMovementTime : float
  invisible_man_target_data__lastDangerTime : float

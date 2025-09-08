module monster_common shared

require ecs
require pathfinder
require math.base
require game.es.ecs_common
require DagorSystem
require DagorMath


def is_monster_sleeping(sleep_mode__isSleeping : bool const?;
                        sleeping_monster : Tag const?)
  if sleep_mode__isSleeping != null
    return *sleep_mode__isSleeping
  elif sleeping_monster != null
    return true

  return false


def is_monster_sleeping(monster_eid : EntityId)
  var result = false

  query(monster_eid) <| $ [es] (sleep_mode__isSleeping : bool const?;
                                sleeping_monster : Tag const?)
    result = is_monster_sleeping(sleep_mode__isSleeping, sleeping_monster)

  return result



def spawn_minion(master_eid : EntityId;
                 minion_tm : float3x4;
                 minion_template : string)
  query(master_eid) <| $ [es] (team aka master_team : int)
    createEntity(minion_template) <| $ [es] (var init : ComponentsInitializer)
      init |> set("transform", minion_tm)
      init |> set("team", master_team)
      init |> set("minion_creature__masterEid", master_eid)


def spawn_minion(master_eid : EntityId;
                 radius : float = 2.0;
                 offset : float = 3.0;
                 minion_template : string)
  query(master_eid) <| $ [es] (transform aka master_transform : float3x4)
    let masterPos = master_transform[3]
    let spawnCircleCenter = masterPos + master_transform[0] * offset
    var minionPos : float3
    if !find_random_point_inside_circle(spawnCircleCenter, radius, 1.0, minionPos)
      logerr("Failed to find nmesh point in front of master = {spawnCircleCenter}")
      return

    var minionTM : float3x4
    minionTM[0] = normalize(masterPos - minionPos)
    minionTM[2] = cross(minionTM[0], master_transform[1])
    minionTM[1] = cross(minionTM[2], minionTM[0])
    minionTM[3] = minionPos
    spawn_minion(master_eid, minionTM, minion_template)


def is_minion_walk_mark_exists(minion_eid : EntityId)
  var result = false
  query(minion_eid) <| $ [es] (minion_creature__masterEid : EntityId)
    result = find_query() <| $ [es] (minion_walk_mark__owner : EntityId)
      return minion_walk_mark__owner == minion_creature__masterEid
  return result


def find_minion_stand_pos(minion_eid : EntityId;
                          walk_marks_only : bool = false)
  var result : float3
  query(minion_eid) <| $ [es] (minion_creature__masterEid : EntityId)

    // Walk mark is first priority
    let walkMarkFound = find_query() <| $ [es] (minion_walk_mark__owner : EntityId;
                                                transform aka minion_walk_mark_transform : float3x4)
      if minion_walk_mark__owner != minion_creature__masterEid
        return false

      result = minion_walk_mark_transform[3]
      return true

    if walkMarkFound || walk_marks_only
      return

    // Master is second priority
    query(minion_creature__masterEid) <| $ [es] (transform aka master_transform : float3x4)
      result = master_transform[3]

  return result


def get_minion_danger_attack_mark_priority(master_eid : EntityId;
                                           target_eid : EntityId)
  var priority = 0

  find_query() <| $ [es] (minion_attack_mark__owner : EntityId;
                          minion_attack_mark__target : EntityId;
                          minion_attack_mark__piority : int)
    if minion_attack_mark__owner != master_eid || minion_attack_mark__target != target_eid
      return false
    priority = minion_attack_mark__piority
    return false

  return priority
require ecs
require app
require level
require math.base
require math.random
require DagorRandom
require DagorDataBlock
require BehNodes
require DngBehTree
require Dacoll
require DagorMath
require pathfinder
require game.es.monster_gen_common
require game.es.custom_region_common
require game.utils.sound_utils


// ATTENTION!
// region_monster_generator_generator, which is used here, was overhauled,
// and this file was not fixed because it was not used at the moment
// If you need this functionality, mind changes in region_monster_generator_generator template
// monster_gen__type and monster_gen__genGenEid components (that are only used in this file)
// were preserved, they shoould work fine

[es(tag=server, on_appear)]
def init_migration_generator(evt : Event; migration__interval : float2; var migration__migrateAt : float&; var migration__updateAt : float&)
  migration__migrateAt = get_sync_time() + rnd_float(migration__interval)
  migration__updateAt = FLT_MAX


[es(tag=server, no_order)]
def migration_trigger_update(act : UpdateStageInfoAct; eid : EntityId; migration__migrateAt : float)
  if migration__migrateAt < act.curTime
    lauch_migration(eid)


[es(tag=server, no_order)]
def migration_movement_update(act : UpdateStageInfoAct;
                              eid aka migration_eid : EntityId;
                              migration__updateInterval : float;
                              migration__speed : float2;
                              migration__radius : float;
                              migration__waitingThreshold : float;
                              migration__maxWaitingTime : float;
                              migration__stragglersRadius : float;
                              migration__checkHeroRadius : float;
                              var migration__waitingTimeLeft : float&;
                              var migration__path : Point3List;
                              var transform aka migration_transform : float3x4;
                              var migration__updateAt : float&)
  if migration__updateAt < act.curTime
    let dt = act.curTime - migration__updateAt + migration__updateInterval
    migration__updateAt = act.curTime + migration__updateInterval
    var count = 0
    var withinRadiusCount = 0
    let migrationRadiusSq = square(migration__radius)
    let stragglersRadiusSq = square(migration__stragglersRadius)
    var stragglers : array<tuple<eid : EntityId; pos : float3>>
    query() <| $ [es] (eid aka follower_eid, generated_monster__genEid : EntityId; transform aka follower_transform : float3x4)
      if generated_monster__genEid == migration_eid
        count++
        let awayDstSq = distance_sq(migration_transform[3], follower_transform[3])
        withinRadiusCount += awayDstSq < migrationRadiusSq ? 1 : 0
        if awayDstSq > stragglersRadiusSq
          stragglers |> emplace((follower_eid, follower_transform[3]))
    if count == 0
      finish_migration(migration_eid)
      return
    let ratio = square(float(withinRadiusCount) / float(count))
    if ratio < migration__waitingThreshold && migration__waitingTimeLeft > 0.0
      migration__waitingTimeLeft -= dt
      return
    clear_stragglers(stragglers, migration__checkHeroRadius)
    let speed = count == 0 ? migration__speed.x : lerp(migration__speed.y, migration__speed.x, ratio)
    var movement = dt * speed
    while movement > 0.0 && length(migration__path) > 0
      let delta = migration__path[0] - migration_transform[3]
      let dst = length(delta)
      if movement >= dst
        movement -= dst
        migration_transform[3] = migration__path[0]
        migration__path |> erase(0)
        if length(migration__path) == 0
          migration__waitingTimeLeft = migration__maxWaitingTime
      else
        migration_transform[3] += delta * safediv(dt * speed, dst)
        movement = 0.0
    if length(migration__path) == 0 && (migration__waitingTimeLeft <= 0.0 || ratio > migration__waitingThreshold)
      finish_migration(migration_eid)


def clear_stragglers(var stragglers : array<tuple<eid : EntityId; pos : float3>>; check_hero_radius : float)
  if length(stragglers) > 0
    let radiusSq = square(check_hero_radius)
    find_query() <| $ [es(REQUIRE=heroForPlayer)] (transform : float3x4; isAlive : bool)
      if isAlive
        var idx = length(stragglers)
        while idx-- > 0
          if distance_sq(transform[3], stragglers[idx].pos) < radiusSq
            stragglers |> erase(idx)
      return length(stragglers) > 0
  //stragglers who don't have players near them are destroyed
  for straggler in stragglers
    destroyEntity(straggler.eid)


def finish_migration(eid : EntityId)
  query(eid) <| $ [es] (monster_gen__region : string;
                        monster_gen__density : float2;
                        migration__interval : float2;
                        migration__maxFails : int;
                        var migration__failsLeft : int&;
                        var migration__migrateAt : float&;
                        var monster_gen__updateAt : float&;
                        var migration__updateAt : float&;
                        var monster_gen__maxCount : int&)
    migration__updateAt = FLT_MAX
    migration__migrateAt = get_sync_time() + rnd_float(migration__interval)
    monster_gen__updateAt = get_sync_time()
    migration__failsLeft = migration__maxFails
    in_region_with_name(monster_gen__region) <| $ [unused_argument(a1, a2)] (a1, a2, data)
      monster_gen__maxCount = int(ceil(rnd_float(monster_gen__density) * data.area))
      query() <| $ [es] (generated_monster__genEid : EntityId; var beh_tree : BehaviourTree; var migration__leaderEid : EntityId&)
        if generated_monster__genEid == eid
          migration__leaderEid = INVALID_ENTITY_ID
          beh_tree.blackBoard |> set("region", monster_gen__region)
          beh_tree_reset(beh_tree)


def nearest_lmesh_border_point(region_points : Point2List; pos : float3)
  var bestDstSq = FLT_MAX
  var bestPoint : float2
  for p in region_points
    let dstSq = distance_sq(p, pos.xz)
    if dstSq < bestDstSq
      bestDstSq = dstSq
      bestPoint = p
  return float3(bestPoint.x, traceht_lmesh(bestPoint), bestPoint.y)


def try_find_full_path(from, to : float3; var path : Point3List)
  clear(path)
  let extents = float3(3.0, FLT_MAX, 3.0)
  let step = 8.0
  var attempts = 4
  var success = false
  var movingFrom = from
  while attempts-- > 0
    let resPath = find_path(movingFrom, to, extents, step, 1.0, null) <| $(data)
      if length(data) > 1 && length(data) < 1000
        for p in data
          path |> push(p)
    if resPath == FindPathResult.FPR_FULL
      let start = length(path) > 0 ? path[length(path) - 1] : from
      if distance(start.xz, to.xz) > step //pathfinder may find "full" path wich is 150 meters away from the destination
        path |> push(to)
      success = true
      break
    elif resPath == FindPathResult.FPR_FAILED
      return false
    elif length(path) > 0
      movingFrom = path[length(path) - 1]
    else
      return false
  return success


def lauch_migration(migration_eid : EntityId)
  query(migration_eid) <| $ [es] (monster_gen__genGenEid : EntityId;
                                  migration__interval : float2;
                                  migration__maxWaitingTime : float;
                                  var migration__failsLeft : int&;
                                  var migration__waitingTimeLeft : float&;
                                  var migration__path : Point3List;
                                  var transform : float3x4;
                                  var migration__migrateAt : float&;
                                  var migration__updateAt : float&;
                                  var monster_gen__updateAt : float&;
                                  var monster_gen__region : das_string)
    find_query() <| $ [es] (moving_zone__sourceRadius : float; moving_zone__sourcePos : float3)
      find_query() <| $ [es] (eid : EntityId; monster_gen_gen__regions : StringList; monster_gen_gen__type : string)
        if monster_gen__genGenEid == eid
          let choices <- find_unoccupied_regions_in_the_zone(moving_zone__sourceRadius, moving_zone__sourcePos, monster_gen_gen__type, monster_gen_gen__regions)
          if length(choices) > 0
            let newRegion = choices[grnd() % length(choices)]
            in_region_with_name(newRegion) <| $ [unused_argument(a32)] (new_points, a32, new_data)
              in_region_with_name(string(monster_gen__region)) <| $ [unused_argument(a42)] (old_points, a42, old_data)
                transform[3] = nearest_lmesh_border_point(old_points, new_data.center)
                let destination = nearest_lmesh_border_point(new_points, old_data.center)
                if try_find_full_path(transform[3], destination, migration__path)
                  print("Start monster migration {string(monster_gen__region)} -> {newRegion}")
                  transform[3] = migration__path[0]
                  migration__migrateAt = FLT_MAX
                  monster_gen__updateAt = FLT_MAX
                  migration__updateAt = get_sync_time()
                  monster_gen__region := newRegion
                  migration__waitingTimeLeft = migration__maxWaitingTime
                  var isSoundPlayed = false
                  query() <| $ [es] (eid, generated_monster__genEid : EntityId;
                                     transform : float3x4;
                                     var beh_tree : BehaviourTree;
                                     var migration__leaderEid : EntityId&)
                    if generated_monster__genEid == migration_eid
                      migration__leaderEid = migration_eid
                      beh_tree_reset(beh_tree)
                      if !isSoundPlayed
                        isSoundPlayed = true
                        broadcast_net_sound(eid, "migration_start", transform[3])
                else
                  if migration__failsLeft-- <= 0
                    migration__migrateAt = get_sync_time() + rnd_float(migration__interval)
          else
            print("Skip monster migration, no free regions found")
            migration__migrateAt = get_sync_time() + rnd_float(migration__interval)
        return monster_gen__genGenEid == eid
      return true
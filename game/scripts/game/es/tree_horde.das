require ecs
require ecs.common
require game.utils.team
require app
require math.base
require math.random
require pathfinder
require Grid
require DagorMath
require game.es.level_common
require game.es.grav_zones_common
require game.events.events_active_matter


[es(on_appear, tag=server)]
def tree_horde_event_init(evt : Event;
                          transform : float3x4;
                          tree_horde_event__numTrees : int2;
                          tree_horde_event__spawnDuration : float;
                          var tree_horde_event__goal : EntityId&;
                          var tree_horde_event__leftToSpawn : int&;
                          var tree_horde_event__nextUpdate : float&;
                          var tree_horde_event__updateInterval : float&)
  tree_horde_event__leftToSpawn = rnd_int(tree_horde_event__numTrees)
  tree_horde_event__updateInterval = tree_horde_event__spawnDuration / float(tree_horde_event__leftToSpawn)
  tree_horde_event__nextUpdate = tree_horde_event__updateInterval + get_sync_time()
  tree_horde_event__goal = createEntity("tree_horde_goal") <| $(var init)
    set(init, "transform", transform)


[es(on_disappear, tag=server)]
def tree_horde_event_destroy(evt : Event;
                             tree_horde_event__goal : EntityId)
  destroyEntity(tree_horde_event__goal)


[es(no_order, tag=server)]
def tree_horde_event_update(upd : UpdateStageInfoAct;
                            transform : float3x4;
                            tree_horde_event__updateInterval : float;
                            tree_horde_event__spawnRadiusMinMax : float2;
                            tree_horde_event__treeTemplate : string;
                            var tree_horde_event__leftToSpawn : int&;
                            var tree_horde_event__nextUpdate : float&)
  if tree_horde_event__leftToSpawn <= 0
    return
  if upd.curTime < tree_horde_event__nextUpdate
    return
  tree_horde_event__nextUpdate = tree_horde_event__updateInterval + upd.curTime
  var spawnTm = transform
  let offset2d = rnd_point_on_ring(tree_horde_event__spawnRadiusMinMax)
  var spawnPos = transform * float3(offset2d.x, 0.0, offset2d.y)

  var poly : dtPolyRef
  if !project_to_nearest_navmesh_point(spawnPos, float3(1.0, 2.0, 1.0), poly)
    return
  if !is_polygon_accessible(poly)
    return
  createEntity(tree_horde_event__treeTemplate) <| $(var init)
    spawnTm[3] = spawnPos
    set(init, "transform", spawnTm)
  tree_horde_event__leftToSpawn -= 1


[es(no_order, tag=server)]
def tree_horde_event_mark_enemies_as_goal(upd : UpdateStageInfoAct;
                                          eid aka event_eid : EntityId;
                                          team aka event_team : int;
                                          truce_id aka event_truce_id : int;
                                          transform aka event_transform : float3x4;
                                          tree_horde_event__goal : EntityId;
                                          tree_horde_event__enemiesMarkRadius : float;
                                          tree_horde_event__enemiesMarkUpdateInterval : float2;
                                          var tree_horde_event__enemiesMarkUpdateAt : float&)
  if upd.curTime < tree_horde_event__enemiesMarkUpdateAt
    return

  tree_horde_event__enemiesMarkUpdateAt = upd.curTime + rnd_float(tree_horde_event__enemiesMarkUpdateInterval)

  let sphere = BSphere3(transform[3], tree_horde_event__enemiesMarkRadius)
  var foundSuitableEnemy = false
  using() <| $(var noPersonalEnemies : EidList)
    for_each_entity_in_grid(ecs_hash("humans"), sphere, GridEntCheck.BOUNDING) <| $(enemy : EntityId; pos : float3)
      if foundSuitableEnemy
        return
      query(enemy) <| $ [es] (team aka enemy_team : int;
                              truce_id aka enemy_truce_id : int = -1)
        if !is_hostile(event_team, event_truce_id, noPersonalEnemies, enemy, enemy_team, enemy_truce_id)
          return
        if distance_sq(pos, event_transform[3]) > square(tree_horde_event__enemiesMarkRadius)
          return
        foundSuitableEnemy = true
        query(tree_horde_event__goal) <| $ [es] (var tree_horde_goal__attachedTo : EntityId&)
          tree_horde_goal__attachedTo = enemy
  if !foundSuitableEnemy
    query(tree_horde_event__goal) <| $ [es] (var tree_horde_goal__attachedTo : EntityId&)
      tree_horde_goal__attachedTo = event_eid


[es(no_order, tag=server)]
def tree_horde_goal_update(upd : UpdateStageInfoAct;
                           tree_horde_goal__attachedTo : EntityId;
                           tree_horde_goal__transformUpdateInterval : float2;
                           var tree_horde_goal__transformUpdateAt : float&;
                           var transform aka goal_transform : float3x4&)
  if upd.curTime < tree_horde_goal__transformUpdateAt
    return
  tree_horde_goal__transformUpdateAt = upd.curTime + rnd_float(tree_horde_goal__transformUpdateInterval)
  query(tree_horde_goal__attachedTo) <| $ [es] (transform aka target_transform : float3x4)
    goal_transform[3] = target_transform[3]

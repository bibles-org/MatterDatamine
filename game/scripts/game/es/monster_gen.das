require ecs
require ecs.common
require math.base
require level
require pathfinder
require DagorMath
require DagorRandom
require DagorSystem
require Dacoll
require game.es.level_common
require game.es.ecs_common
require game.events.events_active_matter
require active_matter.game.es.regions_common
require debug.logerr_once
require daslib/lpipe
require NavmeshMapping
require game.es.ai.agent_position_mapping_common
require game.es.grav_zones_common
require game.es.custom_region_common


[es(tag=server, no_order)]
def update_region_monster_gen(act : ParallelUpdateFrameDelayed;
                              eid : EntityId;
                              monster_gen__genGenEid : EntityId;
                              regional_generator__region : string;
                              regional_generator__condenseToCenter : bool = false;
                              monster_gen__templates : StringList;
                              monster_gen__useGravity : bool;
                              monster_gen__maxCount : int;
                              monster_gen__checkPlayersRadius : float;
                              monster_gen__spawnInterval : float;
                              monster_gen__spawnIntervalKoef : float = 1.0;
                              monster_gen__respawnInterval : float;
                              monster_gen__minProximity : float;
                              monster_gen__maxConsecutiveFails : int;
                              monster_gen__underwaterGenAllowed : bool = false;
                              monster_gen__onlyAccessiblePolygons : bool = true;
                              monster_gen__ignoreForbiddenZones : bool = false;
                              var monster_gen__curCount : int&;
                              var monster_gen__consecutiveFails : int&;
                              var monster_gen__spawnComplete : bool&;
                              var monster_gen__updateAt : float&)
  if monster_gen__updateAt > act.curTime
    return
  in_region_with_name(regional_generator__region) <| $(points, indices, data)
    let radius = max(data.bbox.width.x, max(data.bbox.width.y, data.bbox.width.z))
    monster_gen_procedure(act,
                          eid,
                          monster_gen__genGenEid,
                          monster_gen__templates,
                          monster_gen__useGravity,
                          monster_gen__maxCount,
                          monster_gen__minProximity,
                          monster_gen__checkPlayersRadius,
                          monster_gen__spawnInterval,
                          monster_gen__spawnIntervalKoef,
                          monster_gen__respawnInterval,
                          monster_gen__maxConsecutiveFails,
                          monster_gen__underwaterGenAllowed,
                          monster_gen__onlyAccessiblePolygons,
                          monster_gen__ignoreForbiddenZones,
                          monster_gen__curCount,
                          monster_gen__consecutiveFails,
                          monster_gen__spawnComplete,
                          monster_gen__updateAt,
                          data.center,
                          radius) <| $()
      if regional_generator__condenseToCenter
        return generate_region_point_condense_to_center(data.center, data.bbox, points, indices)
      else
        return random_point_in_region(points, indices)
    lpipe <| $(pos : float3)
      return is_point_inside_region(pos, points, indices, data.bbox)
    lpipe <| $(init)
      init |> set("beh_tree__blackboard__region", regional_generator__region)


[es(tag=server, no_order)]
def update_tm_monster_gen(act : ParallelUpdateFrameDelayed;
                          eid : EntityId;
                          monster_gen__genGenEid : EntityId;
                          transform : float3x4;
                          monster_gen__templates : StringList;
                          monster_gen__useGravity : bool;
                          monster_gen__maxCount : int;
                          monster_gen__checkPlayersRadius : float;
                          monster_gen__spawnInterval : float;
                          monster_gen__spawnIntervalKoef : float = 1.0;
                          monster_gen__respawnInterval : float;
                          monster_gen__minProximity : float;
                          monster_gen__maxConsecutiveFails : int;
                          monster_gen__underwaterGenAllowed : bool = false;
                          monster_gen__onlyAccessiblePolygons : bool = true;
                          monster_gen__ignoreForbiddenZones : bool = false;
                          var monster_gen__curCount : int&;
                          var monster_gen__consecutiveFails : int&;
                          var monster_gen__spawnComplete : bool&;
                          var monster_gen__updateAt : float&)
  if monster_gen__updateAt > act.curTime
    return
  let diag = length(transform[0] + transform[1] + transform[2]) * 0.5
  monster_gen_procedure(act,
                        eid,
                        monster_gen__genGenEid,
                        monster_gen__templates,
                        monster_gen__useGravity,
                        monster_gen__maxCount,
                        monster_gen__minProximity,
                        monster_gen__checkPlayersRadius,
                        monster_gen__spawnInterval,
                        monster_gen__spawnIntervalKoef,
                        monster_gen__respawnInterval,
                        monster_gen__maxConsecutiveFails,
                        monster_gen__underwaterGenAllowed,
                        monster_gen__onlyAccessiblePolygons,
                        monster_gen__ignoreForbiddenZones,
                        monster_gen__curCount,
                        monster_gen__consecutiveFails,
                        monster_gen__spawnComplete,
                        monster_gen__updateAt,
                        transform[3],
                        diag) <| $()
    return transform[3] + transform[0] * rnd_float(-0.5, 0.5) + transform[1] * rnd_float(-0.5, 0.5) + transform[2] * rnd_float(-0.5, 0.5)
  lpipe <| $(pos : float3)
    return is_inside_tm(pos, transform)
  lpipe <| $ [unused_argument(_)] (_){}


def monster_gen_procedure(act : ParallelUpdateFrameDelayed;
                          eid : EntityId;
                          monster_gen__genGenEid : EntityId;
                          monster_gen__templates : StringList;
                          monster_gen__useGravity : bool;
                          monster_gen__maxCount : int;
                          monster_gen__minProximity : float;
                          monster_gen__checkPlayersRadius : float;
                          monster_gen__spawnInterval : float;
                          monster_gen__spawnIntervalKoef : float = 1.0;
                          monster_gen__respawnInterval : float;
                          monster_gen__maxConsecutiveFails : int;
                          monster_gen__underwaterGenAllowed : bool;
                          monster_gen__onlyAccessiblePolygons : bool;
                          monster_gen__ignoreForbiddenZones : bool;
                          var monster_gen__curCount : int&;
                          var monster_gen__consecutiveFails : int&;
                          var monster_gen__spawnComplete : bool&;
                          var monster_gen__updateAt : float&;
                          center : float3;
                          radius : float;
                          get_rnd_point : block<() : float3>;
                          verify_rnd_point : block<(pos : float3) : bool>;
                          init_entity : block<(var init : ComponentsInitializer) : void>)
  if length(monster_gen__templates) == 0
    logerr_once("{getEntityTemplateName(eid)} has no templates to spawn monsters.")
    return

  let hasPlayersNear = find_query() <| $ [es(REQUIRE=heroForPlayer, REQUIRE_NOT=am_militant_bot)] (transform : float3x4)
    return distance_sq(transform[3], center) < square(monster_gen__checkPlayersRadius + radius)
  let spawnAllowed = !monster_gen__spawnComplete || !hasPlayersNear
  var existingMonsters : array<float3>
  if spawnAllowed
    find_query() <| $ [es] (generated_monster__genEid : EntityId; transform : float3x4)
      if generated_monster__genEid == eid
        existingMonsters |> push(transform[3])
      return length(existingMonsters) >= monster_gen__maxCount
  let monsterCount = monster_gen__curCount
  if monsterCount < monster_gen__maxCount && spawnAllowed
    var forbiddenSphereZones : array<float4>
    if !monster_gen__ignoreForbiddenZones
      query() <| $ [es] (monster_generator_forbidden_zone__radius : float;
                         transform : float3x4)
        if distance_sq(transform[3], center) < square(monster_generator_forbidden_zone__radius + radius)
          forbiddenSphereZones |> push(float4(transform[3], square(monster_generator_forbidden_zone__radius)))

    var forbiddenByGenGen : array<float3x4>
    query(monster_gen__genGenEid) <| $ [es] (monster_gen_gen__excludeBoxes : TMatrixList)
      for tm in monster_gen_gen__excludeBoxes
        forbiddenByGenGen |> push(tm)

    var tries = 4
    while tries-- > 0
      monster_gen__consecutiveFails++
      let rndPoint = invoke(get_rnd_point)
      var pos = rndPoint

      var poly : dtPolyRef
      let mappingZone = navmesh_mapping_find_best_zone_for_position(pos)
      pos = navmesh_map_position_in_zone(pos, mappingZone)

      if !project_to_nearest_navmesh_point(pos, float3(1.5, 50.0, 1.5), poly)
        continue

      var isPosInForbiddenZone = false
      for forbiddenSphereZone in forbiddenSphereZones
        if distance_sq(pos, forbiddenSphereZone.xyz) < forbiddenSphereZone.w
          isPosInForbiddenZone = true
          break

      if isPosInForbiddenZone
        continue

      for forbiddenByGenGenTm in forbiddenByGenGen
        if is_inside_tm(pos, forbiddenByGenGenTm)
          isPosInForbiddenZone = true
          break

      if isPosInForbiddenZone
        continue

      if !monster_gen__underwaterGenAllowed
        var isUnderwater = false
        if !is_valid_water_height(traceht_water_at_time(pos, 0.0, act.curTime, isUnderwater))
          isUnderwater = false

        if isUnderwater
          continue

      pos = navmesh_unmap_position_in_zone(pos, mappingZone)
      validate_gameplay_position(pos) <| $()
        return <- "mappingZone={mappingZone}"
      let isValidPoly = monster_gen__onlyAccessiblePolygons ? is_polygon_accessible(poly) : true
      if isValidPoly && invoke(verify_rnd_point, pos)
        if monster_gen__minProximity == .0 || check_proximity_constraint(existingMonsters, pos, monster_gen__minProximity)
          monster_gen__consecutiveFails = 0
          existingMonsters |> push(pos)
          let tmplIdx = grnd() % length(monster_gen__templates)
          let tmpl = add_sub_template_name(string(monster_gen__templates[tmplIdx]), "generated_monster")

          if pos.y <= get_DESTROY_ENTITY_FLOOR_Y()
            logerr("{get_entity_info(eid)}: pos.y is below DESTROY_ENTITY_FLOOR_Y! pos={pos}, rndPoint={rndPoint}, tmpl={tmpl}")

          monster_gen__curCount++
          createEntity(tmpl) <| $(init)
            init |> set("generated_monster__genEid", eid)
            let up = monster_gen__useGravity ? -get_grav_dir(pos) : float3(0.0, 1.0, 0.0)
            let globalForward = get_normal(up)
            let globalRight = cross(globalForward, up)

            let initialLookAngle = gfrnd() * TWOPI
            var s, c : float
            sincos(initialLookAngle, s, c)

            let forward = s * globalForward + c * globalRight
            let right = cross(forward, up)

            var tm = IDENT_TM
            tm[0] = forward
            tm[1] = up
            tm[2] = right
            tm[3] = pos
            init |> set("transform", tm)
            invoke(init_entity, init)
          break
  monster_gen__spawnComplete ||= monsterCount == monster_gen__maxCount
  monster_gen__spawnComplete ||= monster_gen__consecutiveFails > monster_gen__maxConsecutiveFails
  let useLongInterval = monster_gen__spawnComplete || hasPlayersNear || monsterCount == monster_gen__maxCount
  assume spawnInterval = monster_gen__spawnInterval * monster_gen__spawnIntervalKoef
  monster_gen__updateAt = act.curTime + (useLongInterval ? monster_gen__respawnInterval : spawnInterval)


[es(tag=server, on_disappear)]
def monster_gen_disappear(evt : Event;
                          eid aka generator_eid : EntityId;
                          monster_gen__destroyGeneratedEntitiesOnDestroy : bool)
  if monster_gen__destroyGeneratedEntitiesOnDestroy
    query() <| $ [es] (eid, generated_monster__genEid : EntityId)
      if generated_monster__genEid == generator_eid
        destroyEntity(eid)


def check_proximity_constraint(list : array<float3>; pos : float3; min_proximity : float)
  for p in list
    if distance_sq(p, pos) < square(min_proximity)
      return false
  return true


[es(tag=server, on_disappear)]
def update_gen_monster_count_on_monster_disappear(evt : Event;
                                                  generated_monster__genEid : EntityId)
  query(generated_monster__genEid) <| $ [es] (var monster_gen__curCount : int&)
    monster_gen__curCount--

require ecs
require ecs.safe
require app
require math.base
require math.random
require DagorRandom
require DagorMath
require Grid
require DngDm
require DngNet
require BehNodes
require pathfinder
require debug.logerr_once
require game.es.ecs_common
require game.events.events_game
require game.es.grav_zones_common
require game.events.events_active_matter
require active_matter.game.utils.poly_area
require game.es.ai.agent_position_mapping_common


[es(tag=server, on_appear)]
def init_star_cluster(evt : Event;
                      eid : EntityId;
                      transform : float3x4;
                      star_cluster__spawnCount : int;
                      star_cluster__initAttemptsPerSpawn : int;
                      star_cluster__rayCount : int;
                      star_cluster__radius : float;
                      star_cluster__minProximity : float;
                      var star_cluster__initAttemptsLeft : int&;
                      var star_cluster__angle : float&;
                      var star_cluster__seed : int&)
  if star_cluster__seed == 0
    star_cluster__seed = grnd()
  star_cluster__angle = _rnd_float(star_cluster__seed, 0.0, PI * 2.0)
  star_cluster__initAttemptsLeft = star_cluster__initAttemptsPerSpawn * star_cluster__spawnCount
  let theoreticalMaxSpawns = int(float(star_cluster__rayCount) * (star_cluster__radius - star_cluster__minProximity) / star_cluster__minProximity)
  if theoreticalMaxSpawns < star_cluster__spawnCount * 2
    logerr("'{getEntityTemplateName(eid)}' at {transform[3]} will take very long time to init or will fail to init. Too many spawns required for such a small area. Max possible ~= {theoreticalMaxSpawns} required: {star_cluster__spawnCount}")


[es(tag=server, no_order)]
def update_star_cluster(act : UpdateStageInfoAct;
                        eid : EntityId;
                        transform aka field_transform : float3x4;
                        star_cluster__rayCount : int;
                        star_cluster__radius : float;
                        star_cluster__angle : float;
                        star_cluster__spawnCount : int;
                        star_cluster__rndSpawnRadius : float;
                        star_cluster__minProximity : float;
                        star_cluster__playerCheckRadius : float;
                        star_cluster__interval : float;
                        star_cluster__initInterval : float;
                        star_cluster__spawnTemplates : StringList;
                        star_cluster__grid : string;
                        star_cluster__allowIsleSpawns : bool;
                        star_cluster__triggeredDuration  = .0;  //TODO hide in 'initObject'
                        star_cluster__supressErrors : bool = true;
                        var star_cluster__curCount : int&;
                        var star_cluster__initAttemptsLeft : int&;
                        var star_cluster__inited : bool&;
                        var star_cluster__seed : int&;
                        var star_cluster__updateAt : float&)
  if star_cluster__updateAt < act.curTime
    if !star_cluster__inited && star_cluster__initAttemptsLeft < 0
      if !star_cluster__supressErrors
        logerr_once("Star cluster '{getEntityTemplateName(eid)}' at {transform[3]} can't spawn enough '{star_cluster__spawnTemplates}'.")
      destroyEntity(eid)
      return
    star_cluster__updateAt = act.curTime + (star_cluster__inited ? star_cluster__interval : star_cluster__initInterval)

    if star_cluster__curCount < star_cluster__spawnCount
      if !are_grav_zones_loaded()
        return

      let hasPlayersNear = find_query() <| $ [es(REQUIRE=heroForPlayer)] (transform aka player_transform : float3x4)
        return distance_sq(field_transform[3], player_transform[3]) < square(star_cluster__playerCheckRadius)
      if !hasPlayersNear || !star_cluster__inited
        star_cluster__initAttemptsLeft--
        let rayIdx = _rnd_int(star_cluster__seed, 0, star_cluster__rayCount)
        let r = sqrt(_rnd_float(star_cluster__seed, 0.0, square(star_cluster__radius)))
        let angle = star_cluster__angle + float(rayIdx) / float(star_cluster__rayCount) * 2.0 * PI
        var s, c : float
        sincos(angle, s, c)
        let gravTm = get_grav_tm(transform[3])
        let rndOffset = rnd_point_on_disk(star_cluster__rndSpawnRadius)
        var pos = transform[3] + (r * s + rndOffset.x) * gravTm[0] + (r * c + rndOffset.y) * gravTm[2]

        let mappingZone = navmesh_mapping_find_best_zone_for_position(pos)
        var ref : dtPolyRef
        pos = navmesh_map_position_in_zone(pos, mappingZone)
        let navProjectionSuccessful = project_to_nearest_navmesh_point(pos, float3(star_cluster__rndSpawnRadius), ref)
        pos = navmesh_unmap_position_in_zone(pos, mappingZone)
        validate_gameplay_position(pos) <| $()
          return <- "transform={transform}, mappingZone={mappingZone}"

        if navProjectionSuccessful
          var area : uint8
          get_poly_area(ref, area)
          if area != uint8(int(AMPolyArea.POLYAREA_WALKABLE_ISLE)) || star_cluster__allowIsleSpawns
            let hasAnotherEntity = find_entity_in_grid(ecs_hash(star_cluster__grid), BSphere3(pos, star_cluster__minProximity), GridEntCheck.POS) <| $ [unused_argument(_)] (_ : EntityId)
              return true
            if !hasAnotherEntity
              let inForbiddenZone = find_query() <| $ [es] (monster_generator_forbidden_zone__radius : float;
                                                            transform : float3x4)
                return distance_sq(transform[3], pos) < square(monster_generator_forbidden_zone__radius)

              if !inForbiddenZone
                star_cluster__curCount++
                assume spawnTemplate = star_cluster__spawnTemplates[rnd_int(0, length(star_cluster__spawnTemplates) - 1)]
                createEntity(string(spawnTemplate)) <| $(init)
                  var tm = get_grav_tm(pos)
                  var tmRot = IDENT_TM
                  rotyTM(rnd_float(0.0, TWOPI), tmRot)
                  tm = tm * tmRot
                  init |> set("transform", tm)
                  init |> set("spawnling__clusterEid", eid)
                  init |> set("spawnling__triggeredDuration", star_cluster__triggeredDuration)
    else
      star_cluster__inited = true


[es(tag=server, on_disappear)]
def update_star_cluster_count_on_spawnling_disappear(evt : Event;
                                                     spawnling__clusterEid : EntityId)
  query(spawnling__clusterEid) <| $ [es] (var star_cluster__curCount : int&)
    star_cluster__curCount--


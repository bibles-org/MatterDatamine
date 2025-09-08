require ecs
require ecs.safe
require Dacoll
require math
require math.base
require gameObject
require DagorRandom
require DagorSystem
require ecs.common
require strings
require pathfinder
require DagorMath
require game.es.grav_zones_common


[es(on_event=EventGameObjectsCreated, tag=server)]
def indoor_monster_spawner(evt : Event; eid : EntityId;
                           indoor_spawner__templateObjectList : Array;
                           indoor_spawner__count : int;
                           indoor_spawner__useMovingZone : Tag const?;
                           indoor_spawner__createOnComplete : string = "";
                           indoor_spawner__roomWallLengthLimits = float2(0);
                           indoor_spawner__spawnOutsideMovingZoneDist = 50f;
                           indoor_spawner__maxTries = 1)
  var spawnedCount = 0
  find_query() <| $ [es] (game_objects : GameObjects)
    let enviProbes = game_objects |> get_scene_game_objects_by_name("envi_probe_box")
    let enviProbesCount = enviProbes != null ? tiled_scene_getNodesCount(*enviProbes) : 0u
    if enviProbesCount == 0u
      return true

    var excludeBoxeItms : array<float3x4>
    query() <| $ [es(REQUIRE=indoor_spawner__excludeZone)] (transform : float3x4)
      excludeBoxeItms |> push(inverse(transform))
    print("indoor_spawner: found {length(excludeBoxeItms)} exclude boxes")

    let useMovingZone = indoor_spawner__useMovingZone != null
    var movingZoneCenter =  float3()
    var movingZoneRadiusSq = FLT_MAX
    let hasMovingZone = useMovingZone && find_query() <| $ [es] (transform : float3x4; moving_zone__sourceRadius : float)
      movingZoneCenter = transform[3]
      movingZoneRadiusSq = square(moving_zone__sourceRadius + indoor_spawner__spawnOutsideMovingZoneDist)
      print("indoor_spawner: found moving zone {movingZoneCenter} radius: {moving_zone__sourceRadius}")
      return true
    if useMovingZone && !hasMovingZone
      logerr("indoor_spawner: unable to find moving zone, will be used full map to spawn creatures")

    for _ in range(indoor_spawner__count)
      var tries = max(1, indoor_spawner__maxTries)
      while tries-- > 0
        let idx = uint(grnd()) % enviProbesCount
        let roomTm = tiled_scene_getNode(*enviProbes, tiled_scene_getNodeFromIndex(*enviProbes, idx))

        if hasMovingZone && distance_sq(roomTm.col3.xyz, movingZoneCenter) > movingZoneRadiusSq
          continue

        if length(excludeBoxeItms) > 0
          var excludeThisPos = false
          for excludeItm in excludeBoxeItms
            if IDENT_BBOX & (excludeItm * roomTm.col3.xyz)
              excludeThisPos = true
              break
          if excludeThisPos
            continue

        // prerequisite
        assume wallLimit = indoor_spawner__roomWallLengthLimits
        if wallLimit.x > 0f || wallLimit.y > 0f
          let lenSqX = length_sq(roomTm.col0.xyz)
          let lenSqZ = length_sq(roomTm.col2.xyz)
          if ((wallLimit.x > 0f && (lenSqX < square(wallLimit.x) || lenSqZ < square(wallLimit.x)))
           || (wallLimit.y > 0f && (lenSqX > square(wallLimit.y) || lenSqZ > square(wallLimit.y))))
            continue

        tries = 0
        spawnedCount++

        var tm = IDENT_TM
        let angle = gfrnd() * TWOPI
        tm[0] = float3(cos(angle), 0.0, sin(angle))
        tm[2] = float3(-tm[0].z, 0.0, tm[0].x)
        tm[1] = cross(tm[2], tm[0])
        tm[3] = roomTm.col3.xyz

        var navmeshPos = float3(FLT_MAX)
        for itemData in indoor_spawner__templateObjectList
          let itemRef = get_ecs_object(itemData)
          assume item = *itemRef
          let itemTemplate = get_string(item, "template", "")
          var itemTm := tm

          let projectToNavmesh = item.projectToNavmesh ?? false
          if projectToNavmesh
            if navmeshPos.x < FLT_MAX
              itemTm[3] = navmeshPos
            else
              var pos = itemTm[3] - float3(0., 1.0, 0.)
              if project_to_nearest_navmesh_point(pos, float3(1.0))
                navmeshPos = pos
                itemTm[3] = pos
              elif project_to_nearest_navmesh_point(pos, float3(2.0)) // for huge halls
                navmeshPos = pos
                itemTm[3] = pos
            let down = get_grav_dir(itemTm[3])
            var t = 1.0
            var norm : float3
            if traceray_normalized(itemTm[3], down, t, norm, ETF_DEFAULT)
              itemTm[3] += down * t
          let offset = item |> get_Point3("offset")
          if offset != null
            var rotTm : float3x4
            rotTm[0] = normalize(roomTm.col0.xyz)
            rotTm[1] = normalize(roomTm.col1.xyz)
            rotTm[2] = normalize(roomTm.col2.xyz)
            itemTm[3] += rotTm * (*offset)
          if item.alignToWalls ?? false
            itemTm[0] = roomTm.col0.xyz
            itemTm[1] = roomTm.col1.xyz
            itemTm[2] = roomTm.col2.xyz
          let inflateBox = get_Point3(item, "inflateBox")
          if inflateBox != null
            for j in range(3)
              let axisLen = length(itemTm[j])
              itemTm[j] *= safediv(axisLen + (*inflateBox)[j], axisLen)
          if item.sync ?? false
            createEntitySync(itemTemplate) <| $(var init)
              init |> set("transform", itemTm)
              init |> set("indoor_spawner__inflatedBox", inflateBox ?? float3())
          else
            createEntity(itemTemplate) <| $(var init)
              init |> set("transform", itemTm)
              init |> set("indoor_spawner__inflatedBox", inflateBox ?? float3())

    return true

  if !empty(indoor_spawner__createOnComplete)
    createEntitySync(indoor_spawner__createOnComplete)
  destroyEntity(eid)
  let msg = "indoor_spawner: {eid}:{getEntityTemplateName(eid)} spawned: {spawnedCount} required: {indoor_spawner__count}"
  if indoor_spawner__count > 0 && spawnedCount == 0
    logerr(msg)
  else
    print(msg)
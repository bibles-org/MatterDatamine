require ecs
require ecs.safe
require app
require ecs.common
require math.base
require math.random
require level
require DagorMath
require DagorRandom
require DagorSystem
require gameObject
require game.es.custom_region_common
require game.es.grav_zones_common


def validate_monster_regions_exist(eid : EntityId;
                                   monster_gen_gen__regions : StringList&;
                                   monster_gen_gen__generators : Array&)
  for monsterRegionName in monster_gen_gen__regions
    var monsterRegionExists = false
    in_region_with_name(string(monsterRegionName)) <| $ [unused_argument(a1, a2, a3)] (a1, a2, a3)
      monsterRegionExists = true
    if !monsterRegionExists
      var mosterGenType = ""
      for gen in monster_gen_gen__generators
        var genType = (gen as Object)?.genType ?? ""
        if genType == ""
          genType = (gen as Object)?["template"] ?? ""
        if mosterGenType != ""
          mosterGenType += "+"
        mosterGenType += genType
      logerr("{eid} <{getEntityTemplateName(eid)}>: Region '{monsterRegionName}' is not exists! generators={mosterGenType}")


[es(tag=server, on_appear, on_event=(EventRetriggerEntity, CmdRegenMonsterGen))]
def init_regional_monster_gen_gen(evt : Event;
                                  eid : EntityId;
                                  monster_gen_gen__generators : Array;
                                  monster_gen_gen__regions : StringList)
  var canStart = false
  find_query() <| $ [es] (var level__retriggerEids : EidList;
                          level__gameObjectsEntitiesCreated,
                          level__navmeshIslandsMarked,
                          level__navmeshIslandsMarkerAppeared,
                          level__movingZoneInited,
                          level__movingZoneAppeared : bool)
    if (level__gameObjectsEntitiesCreated &&
        level__navmeshIslandsMarked == level__navmeshIslandsMarkerAppeared &&
        level__movingZoneInited == level__movingZoneAppeared)
      canStart = true
    else
      level__retriggerEids |> push(eid)
    return true
  if !canStart
    return

  var zonePos = float3()
  var zoneRadius = 2000.0
  find_query() <| $ [es] (moving_zone__sourceRadius : float; moving_zone__sourcePos : float3)
    zonePos = moving_zone__sourcePos
    zoneRadius = moving_zone__sourceRadius
    return true

  // Filter regions by being in the zone and than randomizing
  var availableRegions : array<string>
  validate_monster_regions_exist(eid, monster_gen_gen__regions, monster_gen_gen__generators)
  query() <| $ [es] (custom_region__name : string; transform : float3x4)
    let radius = length(0.5 * (transform[0] + transform[2]))
    if distance_sq(transform[3], zonePos) < square(zoneRadius + radius)
      if has_value(monster_gen_gen__regions, custom_region__name)
        availableRegions |> push(custom_region__name)
  shuffle(availableRegions)

  // Randomizing generator types - this way if there are less regions than generators, all types will spawn fairly
  var generatorTypes : array<int>
  for i in range(0, length(monster_gen_gen__generators))
    let count = (monster_gen_gen__generators[i] as Object)?.count ?? 0
    for _ in range(count)
      generatorTypes |> push(i)
  shuffle(generatorTypes)

  var typeI = length(generatorTypes)
  var regionI = length(availableRegions)
  while --typeI >= 0 && --regionI >= 0
    let gen = monster_gen_gen__generators[generatorTypes[typeI]] as Object
    let templ = gen?["template"] ?? ""
    let genType = gen?.genType ?? ""
    createEntity(templ) <| $(init)
      init |> set("regional_generator__region", availableRegions[regionI])
      init |> set("monster_gen__genGenEid", eid)
      if genType != "" // monster_gen__type override is optional
        init |> set("monster_gen__type", genType)


[unused_argument(level__loadingGen), es(tag=server, on_event=(CmdRegenMonsterGen), track=level__loadingGen)]
def init_household_monster_gen_gen(evt : Event; level__loadingGen : int;
                                   level__gameObjectsEntitiesCreated, level__movingZoneInited, level__movingZoneAppeared, level__navmeshIslandsMarked : bool)
  if !level__gameObjectsEntitiesCreated || (level__movingZoneInited != level__movingZoneAppeared) || !level__navmeshIslandsMarked
    return
  find_query() <| $ [es] (moving_zone__sourceRadius : float; moving_zone__sourcePos : float3)
    query() <| $ [es] (monster_gen_gen__householdCount : int; eid : EntityId;
                       monster_gen_gen__useHouseholdsOnEuclid : bool;
                       monster_gen_gen__minHouseholdVolume : float;
                       monster_gen_gen__type : string;
                       monster_gen_gen__genTemplates : Object)
      let box = BBox3(moving_zone__sourcePos, moving_zone__sourceRadius * 2f)
      let maxDistanceSq = square(moving_zone__sourceRadius)
      var households : array<float3x4>
      var count = 0
      let gameObjectsEid = getSingletonEntity("game_objects")
      query(gameObjectsEid) <| $ [es] (game_objects : GameObjects)
        game_objects.indoors |> for_scene_game_objects(box) <| $ [unused_argument(ni)] (ni : uint; tm_tmp : float3x4#)
          let tm : float3x4 := tm_tmp
          if distance_sq(tm[3], moving_zone__sourcePos) < maxDistanceSq
            count++
            let volume = tm_volume(tm)
            if volume > monster_gen_gen__minHouseholdVolume
              var shouldAdd = true
              for idx in iter_range(households)
                let h = households[idx]
                if is_tm_intersects_tm(h, tm)
                  shouldAdd = false
                  if volume > tm_volume(h)
                    households[idx] = tm //for now simply chose the larger household. But idealy they should be joined somehow.
              if shouldAdd
                let isInAlteredGravity = find_gravity_zone(tm[3]) != INVALID_ENTITY_ID
                if monster_gen_gen__useHouseholdsOnEuclid ^^ isInAlteredGravity
                  return
                households |> push(tm)

      print("Total non-intersecting households: {length(households)}. Total households within zone: {count}")
      shuffle(households)
      var countToGen = min(monster_gen_gen__householdCount, length(households))
      var totalWeight = 0
      for templ in monster_gen_gen__genTemplates
        totalWeight += get_int(templ.value) ?? 0
      while countToGen-- > 0
        let rndVal = rnd_int(0, totalWeight)
        var acc = 0
        var templateName = ""
        for templ in monster_gen_gen__genTemplates
          acc += get_int(templ.value) ?? 0
          if rndVal <= acc
            templateName = templ.key
            break
        assume tm = households[countToGen]
        createEntity(string(templateName)) <| $(init)
          init |> set("transform", tm)
          init |> set("nmesh_voxel__gridSize", int3(max(1.0, length(tm[0]) / 2.0), max(1.0, length(tm[1]) / 2.0), max(1.0, length(tm[2]) / 2.0))) // 2.0 - gridStep
          init |> set("monster_gen__type", monster_gen_gen__type)
          init |> set("monster_gen__genGenEid", eid)
      if int(float(length(households)) * 1.1) < monster_gen_gen__householdCount
        logerr("[Monster Generator] Total avaliable household count <{length(households)}> 10% less then required household count <{monster_gen_gen__householdCount}>. Adjust the generator more precisely.")
    return true


[es(tag=server, on_appear, on_event=EventRetriggerEntity)]
def init_region_monster_gen(evt : Event;
                            eid : EntityId;
                            regional_generator__region : string;
                            monster_gen__density : float2;
                            monster_gen__respawnInterval : float;
                            var monster_gen__maxCount : int&;
                            var monster_gen__updateAt : float&)
  if wake_me_up_when_monster_gen_prerequisites_are_loaded(eid)
    return
  in_region_with_name(regional_generator__region) <| $ [unused_argument(a1, a2)] (a1, a2, data)
    monster_gen__maxCount = int(ceil(rnd_float(monster_gen__density) * data.area))
  monster_gen__updateAt = get_sync_time() + monster_gen__respawnInterval * eid_frnd(eid)

//Note: works for this case but not in general. Edge to edge intersection is not detected.
def is_tm_intersects_tm(a, b : float3x4) : bool
  if distance_sq(a[3], b[3]) > 0.25 * (length_sq(a[0] + a[1] + a[2]) + length_sq(b[0] + b[1] + b[2]))
    return false
  let m <- fixed_array(-1.0, 1.0)
  for x in m
    for y in m
      for z in m
        if is_inside_tm(a[3] + a[0] * x + a[1] * y + a[2] * z, b)
          return true
  return false


[es(tag=server, on_appear)]
def init_monster_gen_household_bbox(evt : Event; transform : float3x4; var monster_gen__bboxMin, monster_gen__bboxMax : float3&)
  let bbox = transform * BBox3(float3(), 1.0)
  monster_gen__bboxMin = bbox.boxMin
  monster_gen__bboxMax = bbox.boxMax


[es(tag=server, on_appear, on_event=EventRetriggerEntity)]
def init_tm_monster_gen(evt : Event;
                        eid : EntityId;
                        transform : float3x4;
                        monster_gen__density : float2;
                        monster_gen__respawnInterval : float;
                        var monster_gen__maxCount : int&;
                        var monster_gen__updateAt : float&)
  if wake_me_up_when_monster_gen_prerequisites_are_loaded(eid)
    return
  monster_gen__maxCount = int(ceil(rnd_float(monster_gen__density) * tm_volume(transform)))
  monster_gen__updateAt = get_sync_time() + monster_gen__respawnInterval * eid_frnd(eid)


def wake_me_up_when_monster_gen_prerequisites_are_loaded(eid : EntityId)
  var prereqLoaded = false
  find_query() <| $ [es] (var level__retriggerEids : EidList;
                          level__gameObjectsEntitiesCreated : bool;
                          level__navmeshIslandsMarked : bool;
                          level__levelLoaded : bool;
                          level__navmeshIslandsMarkerAppeared : bool)
    prereqLoaded = (level__gameObjectsEntitiesCreated &&
                    level__levelLoaded &&
                    level__navmeshIslandsMarked == level__navmeshIslandsMarkerAppeared)
    if !prereqLoaded
      level__retriggerEids |> push(eid)
    return true
  return !prereqLoaded
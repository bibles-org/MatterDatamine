require ecs
require ecs.common
require ecs.safe
require math.base
require math.random
require strings
require DagorSystem
require DagorMath
require Dacoll
require DngNet
require game.es.grav_zones_common
require game.es.level_common
require game.utils.team
require game.es.ecs_common
require pathfinder
require game.es.ai.agent_position_mapping_common
require game.es.anomalies.anomaly_zones_common
require game.events.events_active_matter
require game.es.truce_common
require danetlibs.pathfinder.main.pathfinder_common
require PhysMat
require DagorDebug3DSolid
require DagorDebug3D


[es(tag=server, on_appear)]
def interesting_encounter_appear(evt : Event;
                                 interesting_encounter__dropRayMat : string;
                                 var interesting_encounter__dropRayMatId : int&)
  interesting_encounter__dropRayMatId = get_material_id(interesting_encounter__dropRayMat)


[es(tag=server, on_appear, REQUIRE=interesting_encounter__blueprint)]
def on_interesting_encounter_appear(evt : Event; eid : EntityId; transform : float3x4)
  print("Interesting encounter <{eid}>'{getEntityTemplateName(eid)}' at {transform[3]}")


[es(on_appear, on_event=EventRetriggerEntity, REQUIRE=interesting_encounter__blueprint)]
def try_start_interesting_encounter(evt : Event; eid : EntityId)
  if wake_me_up_when_gravzones_are_loaded(eid)
    return
  try_ceate_next_encounter_layer(eid)


def try_ceate_next_encounter_layer(eid : EntityId)
  let isTrueServer = is_true_net_server()
  let isOffline = is_server() && !isTrueServer
  let isNetClient = !isOffline && !isTrueServer

  query(eid) <| $ [es] (transform : float3x4;
                        monster_gen__genGenEid : EntityId;
                        var interesting_encounter__blueprint : Array;
                        var interesting_encounter__currentLayer : int&;
                        var interesting_encounter__itemsLeft : int&;
                        var interesting_encounter__creationFinished : bool&;
                        var interesting_encounter__creationStarted : bool&;
                        var interesting_encounter__dQueryEntities : EidList;
                        interesting_encounter__addFromBranches : Array;
                        interesting_encounter__dQueryQueueTemplate : string;
                        interesting_encounter__ignoreScale : bool;
                        interesting_encounter__wipItemTemplate : string;
                        interesting_encounter__debug = false;
                        interesting_encounter__dropRayMatId : int = -1)
    if !interesting_encounter__creationStarted
      var seed = int(eid_frnd(eid) * float(INT_MAX))
      init_blueprint(interesting_encounter__blueprint,
                      monster_gen__genGenEid,
                      seed,
                      interesting_encounter__addFromBranches,
                      transform,
                      eid,
                      interesting_encounter__debug)
    interesting_encounter__creationStarted = true
    if interesting_encounter__itemsLeft == 0
      var nextLayer = INT_MAX
      for it in interesting_encounter__blueprint
        let bp = get_ecs_object(it)
        if bp == null
          continue
        let layer = get_int(bp, "layer") ?? 0
        if layer > interesting_encounter__currentLayer
          nextLayer = min(nextLayer, layer)
      if nextLayer == INT_MAX
        interesting_encounter__creationFinished = true
        if length(interesting_encounter__dQueryEntities) > 0 && get_grav_dir(transform[3]) == float3(0, -1, 0)
          let tmplName = add_sub_template_name(eid, interesting_encounter__dQueryQueueTemplate)
          remote_recreate_entity_from(eid, tmplName) <| $(var init)
            init |> set("interesting_encounter__dQueryQueue", interesting_encounter__dQueryEntities)
          clear(interesting_encounter__dQueryEntities)
        return
      for it, idx in interesting_encounter__blueprint, iter_range(interesting_encounter__blueprint)
        let bp = get_ecs_object(it)
        if bp == null
          continue

        assume isClientOnly = get_bool(bp, "clientOnly") ?? false
        let shouldCreate = isOffline || (isTrueServer && !isClientOnly) || (isNetClient && isClientOnly)

        let layer = get_int(bp, "layer") ?? 0
        if shouldCreate && layer > interesting_encounter__currentLayer && layer <= nextLayer
          let createdEid = createBlueprintEntity(*bp,
                                                  idx,
                                                  transform,
                                                  eid,
                                                  interesting_encounter__wipItemTemplate,
                                                  interesting_encounter__ignoreScale,
                                                  interesting_encounter__debug,
                                                  interesting_encounter__dropRayMatId)
          if createdEid != INVALID_ENTITY_ID
            interesting_encounter__itemsLeft++
            if get_bool(*bp, "compensateDisplacement") ?? false
              interesting_encounter__dQueryEntities |> push(createdEid)
      interesting_encounter__currentLayer = nextLayer


def createBlueprintEntity(bp : Object;
                          idx : int;
                          transform : float3x4;
                          eid : EntityId;
                          wip_item_template : string;
                          ignore_scale, debug_me : bool;
                          interesting_encounter__dropRayMatId : int)
  var notScaledTm := transform
  orthonormalize(notScaledTm)
  let templ = get_string(bp, "templ", "")
  if empty(templ)
    logerr("Some items in {getEntityTemplateName(eid)} don't have 'templ' field or it's empty.")
    return INVALID_ENTITY_ID
  let tm = get_TMatrix(bp, "transform") ?? IDENT_TM
  let precalculatedPos = get_bool(bp, "precalculatedPos") ?? false
  var finalTm : float3x4
  if precalculatedPos
    finalTm = tm
  else
    finalTm = notScaledTm * tm
    if !ignore_scale
      finalTm[3] = transform * tm[3]

  let dropOnNormal = get_bool(bp, "dropOnNormal") ?? false
  let dropOnCollision = get_bool(bp, "dropOnCollision") ?? false
  if !precalculatedPos && (dropOnNormal || dropOnCollision)
    var attempts = 3
    while attempts-- > 0
      var pmid = -1
      var riDesc = RendInstDesc()
      let grav = get_grav_dir(finalTm[3])
      let up = -grav
      let r = 0.1
      var bestT = 2.0
      var bestNormal = up
      let side1 = get_normal(up)
      let side2 = cross(up, side1)
      let traceOffsets <- fixed_array(float3(), side1 * r, -side1 * r, side2 * r, -side2 * r)
      let traceUpOffset = up * 0.5
      for offset in traceOffsets
        var t = 5.0
        var norm : float3
        let startPos = finalTm[3] + offset + traceUpOffset
        traceray_normalized(startPos, grav, t, pmid, norm, ETF_ALL, riDesc, interesting_encounter__dropRayMatId)
        if debug_me
          draw_debug_arrow_buffered(startPos + float3(0.1, 0.0, 0.1), startPos + grav * t + float3(0.1, 0.0, 0.1), E3DCOLOR(0xffffffff), 10000)
        if t < bestT
          bestT = t
          bestNormal = norm
      finalTm[3] = finalTm[3] + traceUpOffset + grav * bestT
      if dropOnNormal
        let q = quat_rotation_arc(up, bestNormal)
        finalTm[0] = q * finalTm[0]
        finalTm[1] = q * finalTm[1]
        finalTm[2] = q * finalTm[2]
      orthonormalize(finalTm)

      let mappingZone = navmesh_mapping_find_best_zone_for_position(finalTm[3])
      var poly : dtPolyRef
      var navPos = navmesh_map_position_in_zone(finalTm[3], mappingZone)
      project_to_nearest_navmesh_point(navPos, float3(1, 5, 1), poly)
      let mappedPos = navPos
      navPos = navmesh_unmap_position_in_zone(navPos, mappingZone)
      validate_gameplay_position(navPos) <| $()
        return <- "finalTm={finalTm}, mappingZone={mappingZone}"
      var tri : NavMeshTriangle
      if dropOnNormal && get_triangle_by_pos(mappedPos, 0.1f, tri)
        var navNorm = normalize(cross(tri.p1 - tri.p2, tri.p1 - tri.p0))
        navNorm = navmesh_unmap_direction_in_zone(navNorm, mappedPos, mappingZone)
        if abs(dot(bestNormal, navNorm)) < 0.8
          finalTm = notScaledTm * tm
          finalTm[3] += normalize(finalTm[3] - transform[3])
          continue
      let dropOnNavmesh = get_bool(bp, "dropOnNavmesh") ?? false
      if dropOnNavmesh
        finalTm[3] = navPos
      break

  let postAligmentOffset = get_Point3(bp, "postAligmentOffset") ?? float3()
  finalTm[3] = finalTm * postAligmentOffset

  let finalTemplate = add_sub_template_name(templ, wip_item_template)
  let createdEid = createEntity("{finalTemplate}+item_generated") <| $(init)
    init |> set("transform", finalTm)
    init |> set("beh_tree__blackboard__wanderTarget", transform[3])
    init |> set("report_to_encounter__encounterEid", eid)
    init |> set("encounter_item__encounterEid", eid)

  if debug_me
    draw_debug_text_mark_buffered(finalTm[3], "[{idx}] {templ}", 10000)
  return createdEid


[es(on_appear, after=riextra_spawn_ri_es)]
def report_encounter_item_created(evt : Event; eid, report_to_encounter__encounterEid : EntityId)
  query(report_to_encounter__encounterEid) <| $ [es] (interesting_encounter__wipItemTemplate : string; var interesting_encounter__itemsLeft : int&)
    interesting_encounter__itemsLeft--
    if interesting_encounter__itemsLeft == 0
      try_ceate_next_encounter_layer(report_to_encounter__encounterEid)
    removeSubTemplate(eid, interesting_encounter__wipItemTemplate)

def report_init_error(eid : EntityId; msg : string)
  logerr("[Interesting encounter init] <{eid}>({getEntityTemplateName(eid)}) {msg}")

def x0y(p2 : float2)
  return float3(p2.x, .0, p2.y)

def init_blueprint(var blueprint : Array;
                   monster_gen__genGenEid : EntityId;
                   var random_seed : int&;
                   branches_data : Array;
                   root_transform : float3x4;
                   eid : EntityId;
                   debug_me : bool)
  var spawnedPos : array<float3>
  let boundingRadiusSq = 1.0
  let boxSize = 2.0
  for branchInfo in branches_data
    let branch = get_ecs_object(branchInfo)
    if branch == null
      report_init_error(eid, "interesting_encounter__addFromBranches must contain objects")
      continue
    let templName = (*branch).templ ?? ""
    if empty(templName)
      report_init_error(eid, "One of the items in interesting_encounter__addFromBranches is missing 'templ' field")
      continue
    var templ = getTemplateByName(templName)
    if templ == null
      templ = buildTemplateByName(templName)
    if templ == null
      report_init_error(eid, "Template '{templName}' doesn't exist")
      continue
    let radius = (*branch).radius ?? FLT_MAX
    let verticalRadius = (*branch).verticalRadius ?? 1.0

    var forbiddenSphereZones : array<float4>
    query() <| $ [es] (monster_generator_forbidden_zone__radius : float;
                       transform aka f_transform : float3x4)
      if distance_sq(f_transform[3], root_transform[3]) < square(monster_generator_forbidden_zone__radius + radius)
        forbiddenSphereZones |> push(float4(f_transform[3], square(monster_generator_forbidden_zone__radius)))

    var forbiddenByGenGen : array<float3x4>
    query(monster_gen__genGenEid) <| $ [es] (monster_gen_gen__excludeBoxes : TMatrixList)
      for tm in monster_gen_gen__excludeBoxes
        forbiddenByGenGen |> push(tm)

    let importPresets = get_ecs_object(getTemplateComponent(*templ, "anomaly_zone__spawnPresets"))
    if importPresets == null
      report_init_error(eid, "'{templName}' doesn't contain anomaly_zone__spawnPresets component")
      continue
    let groups = get_ecs_array(getTemplateComponent(*templ, "anomaly_zone__spawnGroups"))
    if groups == null
      report_init_error(eid, "'{templName}' doesn't contain anomaly_zone__spawnGroups component")

    var presets : table<string; SpawnPreset>
    parse_spawn_presets(*importPresets, presets)

    for g in *groups
      let spawnGroup = get_ecs_object(g)
      if spawnGroup == null
        report_init_error(eid, "'{templName}' contains a spawnGroup which isn't an object")
        continue
      let presetName = (*spawnGroup).preset ?? ""
      if !key_exists(presets, presetName)
        report_init_error(eid, "'{templName}' has unknown preset name '{presetName}'. Skip it")
        continue
      let spawnCountRange = (*spawnGroup).spawnCount ?? int2(10, 10)
      let spawnCount = ceili(float(_rnd_int(random_seed, spawnCountRange.x, spawnCountRange.y)))
      presets |> get(presetName) <| $(preset)
        var spawned = 0
        var tries = 2 * spawnCount * (spawnCount + 1)
        while spawned < spawnCount && --tries > 0
          let horOffset = x0y(rnd_point_on_disk(random_seed, radius))
          let vertOffset = float3(.0, verticalRadius * _rnd_float(random_seed, -1.0, 1.0), .0)
          let rootPos = root_transform[3] + horOffset + vertOffset
          var pos = rootPos
          var poly : dtPolyRef
          if !project_to_nearest_navmesh_point(pos, float3(1.0, 2.5, 1.0), poly)
            continue
          if !is_polygon_accessible(poly)
            continue

          var tooClose = false
          for alreadySpawnedP in spawnedPos
            if distance_sq(alreadySpawnedP, pos) < boundingRadiusSq
              tooClose = true
              break
          if !tooClose
            for forbZone in forbiddenSphereZones
              if distance_sq(forbZone.xyz, pos) < forbZone.w
                tooClose = true
                break
          if !tooClose
            for forbBox in forbiddenByGenGen
              if is_inside_tm(pos, forbBox)
                tooClose = true
                break
          if !tooClose
            spawnedPos |> push(pos)
            spawned++
            for spawnPreset in preset.items
              var itemTm = IDENT_TM
              itemTm[3] = spawnPreset.projectToNavmesh ? pos : rootPos
              let down = get_grav_dir(itemTm[3])
              var t = 1.0
              var norm : float3
              if spawnPreset.projectToNavmesh && traceray_normalized(itemTm[3], down, t, norm, ETF_DEFAULT)
                itemTm[3] += down * t
              if spawnPreset.spawnIndoor != null && (*spawnPreset.spawnIndoor) != level_common::is_pos_indoor(itemTm[3])
                continue
              using() <| $ [es] (var newBp : Object)
                if spawnPreset.targetScale != null
                  for j in range(3)
                    itemTm[j] *= (*spawnPreset.targetScale)[j]
                if spawnPreset.scaleToBox
                  itemTm[0] = float3(boxSize, 0., 0.)
                  itemTm[1] = float3(0., boxSize, 0.)
                  itemTm[2] = float3(0., 0., boxSize)
                newBp |> set("transform", itemTm)
                newBp |> set("templ", spawnPreset.templateName)
                newBp |> set("precalculatedPos", true)
                newBp |> set("clientOnly", spawnPreset.clientOnly)
                blueprint |> push(newBp)
                if debug_me
                  draw_debug_line_buffered(root_transform[3], itemTm[3], E3DCOLOR(0xffffffff), 10000)


[es(tag=server, REQUIRE=trigger_encounter_guards_on_looted)]
def trigger_encounter_guards_on_hero_looted_container(evt : EventExternalInventoryContainerAccessedByHero;
                                                      encounter_item__encounterEid aka container_encounter_item__encounterEid : EntityId)
  query(evt.heroEid) <| $ [es] (team aka looter_team : int; truce_id aka looter_truce_id : int = -1)
    query() <| $ [es] (team aka guard_team : int;
                       truce_id aka guard_truce_id : int = -1;
                       encounter_item__encounterEid aka guard_encounter_item__encounterEid : EntityId;
                       var personal_enemies__enemies : EidList)
      if (container_encounter_item__encounterEid == guard_encounter_item__encounterEid &&
          guard_encounter_item__encounterEid != INVALID_ENTITY_ID)
        if !is_hostile(guard_team, guard_truce_id, personal_enemies__enemies, evt.heroEid, looter_team, looter_truce_id)
          add_personal_enemy(personal_enemies__enemies, evt.heroEid)

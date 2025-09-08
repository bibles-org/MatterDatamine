require ecs
require app
require Grid
require ecs.safe
require DagorMath
require math.base
require pathfinder
require math.random
require game.events.events
require danetlibs.renderer.includes.pufd_events
require game.es.ai.agent_position_mapping_common
require game.es.extraction_point.extraction_point_common


def is_safety_to_regenerate(zone_pos : float3; zone_rad : float)
  var result = true
  let sphere = BSphere3(zone_pos, zone_rad)
  for_each_entity_in_grid(ecs_hash("humans"), sphere, GridEntCheck.POS) <| $(human_eid : EntityId)
    query(human_eid) <| $ [es(REQUIRE_NOT=deadEntity)] (possessedByPlr : EntityId)
      result &&= possessedByPlr == INVALID_ENTITY_ID
  return result


[es(tag=server, on_appear)]
def init_guarded_zone(evt : Event;
                      eid : EntityId;
                      var guarded_zone__maxGuardsCount : int&;
                      var guarded_zone__guardTemplateNames : Object&)
  if length(guarded_zone__guardTemplateNames) > 0
    print("[GUARDED_ZONE] zone <{eid}> have initial guards templates>")
    return

  let founded = find_query() <| $ [es] (guarded_zones_avaliable_monsters__templateBuckets : Array)
    let bucketsArraySize = length(guarded_zones_avaliable_monsters__templateBuckets)
    if bucketsArraySize == 0
      return false
    let idx = rnd_int(0, bucketsArraySize - 1)
    let bucketObj = get_ecs_object(guarded_zones_avaliable_monsters__templateBuckets[idx])
    if bucketObj == null
      return false
    if guarded_zone__maxGuardsCount > 0
      guarded_zone__maxGuardsCount = max(1, ceili(float(guarded_zone__maxGuardsCount) * ((*bucketObj).difficultyMult ?? 1.0)))
    let bucketTemplatesObj = get_ecs_object((*bucketObj)["bucketTemplates"])
    if bucketTemplatesObj == null
      return false
    guarded_zone__guardTemplateNames := *bucketTemplatesObj
    print("[GUARDED_ZONE] zone <{eid}> inited from scene with idx <{idx}>")
    return true

  if !founded
    let templ = getTemplateByName("guarded_zones_avaliable_monsters")
    if templ == null
      error("[GUARDED_ZONE] zone <{eid}> can't init from missed template <guarded_zones_avaliable_monsters>")
      return
    let templateBuckets = getTemplateComponent(*templ, "guarded_zones_avaliable_monsters__templateBuckets")
    if templateBuckets == null
      error("[GUARDED_ZONE] zone <{eid}> can't init from template <guarded_zones_avaliable_monsters>, missed component <guarded_zones_avaliable_monsters__templateBuckets>")
      return
    let templateBucketsArr = get_ecs_array(*templateBuckets)
    if templateBucketsArr == null
      error("[GUARDED_ZONE] zone <{eid}> can't init from template <guarded_zones_avaliable_monsters>, missed component <guarded_zones_avaliable_monsters__templateBuckets>")
      return
    let bucketsArraySize = length(*templateBucketsArr)
    if bucketsArraySize == 0
      error("[GUARDED_ZONE] zone <{eid}> can't init from template <guarded_zones_avaliable_monsters>, empty <guarded_zones_avaliable_monsters__templateBuckets>")
      return
    let idx = rnd_int(0, bucketsArraySize - 1)
    let bucketObj = get_ecs_object((*templateBucketsArr)[idx])
    if bucketObj == null
      error("[GUARDED_ZONE] zone <{eid}> can't init from template <guarded_zones_avaliable_monsters>, not object on idx <{idx}> in <guarded_zones_avaliable_monsters__templateBuckets>")
      return
    if guarded_zone__maxGuardsCount > 0
      guarded_zone__maxGuardsCount = max(1, ceili(float(guarded_zone__maxGuardsCount) * ((*bucketObj).difficultyMult ?? 1.0)))
    let bucketTemplatesObj = get_ecs_object((*bucketObj)["bucketTemplates"])
    if bucketTemplatesObj == null
      error("[GUARDED_ZONE] zone <{eid}> can't init from template <guarded_zones_avaliable_monsters>, not object on idx <{idx}> in <guarded_zones_avaliable_monsters__templateBuckets>")
      return

    guarded_zone__guardTemplateNames := *bucketTemplatesObj
    print("[GUARDED_ZONE] zone <{eid}> inited from template with idx <{idx}>")


[es(tag=server)]
def guarded_zone_regeneration(act : ParallelUpdateFrameDelayed;
                              eid aka zone_eid : EntityId;
                              guarded_zone__maxGuardsCount : int;
                              guarded_zone__guardTemplateNames : Object;
                              guarded_zone__regenerationTime : float2;
                              guarded_zone__regenerationPart : float;
                              guarded_zone__playersCheckRadMult : float;
                              guarded_zone__active : bool;
                              transform : float3x4;
                              var guarded_zone__nextRegenerationAt : float&;
                              var guarded_zone__curGuardsCount : int&;
                              quest_target_geometry_sphere__radius : float const?;
                              extraction__radiusMinMax : float2 const?)
  if !guarded_zone__active || act.curTime < guarded_zone__nextRegenerationAt
    return
  if guarded_zone__curGuardsCount >= guarded_zone__maxGuardsCount
    guarded_zone__nextRegenerationAt = act.curTime + rnd_float(guarded_zone__regenerationTime)
    return

  var radius = 10.0
  if quest_target_geometry_sphere__radius != null
    radius = *quest_target_geometry_sphere__radius
  elif extraction__radiusMinMax != null
    radius = (*extraction__radiusMinMax).y

  if !is_safety_to_regenerate(transform[3], radius * guarded_zone__playersCheckRadMult)
    guarded_zone__nextRegenerationAt = act.curTime + rnd_float(guarded_zone__regenerationTime)
    return

  var guardsToRegenerate = ceili(float(guarded_zone__maxGuardsCount) * guarded_zone__regenerationPart)
  guardsToRegenerate = min(guardsToRegenerate, guarded_zone__maxGuardsCount - guarded_zone__curGuardsCount)
  for _ in range(guardsToRegenerate)
    var spawnTm = transform
    let offset2d = rnd_point_on_disk(radius)
    spawnTm[3] = transform * float3(offset2d.x, 0.0, offset2d.y)
    if !project_to_nearest_navmesh_point_with_navmesh_mapping_and_check_accessibility(spawnTm[3], float3(3.0))
      continue

    find_query() <| $ [es(REQUIRE=(deadEntity))] (eid, guarded_zone_guard__zoneEid : EntityId)
      if guarded_zone_guard__zoneEid == zone_eid
        destroyEntity(eid)
        return true
      return false

    var choices : array<tuple<templateName : string; weight : float>>
    for entry in guarded_zone__guardTemplateNames
      choices |> emplace((entry.key, entry.value ?? 1.0))
    let idx = choose_index_by_weight(choices)

    let guardEid = createEntity("{choices[idx].templateName}+guarded_zone_guard") <| $(var init)
      init |> set("transform", spawnTm)
      init |> set("guarded_zone_guard__zoneEid", zone_eid)
    print("[GUARDED_ZONE] zone <{zone_eid}> created guard <{guardEid}> (bucket idx <{idx}>) at <{spawnTm}>")
    guarded_zone__curGuardsCount += 1

  guarded_zone__nextRegenerationAt = act.curTime + rnd_float(guarded_zone__regenerationTime)
  print("[GUARDED_ZONE] zone <{zone_eid}> planned next generation at <{guarded_zone__nextRegenerationAt}> cur guards <{guarded_zone__curGuardsCount}> / max guards <{guarded_zone__maxGuardsCount}>")


[es(tag=server, on_disappear, on_event=EventEntityDied)]
def on_guarded_zone_guard_died(evt : Event;
                               guarded_zone_guard__zoneEid : EntityId;
                               var guarded_zone_guard__noticedAboutDeath : bool&)
  if guarded_zone_guard__noticedAboutDeath
    return

  query(guarded_zone_guard__zoneEid) <| $ [es] (var guarded_zone__curGuardsCount : int&;
                                                guarded_zone__regenerationTime : float2;
                                                var guarded_zone__nextRegenerationAt : float&;
                                                quest_target_geometry_sphere__radius : float const?;
                                                extraction__radiusMinMax : float2 const?)
    guarded_zone__curGuardsCount = max(0, guarded_zone__curGuardsCount - 1)
    guarded_zone_guard__noticedAboutDeath = true

    var radius = 10.0
    if quest_target_geometry_sphere__radius != null
      radius = *quest_target_geometry_sphere__radius
    elif extraction__radiusMinMax != null
      radius = (*extraction__radiusMinMax).y

    guarded_zone__nextRegenerationAt = get_sync_time() + rnd_float(guarded_zone__regenerationTime)
    print("[GUARDED_ZONE] zone <{guarded_zone_guard__zoneEid}> planned next generation at <{guarded_zone__nextRegenerationAt}>, guard died")


[es(tag=server)]
def enable_guarded_zone_on_objective_linked(evt : EventQuestStaticTargetAssigned;
                                            eid : EntityId;
                                            var guarded_zone__active : bool&)
  guarded_zone__active = true
  print("[GUARDED_ZONE] zone <{eid}> activated by objective <{evt.objectiveEid}>")


[es(tag=server, on_appear, track=extraction__currentState, after=init_guarded_zone)]
def toggle_guarded_zone_for_extractions(evt : Event;
                                        eid : EntityId;
                                        extraction__currentState : int;
                                        var guarded_zone__active : bool&)
  guarded_zone__active = extraction__currentState != int(ExtractionPointState.DISABLED)
  print("[GUARDED_ZONE] zone <{eid}> activation toggle by extraction__currentState <{extraction__currentState}>")

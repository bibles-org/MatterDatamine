require app
require ecs
require ecs.safe
require strings
require DagorMath
require DagorRandom
require math.easing
require math.base
require game.events.events_active_matter
require game.es.extraction_point.extraction_point_common
require game.utils.hero


def spawn_extraction_visual(var extraction__visualEntities : EidList&; owner_eid : EntityId;
                            transform : float3x4; entities : Object)
  for it in entities
    let eid = createEntity(it.key) <| $(ini)
      var scale = 1.0
      var offset : float3
      let valueAsP4 = it.value |> get_Point4()
      if valueAsP4 == null
        offset = it.value ?? float3()
      else
        offset = float3((*valueAsP4).x, (*valueAsP4).y, (*valueAsP4).z)
        scale = (*valueAsP4).w

      var tm = transform
      tm[0] *= scale
      tm[1] *= scale
      tm[2] *= scale
      tm[3] = transform * offset
      ini |> set("transform", tm)
      ini |> set("extraction_visual__ownerEid", owner_eid)
    extraction__visualEntities |> push(eid)


def update_extraction_visual(hero_eid, extraction_eid : EntityId; transform : float3x4;
                             extraction__currentState : int;
                             extraction__inactiveEntityTemplates : Object;
                             extraction__activatingEntityTemplates : Object;
                             extraction__activeEntityTemplates : Object;
                             var extraction__visualEntities : EidList&)
  for visualEid in extraction__visualEntities
    visualEid |> destroyEntity()
  extraction__visualEntities |> clear()

  if !is_extraction_for_hero(hero_eid, extraction_eid)
    return

  assume state = extraction__currentState

  if state == int(ExtractionPointState.INACTIVE)
    spawn_extraction_visual(extraction__visualEntities, extraction_eid, transform, extraction__inactiveEntityTemplates)
  elif state == int(ExtractionPointState.ACTIVATING)
    spawn_extraction_visual(extraction__visualEntities, extraction_eid, transform, extraction__activatingEntityTemplates)
  elif state == int(ExtractionPointState.ACTIVE)
    spawn_extraction_visual(extraction__visualEntities, extraction_eid, transform, extraction__activeEntityTemplates)
  elif state == int(ExtractionPointState.DEACTIVATING)
    spawn_extraction_visual(extraction__visualEntities, extraction_eid, transform, extraction__activatingEntityTemplates)


[es(tag=render, on_appear, track=extraction__currentState)]
def extraction_point_visual_track_state(evt : Event; eid : EntityId; transform : float3x4;
                                        extraction__currentState : int;
                                        extraction__inactiveEntityTemplates : Object;
                                        extraction__activatingEntityTemplates : Object;
                                        extraction__activeEntityTemplates : Object;
                                        var extraction__visualEntities : EidList&)
  let watchedHero = get_watched_entity()
  update_extraction_visual(watchedHero, eid, transform, extraction__currentState, extraction__inactiveEntityTemplates,
                           extraction__activatingEntityTemplates, extraction__activeEntityTemplates, extraction__visualEntities)


[es(tag=render, on_appear, on_disappear, REQUIRE=watchedByPlr)]
def extraction_point_visual_on_watched_change(evt : Event; eid aka hero_eid : EntityId)
  query() <| $ [es] (eid aka extraction_eid : EntityId;
                     transform : float3x4;
                     extraction__currentState : int;
                     extraction__inactiveEntityTemplates : Object;
                     extraction__activatingEntityTemplates : Object;
                     extraction__activeEntityTemplates : Object;
                     var extraction__visualEntities : EidList&)
    update_extraction_visual(hero_eid, extraction_eid, transform, extraction__currentState, extraction__inactiveEntityTemplates,
                             extraction__activatingEntityTemplates, extraction__activeEntityTemplates, extraction__visualEntities)


[es(tag=gameClient, on_disappear)]
def clear_extraction_point_visuals_on_disappear(evt : Event; extraction__visualEntities : EidList)
  for visualEid in extraction__visualEntities
    visualEid |> destroyEntity()


[es(tag=render, on_appear, track=team__spawnGroupId, REQUIRE=team__spawnGroupId)]
def extraction_point_visual_on_spawn_group_change(evt : Event; team__id : int)
  let watchedHero = get_watched_entity()
  var watched_team : int
  query(watchedHero) <| $ [es] (team : int)
    watched_team = team
  if watched_team != team__id
    return
  query() <| $ [es] (eid : EntityId; transform : float3x4;
                     extraction__currentState : int;
                     extraction__inactiveEntityTemplates : Object;
                     extraction__activatingEntityTemplates : Object;
                     extraction__activeEntityTemplates : Object;
                     var extraction__visualEntities : EidList&)
    update_extraction_visual(watchedHero, eid, transform, extraction__currentState, extraction__inactiveEntityTemplates,
                             extraction__activatingEntityTemplates, extraction__activeEntityTemplates, extraction__visualEntities)


[es(tag=render, on_appear)]
def extraction_visual_initial_pos(evt : Event; transform : float3x4;
                                  var extraction_visual__initialPos : float3&)
  extraction_visual__initialPos = transform[3]


[es(tag=render, on_appear)]
def extraction_visual_initial_time(evt : Event; var extraction_visual__initialTime : float&)
  extraction_visual__initialTime = get_sync_time()


def aatm_scale(var transform : float3x4&; scale : float)
  let len1 = length(transform[0])
  let len2 = length(transform[1])
  let len3 = length(transform[2])
  transform[0] *= safediv(scale, len1)
  transform[1] *= safediv(scale, len2)
  transform[2] *= safediv(scale, len3)


[es(tag=render, after=extraction_visual_initial_pos, REQUIRE=extraction__activatingPortal,
    on_event=UpdateStageInfoBeforeRender, before=update_omni_light_es, on_appear)]
def update_activating_extraction(act : Event;
                                 extraction_visual__ownerEid : EntityId;
                                 extraction_visual__initialPos : float3;
                                 extraction_visual__initialTime : float;
                                 extraction_visual__minScale = 0.075;
                                 extraction_visual__preCollapseScale = 0.85;
                                 extraction_light__targetRadius = 4.;
                                 var light__max_radius : float?;
                                 var transform : float3x4&)
  query(extraction_visual__ownerEid) <| $ [es] (extraction__extractionProgress : float)
    let curTime = get_sync_time()
    let elapsedTime = curTime - extraction_visual__initialTime
    let progress = extraction__extractionProgress

    let t = lerp(perlin_noise1(2.3 * elapsedTime) * 1.25, progress, 0.85)

    let scale = lerp(extraction_visual__minScale, extraction_visual__preCollapseScale, max(0.0, t))
    transform |> aatm_scale(scale)

    let moveProgress = elapsedTime * 0.005
    let s = sin(curTime * 25.0 * moveProgress)
    let c = cos(curTime * 25.0 * moveProgress)
    let s2 = sin(curTime * -18. * moveProgress)
    transform[3] = extraction_visual__initialPos + float3(c, s2, s) * 0.1 * lerp(0.33, 0.1, progress)

    if light__max_radius != null
      *light__max_radius = saturate(saturate(lerp(scale, progress, 0.7)) + 0.1) * extraction_light__targetRadius


[es(tag=render, track=extraction__extractedPlayersNum)]
def show_extracted_players_effect(evt : Event; eid : EntityId;
                                  extraction__extractedPlayerEffect : string; transform : float3x4;
                                  extraction__extractedPlayersNum : int;
                                  var extraction__prevExtractedPlayersNum : int&)
  var delay = rnd_float(0.1, 0.2)
  for _ in range(extraction__prevExtractedPlayersNum, extraction__extractedPlayersNum)
    createEntity(extraction__extractedPlayerEffect) <| $(ini)
      ini |> set("transform", transform)
      ini |> set("game_effect__timeToDestroy", delay)
      ini |> set("game_effect__attachedTo", eid)
    delay += rnd_float(0.2, 0.4)
  extraction__prevExtractedPlayersNum = extraction__extractedPlayersNum


[es(tag=render, no_order, REQUIRE=extraction__activePortalLight, on_event=ParallelUpdateFrameDelayed, on_appear)]
def update_active_extraction_portal_color(evt : Event;
                                          extraction_visual__ownerEid : EntityId;
                                          extraction_visual__activePortal : E3DCOLOR;
                                          extraction_visual__extractingPortal : E3DCOLOR;
                                          var light__color : E3DCOLOR&)
  query(extraction_visual__ownerEid) <| $ [es] (extraction__extractionTimeEnd : float)
    light__color = extraction__extractionTimeEnd < 0. ? extraction_visual__activePortal : extraction_visual__extractingPortal


enum PortalPulseEffectState
  INACTIVE = 0
  PULSING = 1


[es(tag=gameClient, no_order, on_appear, on_event=ParallelUpdateFrameDelayed)]
def update_inactive_extraction_portal_pulse_state(evt : Event;
                                                  extraction_inactive_portal_pulse_effect__pulseDuration : float;
                                                  extraction_inactive_portal_pulse_effect__pulsePeriodRange : float2;
                                                  var extraction_inactive_portal_pulse_effect__state : int&;
                                                  var extraction_inactive_portal_pulse_effect__nextStateAt : float&)
  let curTime = get_sync_time()
  if extraction_inactive_portal_pulse_effect__nextStateAt < curTime
    if extraction_inactive_portal_pulse_effect__state == int(PortalPulseEffectState.INACTIVE)
      extraction_inactive_portal_pulse_effect__state = int(PortalPulseEffectState.PULSING)
      extraction_inactive_portal_pulse_effect__nextStateAt = curTime + extraction_inactive_portal_pulse_effect__pulseDuration
    elif extraction_inactive_portal_pulse_effect__state == int(PortalPulseEffectState.PULSING)
      extraction_inactive_portal_pulse_effect__state = int(PortalPulseEffectState.INACTIVE)
      let timeDelay = rnd_float(extraction_inactive_portal_pulse_effect__pulsePeriodRange.x, extraction_inactive_portal_pulse_effect__pulsePeriodRange.y)
      extraction_inactive_portal_pulse_effect__nextStateAt = curTime + timeDelay


[es(REQUIRE=extraction_pulse_effect, after=update_inactive_extraction_portal_pulse_state, tag=gameClient)]
def set_pulse_portal_effect_scale(act : ParallelUpdateFrameDelayed;
                                  extraction_inactive_portal_pulse_effect__state : int;
                                  extraction_inactive_portal_pulse_effect__pulseDuration : float;
                                  extraction_inactive_portal_pulse_effect__nextStateAt : float;
                                  extraction_pulse_effect__minMaxScale : float2;
                                  var transform : float3x4&)
  var curScale = transform[0][0]
  if extraction_inactive_portal_pulse_effect__state == int(PortalPulseEffectState.PULSING)
    let timeToPulseEnd = extraction_inactive_portal_pulse_effect__nextStateAt - act.curTime
    let pulseTimePassed = extraction_inactive_portal_pulse_effect__pulseDuration - timeToPulseEnd
    let ratio = pulseTimePassed / extraction_inactive_portal_pulse_effect__pulseDuration
    curScale = lerp(extraction_pulse_effect__minMaxScale.x, extraction_pulse_effect__minMaxScale.y, square(ratio))
  else
    curScale = approach(curScale, extraction_pulse_effect__minMaxScale.x, act.dt, 0.1)

  aatm_scale(transform, curScale)

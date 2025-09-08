require ecs
require ecs.safe
require app
require player
require math.base
require math.easing
require DagorSystem
require DagorMath
require game.utils.hero
require game.events.events_active_matter
require game.es.extraction_point.extraction_point_common


[es(tag=gameClient, on_appear)]
def extraction_preparing_affect_game_client_affects_appear(evt : Event;
                                                           game_effect__attachedTo : EntityId;
                                                           extraction_preparing_affect__gameClientAffects : Array;
                                                           var extraction_preparing_affect__gameClientAffectEids : EidList)
  query(game_effect__attachedTo) <| $ [es] (createdByPlr : EntityId)
    let localPlayerEid = get_local_player_eid()
    let isLocalPlayerHero = createdByPlr == localPlayerEid

    for gameClientAffectData in extraction_preparing_affect__gameClientAffects
      let gameClientAffectObj = gameClientAffectData as Object
      let affectTemplateName = isLocalPlayerHero ? gameClientAffectObj?.fps ?? "" : gameClientAffectObj?.tps ?? ""
      if affectTemplateName != ""
        let affectEid = createEntity(affectTemplateName) <| $(var init : ComponentsInitializer)
          init |> set("game_effect__attachedTo", game_effect__attachedTo)
        extraction_preparing_affect__gameClientAffectEids |> push(affectEid)


[es(tag=gameClient, on_disappear)]
def extraction_preparing_affect_game_client_affects_disappear(evt : Event;
                                                              var extraction_preparing_affect__gameClientAffectEids : EidList)
  for affectEid in extraction_preparing_affect__gameClientAffectEids
    destroyEntity(affectEid)


def cancel_human_cam_magnification_normalizer_affect(human_eid : EntityId)
  find_query() <| $ [es(REQUIRE=human_cam_magnification_normalizer_affect)] (eid aka normalizer_affect_eid : EntityId;
                                                                             game_effect__attachedTo aka normalizer_affect_game_effect__attachedTo : EntityId)
    if normalizer_affect_game_effect__attachedTo == human_eid
      destroyEntity(normalizer_affect_eid)
      return true
    return false


[es(tag=gameClient, on_appear, REQUIRE=extraction_preparing_affect)]
def extraction_preparing_affect_fov_appear(evt : Event;
                                           game_effect__attachedTo aka extraction_game_effect__attachedTo : EntityId)
  cancel_human_cam_magnification_normalizer_affect(extraction_game_effect__attachedTo)


[es(tag=gameClient, no_order)]
def extraction_preparing_affect_fov_animation(act : ParallelUpdateFrameDelayed;
                                              game_effect__attachedTo : EntityId;
                                              extraction_preparing_affect__startedAt : float;
                                              extraction_preparing_affect__extractAt : float;
                                              extraction_preparing_affect__fovMagnificationFrequency : float;
                                              extraction_preparing_affect__fovMagnificationAmplitudeStart : float2;
                                              extraction_preparing_affect__fovMagnificationAmplitudeEnd : float2)
  let activationProgress = inOutBezier(cvt(act.curTime, extraction_preparing_affect__startedAt, extraction_preparing_affect__extractAt, 0.0, 1.0))

  let amplitudeFrom = lerp(extraction_preparing_affect__fovMagnificationAmplitudeStart.x, extraction_preparing_affect__fovMagnificationAmplitudeEnd.x, activationProgress)
  let amplitudeTo = lerp(extraction_preparing_affect__fovMagnificationAmplitudeStart.y, extraction_preparing_affect__fovMagnificationAmplitudeEnd.y, activationProgress)

  let s = sin(act.curTime * TWOPI * extraction_preparing_affect__fovMagnificationFrequency)
  let targetMagnification = cvt(s, -1.0, 1.0, amplitudeFrom, amplitudeTo)

  query(game_effect__attachedTo) <| $ [es(REQUIRE_NOT=pulled_in_by_portal_militant_animation__fovMagnification)] (var human__cameraMagnificationMult : float&)
    human__cameraMagnificationMult = max(1e-3, lerp(human__cameraMagnificationMult, targetMagnification, act.dt * 3.0))


[es(tag=gameClient, on_disappear, REQUIRE=extraction_preparing_affect)]
def extraction_preparing_affect_fov_disappear(evt : Event;
                                              game_effect__attachedTo : EntityId)
  createEntity("human_cam_magnification_normalizer_affect") <| $(var init : ComponentsInitializer)
    init |> set("game_effect__attachedTo", game_effect__attachedTo)


[es(tag=gameClient, no_order, REQUIRE=hero)]
def update_closest_extraction_portal(act : ParallelUpdateFrameDelayed;
                                     eid aka hero_eid : EntityId;
                                     transform aka hero_transform : float3x4;
                                     var hero_extraction__closestExtractionPortal : EntityId&)
  hero_extraction__closestExtractionPortal = INVALID_ENTITY_ID
  find_query() <| $ [es] (eid aka extraction_eid : EntityId;
                          transform aka extraction_transform : float3x4;
                          extraction__currentState : int;
                          extraction__radiusMinMax : float2)
    if extraction_eid == hero_extraction__closestExtractionPortal
      return false
    if extraction__currentState == int(ExtractionPointState.DISABLED)
      return false
    if !is_extraction_for_hero(hero_eid, extraction_eid)
      return false
    let dstSq = distance_sq(extraction_transform[3], hero_transform[3])
    if dstSq < extraction__radiusMinMax.x
      hero_extraction__closestExtractionPortal = extraction_eid
      return true
    return false


[es(tag=gameClient, on_appear, track=(extraction__currentState, extraction__forceMapVisible))]
def toggle_hud_for_extraction(evt : Event;
                              eid : EntityId;
                              extraction__currentState : int;
                              extraction__forceMapVisible : bool)
  let watchedHero = get_watched_entity()
  update_active_extraction_point(eid, watchedHero, extraction__currentState, extraction__forceMapVisible)


[es(tag=gameClient, on_appear, on_disappear, REQUIRE=watchedByPlr)]
def toggle_hud_for_extraction_on_watched_change(evt : Event; eid aka hero_eid : EntityId)
  query() <| $ [es] (eid aka extraction_eid : EntityId;
                     extraction__currentState : int;
                     extraction__forceMapVisible : bool)
    update_active_extraction_point(extraction_eid, hero_eid, extraction__currentState, extraction__forceMapVisible)


[es(tag=gameClient, on_appear, track=team__spawnGroupId, REQUIRE=team__spawnGroupId)]
def toggle_hud_for_extraction_on_spawn_group_change(evt : Event; team__id : int)
  let watchedHero = get_watched_entity()
  var watched_team : int
  query(watchedHero) <| $ [es] (team : int)
    watched_team = team
  if watched_team != team__id
    return
  query() <| $ [es] (eid : EntityId;
                     extraction__currentState : int;
                     extraction__forceMapVisible : bool)
    update_active_extraction_point(eid, watchedHero, extraction__currentState, extraction__forceMapVisible)

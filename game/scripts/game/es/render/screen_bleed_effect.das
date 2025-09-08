require ecs
require math
require app

[es(tag=render, no_order)]
def smooth_appear_screen_bleed(act : UpdateStageInfoAct;
                               game_effect__attachedAt : float;
                               game_effect__clientDestroyAt, game_effect__timeToDestroy : float const?;
                               game_effect__screenBleedDecaySmoothTime = 2f;
                               game_effect__screenBleedProcessFrameMulSmooth : float2;
                               game_effect__screenBleedSimulateDecaySmooth : float2;
                               var screen_bleed__simulate_decay : float&;
                               var screen_bleed__process_frame_mul : float&)
  let destroying = game_effect__clientDestroyAt != null && game_effect__timeToDestroy != null && *game_effect__clientDestroyAt >= 0.
  let time = destroying ? *game_effect__clientDestroyAt - act.curTime : act.curTime - game_effect__attachedAt
  let totalTime = destroying ? *game_effect__timeToDestroy : game_effect__screenBleedDecaySmoothTime
  let progress = saturate(time / totalTime)
  screen_bleed__process_frame_mul = lerp(game_effect__screenBleedProcessFrameMulSmooth.x, game_effect__screenBleedProcessFrameMulSmooth.y, progress)
  screen_bleed__simulate_decay = lerp(game_effect__screenBleedSimulateDecaySmooth.x, game_effect__screenBleedSimulateDecaySmooth.y, pow(progress, 1. / 16.))


def enabled_screen_bleeding(screen_bleed_effect__template : string)
  var screenBleedForbid = find_query() <| $[es(REQUIRE=disableScreenEffects)] (camera__active : bool)
    return camera__active
  let exists = find_query() <| $ [es(REQUIRE=screenBleedEffect)] (var game_effect__attachedAt : float&;
                                                                  screen_bleed__enabled : bool;
                                                                  eid aka sb_eid : EntityId;
                                                                  screen_bleed_effect__destrTemplate = "")
    if !screen_bleed__enabled
      screenBleedForbid = true
      return false
    game_effect__attachedAt = get_sync_time()
    if !empty(screen_bleed_effect__destrTemplate)
      removeSubTemplate(sb_eid, screen_bleed_effect__destrTemplate)
    return true
  if !exists && !screenBleedForbid
    let eidd = createEntity(screen_bleed_effect__template)

def disabled_screen_bleeding()
  find_query() <| $ [es(REQUIRE=screenBleedEffect)] (eid : EntityId; screen_bleed_effect__destrTemplate = "")
    if !empty(screen_bleed_effect__destrTemplate)
      addSubTemplate(eid, screen_bleed_effect__destrTemplate)
    else
      destroyEntity(eid)
    return true


[es(tag=render, track=screen_bleed__enabled)]
def on_screen_bleed_enabled(evt : Event;
                            screen_bleed__enabled : bool)
  if !screen_bleed__enabled
    disabled_screen_bleeding()
  else
    find_query() <| $[es] (screen_bleed_effect__template : string;
                           game_effect__attachedTo : EntityId)
      if has(game_effect__attachedTo, "watchedByPlr")
        enabled_screen_bleeding(screen_bleed_effect__template)
        return true
      return false


[es(tag=render, on_appear)]
def on_screen_bleed_rq_appear(evt : Event; screen_bleed_effect__template : string; game_effect__attachedTo : EntityId)
  if has(game_effect__attachedTo, "watchedByPlr")
    enabled_screen_bleeding(screen_bleed_effect__template)


[es(tag=render, on_disappear, REQUIRE=screen_bleed_effect__template)]
def on_screen_bleed_rq_disappear(evt : Event; eid aka original_eid : EntityId)
  let exists = find_query() <| $ [es(REQUIRE=screen_bleed_effect__template)] (game_effect__attachedTo, eid aka another_eid : EntityId)
    return another_eid != original_eid && has(game_effect__attachedTo, "watchedByPlr")
  if !exists //No other reason to have bleeding eixists, so delete bleeding
    disabled_screen_bleeding()


[es(tag=render, on_appear, REQUIRE=watchedByPlr)]
def on_started_spectating_hero_with_screen_bleed(evt : Event; eid : EntityId)
  find_query() <| $ [es] (screen_bleed_effect__template : string; game_effect__attachedTo : EntityId)
    if game_effect__attachedTo == eid
      enabled_screen_bleeding(screen_bleed_effect__template)
      return true
    return false


[es(tag=render, on_disappear, REQUIRE=watchedByPlr)]
def on_stopped_spectating_hero_with_screen_bleed(evt : Event; eid aka this_eid : EntityId)
  let exists = find_query() <| $ [es(REQUIRE=screen_bleed_effect__template)] (game_effect__attachedTo : EntityId)
    return this_eid != game_effect__attachedTo && has(game_effect__attachedTo, "watchedByPlr")
  if !exists
    disabled_screen_bleeding()
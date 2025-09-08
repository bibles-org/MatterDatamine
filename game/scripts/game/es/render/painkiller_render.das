require ecs
require app
require DagorMath

[es(tag=render, on_appear)]
def painkiller_effect_appear(evt : Event;
                             game_effect__attachedTo : EntityId;
                             game_effect__timeToDestroy : float;
                             painkiller_effect__effectVisualStrength : float)
  if game_effect__attachedTo |> has("watchedByPlr")
    find_query() <| $ [es] (var painkiller_screen_effect__startAt : float&;
                            var painkiller_screen_effect__endAt : float&;
                            var painkiller_screen_effect__wishBorder : float&)
      painkiller_screen_effect__wishBorder = painkiller_effect__effectVisualStrength
      let curTime = get_sync_time()
      if painkiller_screen_effect__startAt < 0.0
        painkiller_screen_effect__startAt = curTime
      painkiller_screen_effect__endAt = curTime + game_effect__timeToDestroy
      return true


[es(tag=render, before=screen_effect_render_es)]
def painkiller_effect_update(info : UpdateStageInfoAct;
                             painkiller_screen_effect__startTime : float;
                             painkiller_screen_effect__endTime : float;
                             painkiller_screen_effect__wishBorder : float;
                             var painkiller_screen_effect__startAt : float&;
                             var painkiller_screen_effect__endAt : float&;
                             var screen_effect__borderOffset, screen_effect__weight : float&)
  if painkiller_screen_effect__startAt < 0.0
    screen_effect__borderOffset = 0.0
  elif info.curTime < painkiller_screen_effect__startAt + painkiller_screen_effect__startTime
    let timeK = info.curTime - painkiller_screen_effect__startAt
    screen_effect__borderOffset = cvt(timeK, 0.0, painkiller_screen_effect__startTime, 0.0, painkiller_screen_effect__wishBorder)
  elif info.curTime > painkiller_screen_effect__endAt
    painkiller_screen_effect__startAt = -1.0
    painkiller_screen_effect__endAt = -1.0
    screen_effect__borderOffset = 0.0
  elif info.curTime > painkiller_screen_effect__endAt - painkiller_screen_effect__endTime
    let timeK = painkiller_screen_effect__endAt - info.curTime
    screen_effect__borderOffset = cvt(timeK, 0.0, painkiller_screen_effect__endTime, 0.0, painkiller_screen_effect__wishBorder)
  screen_effect__weight = screen_effect__borderOffset > 0.0 ? 0.1 : 0.0


[es(tag=render, on_appear, REQUIRE=watchedByPlr)]
def painkiller_effect_on_watched_appear(evt : Event; eid : EntityId)
  find_query() <| $ [es] (var painkiller_screen_effect__startAt : float&;
                          var painkiller_screen_effect__endAt : float&;
                          var painkiller_screen_effect__wishBorder : float&)
    painkiller_screen_effect__startAt = -1.0
    painkiller_screen_effect__endAt = -1.0
    painkiller_screen_effect__wishBorder = 0.0

    find_query() <| $ [es] (game_effect__attachedTo : EntityId;
                            game_effect__timeToDestroy : float;
                            game_effect__destroyAt : float;
                            painkiller_effect__effectVisualStrength : float)
      if game_effect__attachedTo == eid
        painkiller_screen_effect__wishBorder = painkiller_effect__effectVisualStrength
        if game_effect__destroyAt < 0.0
          // effect has just appeared
          let curTime = get_sync_time()
          painkiller_screen_effect__startAt = curTime
          painkiller_screen_effect__endAt = curTime + game_effect__timeToDestroy
        else
          // effect is already in progress
          painkiller_screen_effect__startAt = game_effect__destroyAt - game_effect__timeToDestroy
          painkiller_screen_effect__endAt = game_effect__destroyAt
        return true
      return false
    return true

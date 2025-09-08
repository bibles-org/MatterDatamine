require ecs
require math.base
require game.events.events_active_matter


[es(tag=gameClient, REQUIRE=hero)]
def bees_on_stain_make(evt : EventBeesLeftStain; eid aka hero_eid : EntityId)
  let hasEffect = find_query() <| $ [es(REQUIRE=bees_dirty_screen_effect)] (game_effect__attachedTo : EntityId; var screen_effect__weight : float&)
    if hero_eid != game_effect__attachedTo
      return false
    screen_effect__weight = min(0.2, screen_effect__weight + evt.value)
    return true
  if !hasEffect
    createEntity("bees_dirty_screen_effect") <| $(var init)
      init |> set("game_effect__attachedTo", hero_eid)
      init |> set("screen_effect__weight", evt.value)


[es(tag=gameClient, REQUIRE=bees_dirty_screen_effect, no_order)]
def bees_stain_update(act : ParallelUpdateFrameDelayed;
                      eid : EntityId;
                      bees_dirty_screen_effect__recoverSpd : float;
                      var screen_effect__weight, screen_effect__intensity : float&)
  screen_effect__weight -= act.dt * bees_dirty_screen_effect__recoverSpd
  if screen_effect__weight <= 0.0
    destroyEntity(eid)
  screen_effect__intensity = approach(screen_effect__intensity, screen_effect__weight, act.dt, 1.0f)

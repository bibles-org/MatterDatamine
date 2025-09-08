require ecs
require math.base
require math.easing
require game.events.events_active_matter


[es(no_order)]
def pain_progress(info : ParallelUpdateFrameDelayed;
                  pain__progressMult : float;
                  pain__lockDecreaseProgressUntil : float;
                  var pain__progress : float&;
                  var pain__active : bool&)
  pain__active = pain__progress > 0f
  if info.curTime < pain__lockDecreaseProgressUntil
    return
  pain__progress = max(0f, pain__progress - info.dt * pain__progressMult)


[es(after=pain_progress)]
def pain_intensity(info : ParallelUpdateFrameDelayed;
                   pain__progress : float;
                   pain__intensityMult : float;
                   var pain__intensity : float&)
  pain__intensity = max(0f, inBounce(pain__progress)) * pain__intensityMult


[es(tag=server, track=pain__active)]
def pain_entity_mods_mult_mgr(evt : Event;
                              eid aka owner_eid : EntityId;
                              pain__active : bool;
                              pain__entityModsMultTemplateName : string)
  if pain__active
    createEntity(pain__entityModsMultTemplateName) <| $(var init)
      set(init, "game_effect__attachedTo", eid)
  else
    find_query() <| $ [es(REQUIRE=painEntityModsMult)] (eid, game_effect__attachedTo : EntityId)
      if game_effect__attachedTo == owner_eid
        destroyEntity(eid)
        return true
      return false
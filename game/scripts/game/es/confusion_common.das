module confusion_common shared
require ecs
require app
require ecs.common

def disable_confusion_affect(owner_eid : EntityId)
  find_query() <| $ [es(REQUIRE=confusionAffect)] (eid : EntityId; game_effect__attachedTo : EntityId)
    if game_effect__attachedTo != owner_eid
      return false

    destroyEntity(eid)
    return true

def enable_confusion_affect(owner_eid : EntityId; duration = 0.0; intensity = 0.0; speed = 0.0;
                            sync : bool = true)
  let isConfused = find_query() <| $ [es(REQUIRE=confusionAffect)] (game_effect__attachedTo : EntityId)
    return game_effect__attachedTo == owner_eid
  if isConfused
    return
  // create sync to predict issue with multiple confusion_affect-s in world assigned to one entity
  (sync ? createEntitySync("confusion_affect") : createEntity("confusion_affect")) <| $(var init : ComponentsInitializer)
    set(init, "game_effect__attachedTo", owner_eid)
    set(init, "confusion__startedAtTime", get_sync_time())
    if duration > 0.0
      set(init, "confusion__duration", duration)
    if intensity > 0.0
      set(init, "confusion__intensity", intensity)
    if speed > 0.0
      set(init, "confusion__speed", speed)


def start_or_overwrite_confusion_affect(owner_eid : EntityId; duration = 0.0; intensity = 0.0; speed = 0.0)
  let isConfused = find_query() <| $ [es(REQUIRE=confusionAffect)] (game_effect__attachedTo : EntityId;
                                                                    confusion__startedAtTime : float;
                                                                    var confusion__duration : float&;
                                                                    var confusion__intensity : float&;
                                                                    var confusion__speed : float&)
    if game_effect__attachedTo == owner_eid
      let time = get_sync_time()
      confusion__duration = max(confusion__duration + confusion__startedAtTime, time + duration) - confusion__startedAtTime
      if intensity > 0.0
        confusion__intensity = intensity
      if speed > 0.0
        confusion__speed = speed
      return true
    return false
  if !isConfused
    // create sync to predict issue with multiple confusion_affect-s in world assigned to one entity
    createEntitySync("confusion_affect") <| $(var init : ComponentsInitializer)
      set(init, "game_effect__attachedTo", owner_eid)
      set(init, "confusion__startedAtTime", get_sync_time())
      if duration > 0.0
        set(init, "confusion__duration", duration)
      if intensity > 0.0
        set(init, "confusion__intensity", intensity)
      if speed > 0.0
        set(init, "confusion__speed", speed)
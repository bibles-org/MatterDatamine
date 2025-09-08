module pain_common shared
require ecs
require DngDm
require app
require strings
require DngNet
require game.utils.net_utils
require game.events.events_active_matter
require game.es.damage_systems.damage_model_common


def has_pain_immunity(human_eid : EntityId) : bool
  var res = false
  find_query() <| $ [es(REQUIRE=painkillerEffect)] (game_effect__attachedTo : EntityId)
    res = game_effect__attachedTo == human_eid
    return res
  return res


def set_pain_progress(target_eid : EntityId; progress : float)
  if !has_pain_immunity(target_eid)
    query(target_eid) <| $ [es] (pain__lockDecreaseProgressDuration : float;
                                 var pain__progress, pain__lockDecreaseProgressUntil : float&)
      pain__progress = clamp(progress, 0f, 1f)
      pain__lockDecreaseProgressUntil = get_sync_time() + pain__lockDecreaseProgressDuration


def add_pain_progress(target_eid : EntityId; progress : float)
  if !has_pain_immunity(target_eid)
    query(target_eid) <| $ [es] (pain__lockDecreaseProgressDuration : float;
                                 var pain__progress, pain__lockDecreaseProgressUntil : float&)
      pain__progress = clamp(pain__progress + progress, 0f, 1f)
      pain__lockDecreaseProgressUntil = get_sync_time() + pain__lockDecreaseProgressDuration


def reset_pain_progress(target_eid : EntityId)
  set_pain_progress(target_eid, 0f)
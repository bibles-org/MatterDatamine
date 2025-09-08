require ecs
require app
require game.events.events_active_matter
require math.easing


[es(tag=gameClient, on_appear, REQUIRE=marker_self_destroy)]
def marker_self_destroy_appear(evt : Event;
                               marker__selfDestroyTime : float;
                               var marker__selfDestroyAt : float&)
  marker__selfDestroyAt = get_sync_time() + marker__selfDestroyTime


[es(tag=gameClient, after=marker_self_destroy_appear)]
def marker_self_destroy_update(act : ParallelUpdateFrameDelayed;
                               eid : EntityId;
                               marker__selfDestroyTime : float;
                               marker__selfDestroyAt : float;
                               var marker__selfDestroyProgress : float&)
  if marker__selfDestroyAt < 0.0
    return

  let timeLeft = marker__selfDestroyAt - act.curTime
  if timeLeft <= 0.0
    marker__selfDestroyProgress = 0.0
    destroyEntity(eid)
    return

  marker__selfDestroyProgress = outQuad(timeLeft / marker__selfDestroyTime)


[es(tag=gameClient, after=marker_self_destroy_update)]
def marker_self_destroy_update_hud_marker(act : ParallelUpdateFrameDelayed;
                                          marker__selfDestroyProgress : float;
                                          var hud_marker__opacity : float&)
  hud_marker__opacity = marker__selfDestroyProgress


[es(tag=gameClient, after=marker_self_destroy_update)]
def marker_self_destroy_update_map_object_marker(act : ParallelUpdateFrameDelayed;
                                                 marker__selfDestroyProgress : float;
                                                 var map_object_marker__opacity : float&)
  map_object_marker__opacity = marker__selfDestroyProgress


[es(tag=gameClient, on_disappear)]
def marker_self_destroy_hud_marker(evt : Event;
                                   var hud_marker__opacity : float&)
  hud_marker__opacity = 0.0


[es(tag=gameClient, on_disappear)]
def marker_self_destroy_map_object_marker(evt : Event;
                                          var map_object_marker__opacity : float&)
  map_object_marker__opacity = 0.0

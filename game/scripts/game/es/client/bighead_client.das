require ecs
require app
require math.random
require math.base
require game.es.bighead_common
require DagorMath
require game.events.events_active_matter


[es(tag=gameClient, track=isAlive, REQUIRE=bighead)]
def destroy_floating_objects_on_death(evt : Event;
                                      isAlive : bool;
                                      var floating_objects__eids : EidList)
  if isAlive
    return
  let now = get_sync_time()
  for eid in floating_objects__eids
    addSubTemplate(eid, "bighead_floating_object_destruction") <| $(i)
      set(i, "bighead_floating_object_destruction__destroyAt", now + rnd_float(0.0, 5.0))
  clear(floating_objects__eids)


[es(tag=gameClient, no_order)]
def bighead_move_floating_objects_anchor(update : ParallelUpdateFrameDelayed;
                                         transform : float3x4;
                                         floating_objects__anchorApproachViscocity : float;
                                         floating_objects__anchorOffset : float3;
                                         var floating_objects__anchorPosition : float3&)
  floating_objects__anchorPosition = approach(floating_objects__anchorPosition,
                                                      transform * floating_objects__anchorOffset,
                                                      update.dt,
                                                      floating_objects__anchorApproachViscocity)

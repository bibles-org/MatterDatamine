require app
require ecs
require ecs.common
require game.events.events_active_matter


[es(on_appear)]
def swarm_destroy_if_empty_init(evt : Event;
                                eid : EntityId;
                                swarm_destroy_if_empty__checkInterval : float = 1.0;
                                var swarm_destroy_if_empty__nextCheckAt : float&)
  swarm_destroy_if_empty__nextCheckAt = get_sync_time() + 1.0 + eid_frnd(eid) * swarm_destroy_if_empty__checkInterval


[es(no_order)]
def swarm_destroy_if_empty(act : ParallelUpdateFrameDelayed;
                           eid : EntityId;
                           swarm_destroy_if_empty__checkInterval : float = 1.0;
                           var swarm_destroy_if_empty__nextCheckAt : float&)
  if act.curTime < swarm_destroy_if_empty__nextCheckAt
    return

  let found = find_query() <| $ [es] (parentSwarm : EntityId) => parentSwarm == eid
  if found
    swarm_destroy_if_empty__nextCheckAt = get_sync_time() + swarm_destroy_if_empty__checkInterval
  else
    destroyEntity(eid)

require ecs
require game.events.events_active_matter


def track_entity_in_net_stash(eid : EntityId; transform : float3x4)
  if transform[3].x < -4000.0 && transform[3].z < -4000.0
    addSubTemplate(eid, "net_stash_entity")
    sendEvent(eid, EventWentToNetStash())


[es(no_order, tag=netClient, REQUIRE=loc_snapshots__snapshotData, REQUIRE_NOT=net_stash_entity, parallel_for=64)]
def track_loc_snapshot_entities_in_net_stash(update : ParallelUpdateFrameDelayed; eid : EntityId; transform : float3x4)
  track_entity_in_net_stash(eid, transform)


[es(no_order, tag=netClient, REQUIRE=base_net_phys_ptr, REQUIRE_NOT=net_stash_entity, parallel_for=64)]
def track_net_phys_entities_in_net_stash(update : ParallelUpdateFrameDelayed; eid : EntityId; transform : float3x4)
  track_entity_in_net_stash(eid, transform)


[es(no_order, tag=netClient, REQUIRE=net_stash_entity, parallel_for=64)]
def release_entities_from_net_stash(update : ParallelUpdateFrameDelayed; eid : EntityId; transform : float3x4)
  if transform[3].x > -4000.0 || transform[3].z > -4000.0
    removeSubTemplate(eid, "net_stash_entity")
    sendEvent(eid, EventNoLongerInNetStash())

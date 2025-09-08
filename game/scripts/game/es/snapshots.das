require ecs
require DngNet


[es(REQUIRE=loc_snapshots_wait_lock, no_order)]
def loc_snapshots_wait_lock_update(act : UpdateStageInfoAct;
                                   eid : EntityId;
                                   loc_snapshots__snapshotData : LocSnapshotsList;
                                   loc_snapshots__template : string = "loc_snapshots_wait_lock")
  if length(loc_snapshots__snapshotData) > 0
    removeSubTemplate(eid, loc_snapshots__template)
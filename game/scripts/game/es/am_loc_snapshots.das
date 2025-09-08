require app
require ecs
require strings
require daslib.strings_boost
require BitStream
require DngNet
require DagorMath
require game.events.events_active_matter
require game.es.loc_snapshots_common

//Send event but only on recreate
[es(tag=(server, net), on_appear, REQUIRE=loc_snaphots__disabled)]
def send_reliable_snapshot_on_monster_fell_asleep(evt : Event; eid : EntityId; transform : float3x4; var loc_snapshots__inited : bool&)
  if loc_snapshots__inited
    var snapshots : array<SnapshotEntityData>
    var tm := transform
    orthonormalize(tm)
    snapshots |> emplace(SnapshotEntityData(eid = eid, pos = tm[3], orientation = math::quat(tm), blink = false, rangeIdx = 0u))
    serialize_snapshots(get_sync_time(), snapshots) <| $(var bs : BitStream)
      send_TransformSnapshotReliable_event(bs)
    find_query() <| $ [es] (var loc_snapshots_debug__countByType : Object)
      let tmpl = getEntityTemplateName(eid)
      if !empty(tmpl)
        let parts <- split(tmpl, "+")
        var counts = get_IPoint2(loc_snapshots_debug__countByType, parts[0]) ?? int2()
        counts.y++
        set(loc_snapshots_debug__countByType, parts[0], counts)
      return true
  loc_snapshots__inited = true


[es(tag=(server, net), on_appear, REQUIRE_NOT=loc_snaphots__disabled)]
def init_sleeping_monster_snapshots(evt : Event; var loc_snapshots__inited : bool&)
  loc_snapshots__inited = true


[es(tag=(gameClient, net))]
def receive_reliable_snapshot(evt : TransformSnapshotsReliable)
  let affectedEntities <- read_and_add_snapshots(evt.data, 0.0)
  for eid in affectedEntities
    query(eid) <| $ [es] (loc_snapshots__snapshotData : LocSnapshotsList; var transform : float3x4)
      assume lastSnap = loc_snapshots__snapshotData[length(loc_snapshots__snapshotData) - 1]
      make_tm(lastSnap.quat, lastSnap.pos, transform)

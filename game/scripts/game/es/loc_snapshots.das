require app
require ecs
require ecs.common
require math.base
require strings
require daslib.strings_boost
require BitStream
require DngNet
require DagorMath
require Grid
require GridCollision
require game.events.events_active_matter
require game.es.loc_snapshots_common
require game.utils.net_utils


[es(tag=(server, net), on_appear)]
def init_awareness_snapshots(act : Event;
                             eid : EntityId;
                             hero_awareness__startDelay : float;
                             var hero_awareness__updateAt : float&;
                             var hero_awareness__lastUpdateAt : float&)
  hero_awareness__lastUpdateAt = get_sync_time() + eid_frnd(eid)
  hero_awareness__updateAt = hero_awareness__lastUpdateAt + hero_awareness__startDelay


[es(tag=(server, net), no_order)]
def send_awareness_snapshots(act : UpdateStageInfoAct;
                             eid : EntityId;
                             possessedByPlr : EntityId;
                             transform aka o_transform : float3x4;
                             hero_awareness__rangeStep : float;
                             hero_awareness__rangeCount : int;
                             hero_awareness__rateStep : float;
                             @shared_comp hero_awareness__rates : IntList;
                             hero_awareness_debug__enabled : bool = false;
                             var hero_awareness__updateAt : float&;
                             var hero_awareness__lastUpdateAt : float&)
  query(possessedByPlr) <| $ [es] (connid : int; disconnected : bool)
    if connid >= 0 && !disconnected
      if act.curTime > hero_awareness__updateAt
        let lastUpdateAt = hero_awareness__lastUpdateAt
        hero_awareness__lastUpdateAt = act.curTime
        hero_awareness__updateAt = act.curTime + hero_awareness__rateStep

        //Gather data
        let globalPeriod = float(hero_awareness__rates[length(hero_awareness__rates) - 1]) * hero_awareness__rateStep
        let maxDstSq = square(float(hero_awareness__rangeCount) * hero_awareness__rangeStep)
        var snapshots : array<SnapshotEntityData>
        query() <| $ [es(REQUIRE=loc_snapshots__snapshotData,
                         REQUIRE_NOT=(deadEntity, loc_snaphots__disabled))] (eid aka t_eid : EntityId;
                                                                             transform aka t_transform : float3x4;
                                                                             loc_snapshots__addPeriod : int = 0;
                                                                             loc_snapshots__maxDelayDstSq : float = FLT_MAX;
                                                                             var loc_snapshots__sendExtraSnap : bool&;
                                                                             var loc_snapshots__blink : bool&)
          let dstSq = min(distance_sq(o_transform[3], t_transform[3]), loc_snapshots__maxDelayDstSq)
          if dstSq > maxDstSq
            return
          let sendOffset = eid_frnd(eid) * globalPeriod
          let rangeIdx = max(0, int(ceil(sqrt(dstSq) / hero_awareness__rangeStep)) - 1)
          let rateIdx = min(length(hero_awareness__rates) - 1, rangeIdx)
          let sendStepsCount = hero_awareness__rates[rateIdx] + loc_snapshots__addPeriod
          let sendPeriod = float(sendStepsCount) * hero_awareness__rateStep
          let periodsBefore = int((lastUpdateAt + sendOffset) / sendPeriod)
          let periodsNow = int((act.curTime + sendOffset) / sendPeriod)
          if loc_snapshots__sendExtraSnap || periodsNow > periodsBefore
            loc_snapshots__sendExtraSnap = false
            var tm := t_transform
            orthonormalize(tm)
            snapshots |> emplace(SnapshotEntityData(eid = t_eid, pos = tm[3], orientation = math::quat(tm), blink = loc_snapshots__blink, rangeIdx = uint(rangeIdx)))
            loc_snapshots__blink = false

        //Send data
        serialize_snapshots(act.curTime, snapshots) <| $(var bs : BitStream)
          send_net_event(eid, TransformSnapshotsTargeted(data = ecs_addr(bs)), possessed_and_spectated(eid))

        if hero_awareness_debug__enabled
          accumulate_debug_data(eid, act.curTime, snapshots)
        find_query() <| $ [es] (var loc_snapshots_debug__countByRange : IntList; var loc_snapshots_debug__countByType : Object)
          accumulate_debug_data(loc_snapshots_debug__countByRange, loc_snapshots_debug__countByType, snapshots)
          return true


def accumulate_debug_data(eid : EntityId; cur_time : float; snapshots : array<SnapshotEntityData>)
  query(eid) <| $ [es] (var hero_awareness_debug__tallyAt : float&;
                        var hero_awareness_debug__eids : EidList;
                        var hero_awareness_debug__eidsCount : IntList;
                        var hero_awareness_debug__snapsCount : IntList;
                        hero_awareness_debug__tallyInterval : float;
                        hero_awareness__rangeCount : int)
    if cur_time > hero_awareness_debug__tallyAt
      hero_awareness_debug__tallyAt = cur_time + hero_awareness_debug__tallyInterval
      send_net_event(eid, EventSnapshotsDebugInfo(eidsCounts = ecs_addr(hero_awareness_debug__eidsCount), snapsCounts = ecs_addr(hero_awareness_debug__snapsCount)), target_entity_conn(eid))
      clear(hero_awareness_debug__eids)
      clear(hero_awareness_debug__snapsCount)
      resize(hero_awareness_debug__snapsCount, hero_awareness__rangeCount)
      clear(hero_awareness_debug__eidsCount)
      resize(hero_awareness_debug__eidsCount, hero_awareness__rangeCount)
    for snap in snapshots
      if !has_value(hero_awareness_debug__eids, snap.eid)
        hero_awareness_debug__eids |> push(snap.eid)
        hero_awareness_debug__eidsCount[snap.rangeIdx]++
      hero_awareness_debug__snapsCount[snap.rangeIdx]++


[es(tag=(server, net), on_disappear, REQUIRE=loc_snaphots__disabled)]
def send_extra_snap_for_enabled_agents(evt : Event; var loc_snapshots__sendExtraSnap : bool&)
  loc_snapshots__sendExtraSnap = true //todo: this must happen for each player, not just the first one


def accumulate_debug_data(var loc_snapshots_debug__countByRange : IntList;
                          var loc_snapshots_debug__countByType : Object;
                          snapshots : array<SnapshotEntityData>)
  for snap in snapshots
    if length(loc_snapshots_debug__countByRange) <= int(snap.rangeIdx)
      resize(loc_snapshots_debug__countByRange, int(snap.rangeIdx) + 1)
    loc_snapshots_debug__countByRange[snap.rangeIdx]++
    let tmpl = getEntityTemplateName(snap.eid)
    if !empty(tmpl)
      let parts <- split(tmpl, "+")
      var counts = get_IPoint2(loc_snapshots_debug__countByType, parts[0]) ?? int2()
      counts.x++
      set(loc_snapshots_debug__countByType, parts[0], counts)
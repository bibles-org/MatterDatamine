options no_aot
require app
require ecs
require ecs.common
require strings
require daslib.strings_boost
require math.base
require DngNet
require DagorMath
require DagorDebug3D
require DagorConsole
require game.events.events_active_matter
require game.es.loc_snapshots_common

let ACBLUE = E3DCOLOR(0xFF6666FF)
let ACINDI = E3DCOLOR(0xFF0000ee)
let ACRED = E3DCOLOR(0xFFFF1111)
let ACGREEN = E3DCOLOR(0xFF00FF00)
let ACYELLOW = E3DCOLOR(0xFFFFFF00)
let ACORANGE = E3DCOLOR(0xFFFF7700)
let ACMAGENTA = E3DCOLOR(0xFFFF00FF)
let ACCYAN = E3DCOLOR(0xFF00FFFF)
let ACWHITE = E3DCOLOR(0xFFFFFFFF)


[es(tag=(gameClient, net, dev), no_order, REQUIRE=loc_snapshots_debug)]
def debug_loc_snapshots(act : UpdateStageInfoRenderDebug; loc_snaphots__debugRadius : float = 60.0)
  find_query() <| $ [es] (camera__active : bool; transform aka cam_transform : float3x4)
    if camera__active
      query() <| $ [es(REQUIRE_NOT=loc_snapshots__dontUpdate)] (loc_snaphots__disabled : Tag const?;
                                                                loc_snapshots__snapshotData : LocSnapshotsList;
                                                                loc_snapshots__isInExtrapolation : bool;
                                                                loc_snapshots__timeOffset : float;
                                                                loc_snapshots__targetTimeOffset : float;
                                                                loc_snapshots__extrapolationDiscrepancy : float3;
                                                                transform aka agent_transform : float3x4)
        if distance_sq(cam_transform[3], agent_transform[3]) < square(loc_snaphots__debugRadius)
          if loc_snaphots__disabled != null
            draw_debug_tehedron_buffered(agent_transform[3], 1.0, ACRED, 1)
            return
          let curTime = get_sync_time()
          let interpTime = curTime - loc_snapshots__timeOffset
          let debugScale = 2.0
          let up = float3(0, 1, 0)
          let side = float3(1, 0, 0)
          let agentHeight = 1.7
          let agentHeightPos = up * agentHeight
          var bufferCount = 0
          for snap in loc_snapshots__snapshotData
            let color = snap.atTime > interpTime ? ACYELLOW : ACWHITE
            //Draw snapshot on the timeline:
            draw_debug_circle_buffered(agent_transform[3] + agentHeightPos + side * debugScale * (curTime - snap.atTime), side, 0.1, color, 4, 1)
            bufferCount += snap.atTime > interpTime ? 1 : 0
          //Draw timeline:
          let timelineColor = bufferCount > 0 ? ACWHITE : ACRED
          draw_debug_line_buffered(agent_transform[3] + agentHeightPos, agent_transform[3] + agentHeightPos + side * debugScale, timelineColor, 1)
          //Draw snapshots buffer (how many snapshots are ahead of the current time)
          let bufferColor = bufferCount > 2 ? ACGREEN : (bufferCount > 1 ? ACYELLOW : ACRED)
          for i in range(bufferCount)
            draw_debug_sphere_buffered(agent_transform[3] + up * (agentHeight + 0.15 + 0.1 * float(i)), 0.05, bufferColor, 4, 1)
          //Draw currentinterp time on the timeline:
          draw_debug_circle_buffered(agent_transform[3] + agentHeightPos + side * debugScale * (curTime - interpTime), side, 0.1, ACBLUE, 4, 1)
          if loc_snapshots__isInExtrapolation
            draw_debug_circle_buffered(agent_transform[3] + agentHeightPos + side * debugScale * (curTime - interpTime), side, 0.15, ACMAGENTA, 4, 1)

          //Draw snapshot locations
          var prev : float3
          for snap in loc_snapshots__snapshotData
            let color = snap.atTime > interpTime ? ACYELLOW : ACWHITE
            draw_debug_tehedron_buffered(snap.pos + up, 0.1, color, 1)
            if snap.blink
              draw_debug_sphere_buffered(snap.pos + up, 0.15, color, 12, 1)
            if prev != float3()
              draw_debug_line_buffered(prev + up, snap.pos + up, color, 1)
            prev = snap.pos

          //Draw timespeed changing
          if loc_snapshots__targetTimeOffset != loc_snapshots__timeOffset
            draw_debug_circle_buffered(agent_transform[3] + up * 2.0, up, 0.6, ACCYAN, 7, 100)

          if loc_snapshots__extrapolationDiscrepancy != float3()
            draw_debug_line_buffered(agent_transform[3] + up * 0.5, agent_transform[3] + up * 0.5 - loc_snapshots__extrapolationDiscrepancy, ACBLUE, 1)
    return camera__active


[console_cmd(name="am.debug_snaphots")]
def console_debug_snaphots()
  var hasDebug = false
  query() <| $ [es(REQUIRE=loc_snapshots_debug)] (eid : EntityId)
    destroyEntity(eid)
    hasDebug = true
  if !hasDebug
    createEntity("loc_snapshots_debug")
  query() <| $ [es(REQUIRE=hero)] (eid : EntityId)
    send_net_event(eid, CmdToggleSnapshotDebug())


[es(tag=(server, dev), on_event=CmdToggleSnapshotDebug)]
def toggle_server_snapshot_debug(evt : Event; var hero_awareness_debug__enabled : bool&)
  hero_awareness_debug__enabled = !hero_awareness_debug__enabled


def per_second_value(count : int; interval : float)
  return int(ceil(float(count) / interval))


[es(tag=(gameClient, dev))]
def display_snapshot_stat_info(evt : EventSnapshotsDebugInfo; hero_awareness_debug__tallyInterval : float)
  var totalSnaps, totalEntities : int
  let outStr = build_string() <| $(var str)
    for snapInfo, entityInfo, idx in *evt.snapsCounts, *evt.eidsCounts, iter_range(*evt.snapsCounts)
      if idx % 5 == 0
        str |> write("     ")
      totalSnaps += snapInfo
      totalEntities += entityInfo
      str |> write("| ")
      str |> write(fmt(":2d", per_second_value(snapInfo, hero_awareness_debug__tallyInterval)))
      str |> write(" ")
      str |> write(fmt(":2d", entityInfo))
      str |> write(" ")
  let totalSnapsStr = fmt(":3d", per_second_value(totalSnaps, hero_awareness_debug__tallyInterval))
  let totalEntitiesStr = fmt(":3d", totalEntities)
  visual_log("snaps: {totalSnapsStr} entities: {totalEntitiesStr} {outStr}")


[es(tag=(server, net), no_order)]
def gather_snapshot_monster_info_and_report(act : UpdateStageInfoAct;
                                            loc_snapshots_debug__reportInterval : float;
                                            var loc_snapshots_debug__countByType : Object;
                                            var loc_snapshots_debug__countByRange : IntList;
                                            var loc_snapshots_debug__reportAt : float&)
  if loc_snapshots_debug__reportAt < act.curTime
    let timeDelta = act.curTime - loc_snapshots_debug__reportAt + loc_snapshots_debug__reportInterval
    loc_snapshots_debug__reportAt = act.curTime + loc_snapshots_debug__reportInterval
    var countPerType : table<string; int2>
    query() <| $ [es(REQUIRE=loc_snapshots__snapshotData)] (eid : EntityId; loc_snaphots__disabled : Tag const?)
      let tmpl = getEntityTemplateName(eid)
      if !empty(tmpl)
        let parts <- split(tmpl, "+")
        var creatureCounts : int2
        if key_exists(countPerType, parts[0])
          creatureCounts = countPerType.get_value(parts[0])
        if loc_snaphots__disabled == null
          creatureCounts.x++
        else
          creatureCounts.y++
        countPerType.insert(parts[0], creatureCounts)

    var total : int4
    for t in loc_snapshots_debug__countByType
      let creatureCount = countPerType?[t.key] ?? int2()
      let val = get_IPoint2(t.value) ?? int2()
      total.x += val.x
      total.y += val.y
      total.z += creatureCount.x
      total.w += creatureCount.y

    let snapInfoStr = build_string() <| $(var str)
      str |> write("SNAP INFO ({timeDelta}):\n")
      str |> write("\tTotal \tsnaps: {total.x}\treliable snaps: {total.y}\tactive : {total.z}\tsleeping: {total.w}\n")
      for t in loc_snapshots_debug__countByType
        let val = get_IPoint2(t.value) ?? int2()
        let creatureCount = countPerType?[t.key] ?? int2()
        str |> write("\t{t.key} \tsnaps: {val.x}\treliable snaps: {val.y}\tactive : {creatureCount.x}\tsleeping: {creatureCount.y}\n")
    print(snapInfoStr)

    print("SNAPS BY RANGE:")
    for idx, r in iter_range(loc_snapshots_debug__countByRange), loc_snapshots_debug__countByRange
      print("\t{idx} \tsnaps: {r}")
    clear(loc_snapshots_debug__countByType)
    clear(loc_snapshots_debug__countByRange)

    var recieversCount = 0
    query() <| $ [es(REQUIRE=hero_awareness__rangeStep)] (possessedByPlr : EntityId)
      query(possessedByPlr) <| $ [es] (connid : int; disconnected : bool)
        if connid >= 0 && !disconnected
          recieversCount++

    print("SNAPS TO PLAYERS: {recieversCount}")
require ecs
require ecs.common
require app
require math.base
require math.random
require pathfinder
require Grid
require DagorMath
require game.es.level_common
require game.es.grav_zones_common
require game.events.events_active_matter


let XENOHOUND_LOG = "[XENOHOUND]"
let XENOHOUND_EVENT_ACTIVE = 1


[es(tag=server, on_appear)]
def init_xenohound_event(evt : Event;
                         xenohound_event__radius : float2;
                         xenohound_event__targetEid : EntityId;
                         xenohound_event__scaledDifficulty : int;
                         xenohound_event__spawnPerDifficulty : int;
                         xenohound_event__durationPerDifficulty : int;
                         var xenohound_event__spawnsPerPlayer : int2&;
                         var xenohound_event__duration : float2&;
                         var xenohound_event__seed : int&;
                         var xenohound_event__leftToSpawn : int&)
  xenohound_event__spawnsPerPlayer.x += xenohound_event__scaledDifficulty * xenohound_event__spawnPerDifficulty
  xenohound_event__spawnsPerPlayer.y += xenohound_event__scaledDifficulty * xenohound_event__spawnPerDifficulty
  xenohound_event__duration.x += float(xenohound_event__durationPerDifficulty * xenohound_event__spawnPerDifficulty)
  xenohound_event__duration.y += float(xenohound_event__durationPerDifficulty * xenohound_event__spawnPerDifficulty)

  query(xenohound_event__targetEid) <| $ [es] (transform : float3x4; team aka original_team : int)
    var playerCount = 0
    var allFromTheSameTeam = true
    let sphere = BSphere3(transform[3], xenohound_event__radius.y)
    for_each_entity_in_grid(ecs_hash("humans"), sphere, GridEntCheck.POS) <| $(human_eid : EntityId)
      query(human_eid) <| $ [es(REQUIRE_NOT=deadEntity, REQUIRE=heroForPlayer)] (team aka another_team : int)
        allFromTheSameTeam &&= another_team == original_team
        playerCount++
    if !allFromTheSameTeam
      playerCount /= 2 //it's complicated as it is
      playerCount = clamp(playerCount, 1, 3)
    if xenohound_event__seed == 0
      xenohound_event__seed = int(uint(xenohound_event__targetEid))
    for _ in range(playerCount)
      xenohound_event__leftToSpawn += _rnd_int(xenohound_event__seed, xenohound_event__spawnsPerPlayer)
    print("{XENOHOUND_LOG} event for <{xenohound_event__targetEid}> STARTS.\nSeed {xenohound_event__seed}. Will spawn {xenohound_event__leftToSpawn} creatures at {transform[3]}")


[es(tag=server, no_order)]
def xenohound_event_es(act : ParallelUpdateFrameDelayed;
                       eid : EntityId;
                       xenohound_event__targetEid : EntityId;
                       xenohound_event__interval : float;
                       xenohound_event__spawnsPerPortal : int2;
                       var xenohound_event__leftToSpawn : int&;
                       var xenohound_event__state : int&;
                       var xenohound_event__updateAt : float&)
  if xenohound_event__updateAt < act.curTime
    xenohound_event__updateAt = act.curTime + xenohound_event__interval
    if xenohound_event__state == XENOHOUND_EVENT_ACTIVE
      var numActivePortals = 0
      query() <| $ [es] (xenohound_portal__eventEid : EntityId)
        if xenohound_portal__eventEid == eid
          numActivePortals++
      if numActivePortals == 0
        destroyEntity(eid)
        print("{XENOHOUND_LOG} event for <{xenohound_event__targetEid}> is COMPLETE")
    elif xenohound_event__leftToSpawn > 0
      let thisCount = min(xenohound_event__leftToSpawn, rnd_int(xenohound_event__spawnsPerPortal))
      if spawn_xenohound_portal(eid, thisCount)
        xenohound_event__leftToSpawn -= thisCount
    else
      xenohound_event__state = XENOHOUND_EVENT_ACTIVE


def spawn_xenohound_portal(eid : EntityId; count : int)
  var res = false
  query(eid) <| $ [es] (xenohound_event__targetEid : EntityId;
                        xenohound_event__minDstBetweenPortalsSq : float;
                        xenohound_event__radius : float2;
                        xenohound_event__portalTemplate : string;
                        xenohound_event__xenoTemplate : string;
                        xenohound_event__duration : float2;
                        var xenohound_event__seed : int&)
    query(xenohound_event__targetEid) <| $ [es] (transform : float3x4; isAlive : bool)
      if !isAlive
        res = true
        return
      var tries = 10
      while --tries > 0
        let horOffset = x0y(rnd_point_on_ring(xenohound_event__seed, xenohound_event__radius.x, xenohound_event__radius.y))
        let vertOffset = float3(.0, xenohound_event__radius.y * _rnd_float(xenohound_event__seed, -1.0, 1.0), .0)
        let rootPos = transform[3] + horOffset + vertOffset
        var pos = rootPos
        var poly : dtPolyRef
        if !project_to_nearest_navmesh_point(pos, float3(1.0, 2.5 + xenohound_event__radius.y, 1.0), poly)
          continue
        if !is_polygon_accessible(poly)
          continue

        var tooClose = false
        find_query() <| $ [es(REQUIRE=xenohound_portal__eventEid)] (transform : float3x4)
          tooClose = distance_sq(transform[3], pos) < xenohound_event__minDstBetweenPortalsSq
          return tooClose
        if !tooClose
          createEntity(xenohound_event__portalTemplate) <| $(var init)
            var tm = IDENT_TM
            tm[3] = pos - get_grav_dir(pos)
            init |> set("transform", tm)
            init |> set("xenohound_portal__eventEid", eid)
            init |> set("xenohound_portal__spawnsLeft", count)
            init |> set("xenohound_portal__xenoTemplate", xenohound_event__xenoTemplate)
            init |> set("xenohound_portal__targetEid", xenohound_event__targetEid)
            init |> set("xenohound_portal__endAt", get_sync_time() + rnd_float(xenohound_event__duration))
          res = true
          return
  return res


def x0y(p2 : float2)
  return float3(p2.x, .0, p2.y)


[es(tag=server, no_order)]
def xenohound_portal_es(act : ParallelUpdateFrameDelayed;
                        eid : EntityId;
                        transform : float3x4;
                        xenohound_portal__interval : float;
                        xenohound_portal__endAt : float;
                        xenohound_portal__spawnCooldown : float2;
                        xenohound_portal__xenoTemplate : string;
                        xenohound_portal__targetEid : EntityId;
                        var xenohound_portal__spawnlings : EidList;
                        var xenohound_portal__spawnsLeft : int&;
                        var xenohound_portal__updateAt : float&)
  if xenohound_portal__updateAt < act.curTime
    if xenohound_portal__spawnsLeft > 0
      xenohound_portal__updateAt = act.curTime + rnd_float(xenohound_portal__spawnCooldown)
      let spawnling = createEntity(xenohound_portal__xenoTemplate) <| $(var init)
        init |> set("transform", transform)
        init |> set("walker_agent__targetEid", xenohound_portal__targetEid)
        init |> set("walker_agent__prevTargetEid", xenohound_portal__targetEid)
        init |> set("spawnling__parentEid", eid)
        init |> set("xenohound_creature__recallAt", xenohound_portal__endAt)
      xenohound_portal__spawnlings |> push(spawnling)
      xenohound_portal__spawnsLeft--
    elif length(xenohound_portal__spawnlings) == 0
      destroyEntity(eid)
    else
      xenohound_portal__updateAt = act.curTime + xenohound_portal__interval


[es(tag=server, on_disappear, on_event=EventEntityDied, REQUIRE=xenohound_creature__recallAt)]
def erase_xenohound_from_portal_on_disappear(evt : Event; eid, spawnling__parentEid : EntityId)
  query(spawnling__parentEid) <| $ [es] (var xenohound_portal__spawnlings : EidList)
    let idx = find_index(xenohound_portal__spawnlings, eid)
    if idx >= 0
      erase(xenohound_portal__spawnlings, idx)


[es(on_appear, after=nphys_randomize_animchar_scale)]
def xenohound_scale_on_appear_init(evt : Event;
                                   xenohound_scale_on_appear__scaleTime : float;
                                   xenohound_scale_on_appear__minScale : float;
                                   var nPhys__animcharScale : float&;
                                   var xenohound_scale_on_appear__finishAt : float&;
                                   var xenohound_scale_on_appear__initialScale : float&)
  xenohound_scale_on_appear__initialScale = nPhys__animcharScale
  xenohound_scale_on_appear__finishAt = get_sync_time() + xenohound_scale_on_appear__scaleTime
  nPhys__animcharScale = xenohound_scale_on_appear__minScale


[es(tag=gameClient, before=update_nphys_scale)]
def xenohound_scale_on_appear_update(upd : UpdateStageInfoAct;
                                     xenohound_scale_on_appear__scaleTime : float;
                                     xenohound_scale_on_appear__finishAt : float;
                                     xenohound_scale_on_appear__minScale : float;
                                     xenohound_scale_on_appear__initialScale : float;
                                     var nPhys__animcharScale : float&)
  let t = clamp(1.0 - (xenohound_scale_on_appear__finishAt - upd.curTime) / (xenohound_scale_on_appear__scaleTime), 0.0, 1.0)
  nPhys__animcharScale = lerp(xenohound_scale_on_appear__minScale, xenohound_scale_on_appear__initialScale, t)


[es(after=xenohound_scale_on_appear_update)]
def xenohound_scale_on_appear_finish(upd : UpdateStageInfoAct;
                                     eid : EntityId;
                                     xenohound_scale_on_appear__finishAt : float)
  if upd.curTime >= xenohound_scale_on_appear__finishAt
    removeSubTemplate(eid, "xenohound_scale_on_appear")


[es(on_disappear)]
def xenohound_scale_on_appear_onDestroy(evt : Event;
                                        xenohound_scale_on_appear__initialScale : float;
                                        var nPhys__animcharScale : float&)
  nPhys__animcharScale = xenohound_scale_on_appear__initialScale

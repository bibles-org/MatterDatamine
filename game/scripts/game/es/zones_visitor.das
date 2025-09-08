require ecs
require DngNet
require zones
require game.events.events_game
require ecs.common
require math.base
require DagorMath
require Grid


def leave_all_zones(visitor_eid : EntityId; var zones_in : EidList)
  while length(zones_in) != 0
    let last = length(zones_in) - 1
    let zoneEid = zones_in[last]
    zones_in |> erase(last)
    sendEvent(zoneEid, EventZoneLeave(visitorEid = visitor_eid))


def leave_all_from_zone(zone_eid : EntityId)
  ecs::query() <| $ [es] (eid : EntityId; var zones_visitor__zonesIn : EidList)
    let idx = zones_visitor__zonesIn |> find_index(zone_eid)
    if idx >= 0
      zones_visitor__zonesIn |> erase(idx)
      sendEvent(zone_eid, EventZoneLeave(visitorEid = eid))


def update_is_inside(cur_time : float; zone_eid : EntityId; visitor_pos : float3; update)
  ecs::query(zone_eid) <| $ [es] (transform : float3x4;
                                  sphere_zone__radius : float;
                                  sphere_zone__truncateBelow : float const?;
                                  zone__active : bool = true;
                                  var zone__nextCheckTime : float&;
                                  zone__updateInterval : float = 0.0)
    if cur_time < zone__nextCheckTime
      return
    zone__nextCheckTime = cur_time + zone__updateInterval
    let isInside = zone__active && is_inside_truncated_sphere_zone(visitor_pos, transform, sphere_zone__radius, sphere_zone__truncateBelow)
    invoke(update, isInside)

  ecs::query(zone_eid) <| $ [es(REQUIRE=box_zone)] (transform : float3x4;
                                                    zone__active : bool = true;
                                                    var zone__nextCheckTime : float&;
                                                    zone__updateInterval : float = 0.0)
    if cur_time < zone__nextCheckTime
      return
    zone__nextCheckTime = cur_time + zone__updateInterval
    let isInside = zone__active && (IDENT_BBOX & (inverse(transform) * visitor_pos))
    invoke(update, isInside)


def for_each_zone(old; current; update)
  for zoneEid in old
    invoke(update, zoneEid)
  for zoneEid in current
    invoke(update, zoneEid)


[es(tag=server, after=after_net_phys_sync, REQUIRE_NOT=sleeping_monster)]
def zones_visitor_update_es(info : UpdateStageInfoAct;
                            eid : EntityId;
                            transform : float3x4;
                            isAlive : bool = true;
                            var zones_visitor__zonesIn : EidList;
                            zones_visitor__triggerTag : string;
                            zones_visitor__disabled : bool = false;
                            zones_visitor__searchRad = 10f)
  if !isAlive || zones_visitor__disabled
    leave_all_zones(eid, zones_visitor__zonesIn)
    return
  let visitorEid = eid
  let visitorPos = transform[3]

  let bsphere = BSphere3(transform[3], zones_visitor__searchRad)
  let zones_visitor__triggerTagHash = ecs_hash(zones_visitor__triggerTag)
  gather_entities_in_grid(ecs_hash("zones"), bsphere, GridEntCheck.BOUNDING) <| $(zones)
    for_each_zone(zones_visitor__zonesIn, zones) <| $(zoneEid : EntityId)
      if !has(zoneEid, zones_visitor__triggerTag, zones_visitor__triggerTagHash)
        return

      update_is_inside(info.curTime, zoneEid, visitorPos) <| $(is_inside : bool)
        let idx = zones_visitor__zonesIn |> find_index(zoneEid)
        let wasInside = idx != -1
        if is_inside == wasInside
          return
        if is_inside
          zones_visitor__zonesIn |> push(zoneEid)
          sendEvent(zoneEid, EventZoneEnter(visitorEid = visitorEid))
        else
          zones_visitor__zonesIn |> erase(idx)
          sendEvent(zoneEid, EventZoneLeave(visitorEid = visitorEid))


[es(tag=server, on_disappear, REQUIRE=zone__active)]
def zone_destroyed_es(evt : Event; eid aka zone_eid : EntityId)
  ecs::query() <| $ [es] (eid aka visitor_eid : EntityId;
                          var zones_visitor__zonesIn : EidList)
    let idx = zones_visitor__zonesIn |> find_index(zone_eid)
    if idx >= 0
      zones_visitor__zonesIn |> erase(idx)
      // Send it immediately because we are destroyed already
      sendEventImmediate(zone_eid, EventZoneLeave(visitorEid = visitor_eid))


[es(tag=server, track=zone__active)]
def zone_deactivated_es(evt : Event; eid : EntityId; zone__active : bool)
  if !zone__active
    leave_all_from_zone(eid)


[es(tag=server, on_disappear)]
def zones_visitor_destroyed_es(evt : Event; eid : EntityId; var zones_visitor__zonesIn : EidList)
  leave_all_zones(eid, zones_visitor__zonesIn)

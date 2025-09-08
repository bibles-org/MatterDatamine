require ecs
require app
require net
require Grid
require math.base
require DagorMath
require DagorSystem
require DagorRandom
require DagorDataBlock
require DaWeaponProps
require ecs.soa_template
require game.utils.net_utils
require game.events.events_game
require game.events.inventory_events
require game.events.events_active_matter
require game.es.activity_helper_checks_common
require active_matter.game.es.moving_zone_common
require math.easing


[es(tag=server, on_appear, REQUIRE=possessedByPlr, REQUIRE_NOT=(encounter_guard))]
def activity_helper_checks_appear(evt : Event;
                                  eid : EntityId;
                                  transform : float3x4)
  find_query() <| $ [soa_blk, es] (activity_helper_checks__noActivityMaxTime : float;
                                   var activity_helper_checks_data : ActivityHelperChecksData_SOA)
    activity_helper_checks_data |> push() <| ActivityHelperChecksData(
      activity_helper_checks__eid = eid,
      activity_helper_checks__startSearchActivityAt = get_sync_time() + activity_helper_checks__noActivityMaxTime,
      activity_helper_checks__lastCheckPosition = transform[3]
    )
    return true


[soa_es, es(tag=server, no_order)]
def activity_helper_checks_update(act : UpdateStageInfoAct;
                                  activity_helper_checks__checkTime : float;
                                  activity_helper_checks__noActivityMaxTime : float;
                                  activity_helper_checks__checkDistanceSq : float;
                                  activity_helper_checks__activityDistanceRangeSq : float2;
                                  activity_helper_checks__searchRange = float2(10, 30);
                                  var activity_helper_checks__nextCheckAt : float&;
                                  var activity_helper_checks_data : ActivityHelperChecksData_SOA)
  if act.curTime < activity_helper_checks__nextCheckAt
    return
  activity_helper_checks__nextCheckAt = act.curTime + activity_helper_checks__checkTime

  let movingZone = get_target_moving_zone()
  let zoneRadiusSq = square(movingZone.radius)

  for data in activity_helper_checks_data
    query(data.activity_helper_checks__eid) <| $ [es(REQUIRE_NOT=deadEntity)] (transform aka hero_transform : float3x4)
      assume currentPoint = data.activity_helper_checks__currentPoint
      if length_sq(currentPoint) > 0.0 && distance_sq(currentPoint, hero_transform[3]) < activity_helper_checks__activityDistanceRangeSq.x
        data.activity_helper_checks__startSearchActivityAt = act.curTime + activity_helper_checks__noActivityMaxTime
        currentPoint = float3(0.0)
        return

      if length_sq(currentPoint) > 0.0 && distance_sq(data.activity_helper_checks__lastCheckPosition, hero_transform[3]) < activity_helper_checks__checkDistanceSq
        data.activity_helper_checks__startSearchActivityAt += activity_helper_checks__checkTime
      data.activity_helper_checks__lastCheckPosition = hero_transform[3]

      if act.curTime < data.activity_helper_checks__startSearchActivityAt
        return
      data.activity_helper_checks__startSearchActivityAt = act.curTime + activity_helper_checks__noActivityMaxTime

      let needsMed = does_hero_need_med(data.activity_helper_checks__eid)
      let needsAmmoIds = get_desirable_ammo_ids(data.activity_helper_checks__eid)

      var coords : array<float3>
      let minSearchRadSq = square(activity_helper_checks__searchRange.x)
      var nearestLootPoint : float3
      var wasLootDesirable = false
      var nearestLootDistSq = square(activity_helper_checks__searchRange.y)

      let sphere = BSphere3(hero_transform[3], activity_helper_checks__searchRange.y)
      for_each_entity_in_grid(ecs_hash("loot"), sphere, GridEntCheck.BOUNDING) <| $(eid : EntityId; pos : float3)
        if distance_sq(pos, movingZone.pos) > zoneRadiusSq
          return
        let distSq = distance_sq(pos, hero_transform[3])
        if distSq >= minSearchRadSq
          query(eid) <| $ [es] (ammo_holder__id : int = 0;
                                item_heal : Tag const?;
                                item__currentBoxedItemCount = -1;
                                item__rarity = "common")
            let isEmpty = item__currentBoxedItemCount == 0
            let isDesirableAmmo = length(needsAmmoIds) > 0 && ammo_holder__id != 0 && !isEmpty && find_index(needsAmmoIds, ammo_holder__id) != -1
            let isDesirableMed = length(needsAmmoIds) == 0 && item_heal != null && !isEmpty && needsMed
            let isDesirableMisc = item__rarity != "common"
            let isDesirableSpecial = isDesirableAmmo || isDesirableMed
            if isDesirableMisc || isDesirableSpecial
              if distSq <= nearestLootDistSq || !wasLootDesirable && isDesirableSpecial
                if isDesirableSpecial || !wasLootDesirable
                  wasLootDesirable = isDesirableSpecial
                  nearestLootDistSq = distSq
                  nearestLootPoint = pos
      if length_sq(nearestLootPoint) > 0.0
        coords |> push(nearestLootPoint)

      nearestLootDistSq = square(activity_helper_checks__searchRange.y)
      for_each_entity_in_grid(ecs_hash("interactable"), sphere, GridEntCheck.BOUNDING) <| $(eid : EntityId; pos : float3)
        if eid |> has("external_inventory_container") && eid |> has("itemContainer")
          if distance_sq(pos, movingZone.pos) > zoneRadiusSq
            return
          let distSq = distance_sq(pos, hero_transform[3])
          if distSq <= nearestLootDistSq && distSq >= minSearchRadSq
            nearestLootDistSq = distSq
            nearestLootPoint = pos
      if length_sq(nearestLootPoint) > 0.0
        coords |> push(nearestLootPoint)

      if length(coords) > 0
        let point = coords[rnd_int(0, length(coords) - 1)]
        send_net_event(data.activity_helper_checks__eid, ShowActivityHelperPoint(position = point), target_entity_conn(data.activity_helper_checks__eid))
        currentPoint = point


def private refresh_timer(hero_eid : EntityId)
  find_query() <| $ [soa_blk, es] (activity_helper_checks__noActivityMaxTime : float;
                                   var activity_helper_checks_data : ActivityHelperChecksData_SOA)
    for data in activity_helper_checks_data
      if data.activity_helper_checks__eid == hero_eid
        data.activity_helper_checks__startSearchActivityAt = get_sync_time() + activity_helper_checks__noActivityMaxTime
        data.activity_helper_checks__currentPoint = data.activity_helper_checks__currentPoint //noop to mute warnings
        data.activity_helper_checks__lastCheckPosition = data.activity_helper_checks__lastCheckPosition //noop to mute warnings
        break
    return true



def does_hero_need_med(hero_eid : EntityId, min_count = 4)
  var count = 0
  find_query() <| $ [es(REQUIRE=item_heal, REQUIRE_NOT=transform)] (item__humanOwnerEid : EntityId;
                                                                    item__currentBoxedItemCount = -1)
    if (item__humanOwnerEid == hero_eid)
      count += item__currentBoxedItemCount != -1 ? item__currentBoxedItemCount : 1
    return count < min_count
  return count < min_count


//Ignores gunShellProps
def get_desirable_ammo_ids(hero_eid : EntityId; min_supply_mult  = 2.0)
  var gun : array<int>
  var gunAmmoCount : array<int>
  var gunAmmoMax : array<int>
  var gunHolderIds : array<array<int>>

  var relevantHolderTypes : array<int>
  var relevantHolderTypeCurrentAmmo : array<int>
  var relevantHolderTypeMaxAmmo : array<int>

  //Collect guns info
  query(hero_eid) <| $ [es] (human_weap__gunEids : EidList)
    for gunIdx in iter_range(human_weap__gunEids)
      var holderIdsForThisGun : array<int>
      query(human_weap__gunEids[gunIdx]) <| $ [es] (gun__ammo : int;
                                                    gun__maxAmmo : int;
                                                    gun__ammoHolderIds : IntList;
                                                    gun__secondaryAmmoHolderIds : IntList const?)
        gun |> push(gunIdx)
        gunAmmoCount |> push(gun__ammo)
        gunAmmoMax |> push(gun__secondaryAmmoHolderIds == null ? gun__maxAmmo : 0) //mag size for magazine type weapons
        for holderId in gun__ammoHolderIds
          holderIdsForThisGun |> push(holderId)
          if find_index(relevantHolderTypes, holderId) == -1
            relevantHolderTypes |> push(holderId)
            relevantHolderTypeCurrentAmmo |> push(0)
            relevantHolderTypeMaxAmmo |> push(0)
        if gun__secondaryAmmoHolderIds != null
          for holderId in *gun__secondaryAmmoHolderIds
            holderIdsForThisGun |> push(holderId)
            if find_index(relevantHolderTypes, holderId) == -1
              relevantHolderTypes |> push(holderId)
              relevantHolderTypeCurrentAmmo |> push(0)
              relevantHolderTypeMaxAmmo |> push(0)
      gunHolderIds |> emplace(holderIdsForThisGun)

  //Collect ammo info
  query() <| $ [es(REQUIRE_NOT=(item_heal, transform))] (item__humanOwnerEid : EntityId;
                                                         ammo_holder__id : int;
                                                         item__currentBoxedItemCount : int;
                                                         item_holder__maxItemCount = -1;
                                                         item__countPerStack = -1)
    if item__humanOwnerEid == hero_eid
      let holderTypeIdx = find_index(relevantHolderTypes, ammo_holder__id)
      if holderTypeIdx != -1
        relevantHolderTypeCurrentAmmo[holderTypeIdx] += item__currentBoxedItemCount
        if item__countPerStack > 0
          relevantHolderTypeMaxAmmo[holderTypeIdx] = item__countPerStack
        if item_holder__maxItemCount > 0
          relevantHolderTypeMaxAmmo[holderTypeIdx] = item_holder__maxItemCount

  //Calculate gun ammo
  for i in iter_range(gun)
    for holderId in gunHolderIds[i]
      let idx = find_index(relevantHolderTypes, holderId)
      gunAmmoCount[i] += relevantHolderTypeCurrentAmmo[idx]
      gunAmmoMax[i] = gunAmmoMax[i] == 0 ? max(gunAmmoMax[i], relevantHolderTypeMaxAmmo[idx]) : gunAmmoMax[i]
    gunAmmoMax[i] = gunAmmoMax[i] == 0 ? 30 : gunAmmoMax[i]


  var res : array<int>
  for i in iter_range(gun)
    if length(gunHolderIds[i]) > 0 && gunAmmoMax[i] > 0
      if float(gunAmmoCount[i]) < min_supply_mult * float(gunAmmoMax[i])
        for hId in gunHolderIds[i]
          if find_index(res, hId) == -1
            res |> push(hId)
  //for i in iter_range(gun)
  //  print("GunIndex {gun[i]} Ammo: {gunAmmoCount[i]} / {gunAmmoMax[i]} Holders: {length(gunHolderIds[i])}")
  //print("Desirable: {res}")
  return <- res


[unused_argument(trap_logger__lastTrapActivationTime, am_storage__value),
 es(tag=server,
    on_event=EventOnItemPickup,
    track=(trap_logger__lastTrapActivationTime, am_storage__value),
    REQUIRE=possessedByPlr, REQUIRE_NOT=encounter_guard)]
def activity_helper_checks_update_common_events(evt : Event;
                                                eid : EntityId;
                                                trap_logger__lastTrapActivationTime : float;
                                                am_storage__value : int)
  refresh_timer(eid)


[es(tag=server, REQUIRE=eid)]
def activity_helper_checks_update_weapon_events(evt : EventOnEquipingAsWeapon)
  if evt.fromInventoryEid == INVALID_ENTITY_ID
    refresh_timer(evt.heroEid)


[es(tag=server, REQUIRE=eid)]
def activity_helper_checks_update_weapon_mod_events(evt : EventOnEquipingAsWeaponMod)
  if evt.fromInventoryEid == INVALID_ENTITY_ID
    refresh_timer(evt.actorEid)


[es(tag=server, REQUIRE=eid)]
def activity_helper_checks_update_equipment_events(evt : EventOnEquipingAsEquipment)
  if evt.fromInventoryEid == INVALID_ENTITY_ID
    refresh_timer(evt.heroEid)


[es(tag=server, REQUIRE=eid)]
def activity_helper_checks_update_equipment_mod_events(evt : EventOnEquipingAsEquipmentMod)
  if evt.fromInventoryEid == INVALID_ENTITY_ID
    refresh_timer(evt.actorEid)


[es(tag=server, track=human_weap__lastShotAtTime)]
def activity_helper_checks_shoot_events(evt : Event; eid : EntityId; human_weap__lastShotAtTime : float)
  if human_weap__lastShotAtTime > 0.0
    refresh_timer(eid)


[es(tag=server)]
def activity_helper_checks_update_damage_events(evt : EventOnEntityHit)
  find_query() <| $ [soa_blk, es] (activity_helper_checks__noActivityMaxTime : float;
                                   var activity_helper_checks_data : ActivityHelperChecksData_SOA)
    for data in activity_helper_checks_data
      if data.activity_helper_checks__eid == evt.victim || data.activity_helper_checks__eid == evt.offender
        data.activity_helper_checks__startSearchActivityAt = get_sync_time() + activity_helper_checks__noActivityMaxTime
        data.activity_helper_checks__currentPoint = data.activity_helper_checks__currentPoint //noop to mute warnings
        data.activity_helper_checks__lastCheckPosition = data.activity_helper_checks__lastCheckPosition //noop to mute warnings
    return true


[unused_argument(objective__currentValue), es(tag=server, track=objective__currentValue)]
def activity_helper_checks_update_objectives_events(evt : Event;
                                                    objective__currentValue : int;
                                                    objective__playerEid : EntityId)
  var heroEid = INVALID_ENTITY_ID
  query(objective__playerEid) <| $ [es] (possessed : EntityId)
    heroEid = possessed
  if heroEid == INVALID_ENTITY_ID
    return
  refresh_timer(heroEid)


[es(tag=server)]
def activity_helper_checks_update_recognize_events(evt : CmdMarkItemRecognized; eid : EntityId)
  refresh_timer(eid)


[es(tag=gameClient, REQUIRE=hero)]
def activity_helper_add_point(evt : ShowActivityHelperPoint;
                              eid aka hero_eid : EntityId)
  var tm = IDENT_TM
  tm[3] = evt.position

  query() <| $ [es(REQUIRE=activity_helper_marker__ownerEid, REQUIRE_NOT=marker_self_destroy)] (eid : EntityId)
    addSubTemplate(eid, "marker_self_destroy")

  var activityDictanceRangeSq = float2(0, 0)
  find_query() <| $ [es] (activity_helper_checks__activityDistanceRangeSq : float2)
    activityDictanceRangeSq = activity_helper_checks__activityDistanceRangeSq
    return true

  createEntity("activity_helper_marker") <| $(var init)
    init |> set("transform", tm)
    init |> set("activity_helper_marker__ownerEid", hero_eid)
    init |> set("activity_helper_marker__activityDistanceRangeSq", activityDictanceRangeSq)


[es(tag=gameClient, REQUIRE_NOT=marker_self_destroy)]
def activity_helper_check_point(act : ParallelUpdateFrameDelayed;
                                eid : EntityId;
                                activity_helper_marker__ownerEid : EntityId;
                                transform aka point_transform : float3x4;
                                activity_helper_marker__activityDistanceRangeSq : float2;
                                var hud_marker__opacity : float&)
  query(activity_helper_marker__ownerEid) <| $ [es] (transform : float3x4)
    let distanceSq = distance_sq(point_transform[3], transform[3])
    if distanceSq < activity_helper_marker__activityDistanceRangeSq.x || activity_helper_marker__activityDistanceRangeSq.y < distanceSq
      hud_marker__opacity = 0.0
      destroyEntity(eid)
    else
      hud_marker__opacity = 1.0 - inQuad(distanceSq / activity_helper_marker__activityDistanceRangeSq.y)


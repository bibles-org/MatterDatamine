require ecs
require app
require math.base
require Grid
require DagorMath
require game.events.inventory_events


[es(tag=server, track=human_weap__lastShotAtTime)]
def spawn_attract_point_on_shoot(evt : Event;
                                 transform : float3x4;
                                 human_weap__lastShotAtTime : float;
                                 eid, human_weap__currentGunEid : EntityId;
                                 human_weap__throwMode : bool)
  if human_weap__lastShotAtTime < 0.0 || !human_weap__currentGunEid || human_weap__throwMode
    return

  var attractMagnitude, attractTtl, attractMaxMagnitude, attractMagnitudeStep : float
  let gunEid = human_weap__currentGunEid
  // NOTE: FIX: all guns have noise!
  let haveNoise = query(gunEid) <| $ [es] (gun_noise__attractMagnitude = 1f;
                                           gun_noise__attractTtl = 3.;
                                           gun_noise__attractMagnitudeStep = 1.05f;
                                           gun_noise__attractMaxMagnitude = 2f)
    attractMagnitude = gun_noise__attractMagnitude
    attractTtl = gun_noise__attractTtl
    attractMaxMagnitude = gun_noise__attractMaxMagnitude
    attractMagnitudeStep = gun_noise__attractMagnitudeStep

  if !haveNoise
    return

  let position = transform[3]
  let nearestAttractDist = 4f
  var found = false
  let bsphere = BSphere3(position, nearestAttractDist)
  let curTime = get_sync_time()
  find_entity_in_grid(ecs_hash("attract_point"), bsphere, GridEntCheck.POS) <| $(attractEid : EntityId)
    query(attractEid) <| $ [es(REQUIRE=shootAttractPoint)] (attract_point__ownerEid : EntityId;
                                                            var attract_point__magnitude : float&;
                                                            var game_effect__destroyAt : float?)
      if attract_point__ownerEid != eid
        return
      if game_effect__destroyAt != null
        *game_effect__destroyAt = max(*game_effect__destroyAt, attractTtl + curTime)
      attract_point__magnitude = max(attract_point__magnitude, attractMagnitude) * square(attractMagnitudeStep)
      attract_point__magnitude = min(attractMagnitude * attractMaxMagnitude, attract_point__magnitude)
      found = true
    return found

  if !found
    createEntity("shoot_attract_point") <| $(init)
      var tm : float3x4 = IDENT_TM
      tm[3] = position
      init |> set("transform", tm)
      init |> set("attract_point__magnitude", attractMagnitude)
      init |> set("game_effect__timeToDestroy", attractTtl)
      init |> set("attract_point__ownerEid", eid)

[es(tag=server, REQUIRE=eid)]
def spawn_attract_point_on_loot_pickup(evt : EventOnItemPickup; eid : EntityId)
  query(evt.itemEid) <| $ [es] (pickup_attract_point_creator__templateName : string; transform : float3x4)
    createEntity(pickup_attract_point_creator__templateName) <| $(init)
      init |> set("transform", transform)
      init |> set("attract_point__ownerEid", eid)


[es(tag=server, on_appear)]
def spawn_personal_attract_point_on_loot_pickup(evt : Event;
                                                var folower_attraction_point__endTimeAt : float&;
                                                attract_owner_point__duringTime : float = 40.)
  folower_attraction_point__endTimeAt = get_sync_time() + attract_owner_point__duringTime

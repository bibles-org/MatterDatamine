require ecs
require app
require ecs.safe
require game.events.events_game
require game.events.events_active_matter
require DngHuman
require game.es.human_self_resurrection_device_common
require pathfinder
require game.es.level_common
require DngNet
require math.base
require game.es.status_tip_common
require game.utils.team


def private log(text : string)
  print("[RESURRECT DEVICE]: {text}")


[es(tag=server, on_event=CmdDebriefingUseRespawnDeviceRequest)]
def use_respawn_device(evt : Event; possessed : EntityId; eid aka player_eid : EntityId; var player__stats : Object)
  let device = find_player_ressurection_device(player_eid)
  if device == INVALID_ENTITY_ID
    log("<{possessed}> doesn't have res device, usage prevented")
    return

  var alreadyAlive = true
  query(possessed) <| $ [es] (isAlive : bool)
    alreadyAlive = isAlive

  if alreadyAlive
    log("<{possessed}> is already alive, usage prevented")
    return

  query(device) <| $ [es] (resurrect_device__builderTm : float3x4)
    let statName = "resurrected_via_beacon"
    player__stats |> set(statName, 1 + player__stats[statName] ?? 0)
    sendEvent(player_eid, CmdSpawnEntity(tm = resurrect_device__builderTm))
    destroyEntity(device)
    log("<{device}> is used at {resurrect_device__builderTm[3]}")

  // remove previous cortical vault
  query() <| $[es(REQUIRE=cortical_vault)] (eid : EntityId;
                                            playerItemOwner : EntityId)
    if playerItemOwner == player_eid
      destroyEntity(eid)


[es(tag=server)]
def start_resurrect_device_countdown(evt : EventEntityDied; possessedByPlr : EntityId; team : int)
  var haveAliveTeammates = false
  var teammatesPlayer : array<EntityId>
  for_each_teammate_player(possessedByPlr, team) <| $(teammate_eid)
    query(teammate_eid) <| $[es] (possessed : EntityId)
      query(possessed) <| $[es] (isAlive : bool)
        haveAliveTeammates = isAlive
        teammatesPlayer |> push(teammate_eid)
  if haveAliveTeammates
    return

  teammatesPlayer |> push(possessedByPlr)
  for teammate in teammatesPlayer
    let device = find_player_ressurection_device(teammate)
    if device != INVALID_ENTITY_ID
      createEntity("resurrect_device_self_destruction_effect") <| $(init)
        set(init, "team", team)
        set(init, "game_effect__attachedTo", device)


[es(tag=server, on_appear)]
def init_resurrect_device_countdown(evt : Event;
                                    resurrect_device__onDeathWaitSeconds : float;
                                    var resurrect_device__destroyAt : float&)
  resurrect_device__destroyAt = get_sync_time() + resurrect_device__onDeathWaitSeconds


[es(tag=gameClient, on_appear)]
def resurrect_device_appear_client(evt : Event; playerOwnerEid : EntityId; var map_object__show : bool&)
  query(playerOwnerEid) <| $ [es] (possessed : EntityId)
    map_object__show = possessed |> has("hero")


[es(tag=server, no_order)]
def process_resurrect_device_self_destruction(upd : UpdateStageInfoAct; eid : EntityId; game_effect__attachedTo : EntityId; resurrect_device__destroyAt : float)
  if upd.curTime < resurrect_device__destroyAt || resurrect_device__destroyAt < 0.0
    return
  log("resurrect device <{game_effect__attachedTo}> expired")
  query(game_effect__attachedTo) <| $ [es] (thrown_self_resurrection_device__playerOwner : EntityId)
    sendEvent(thrown_self_resurrection_device__playerOwner, EventResurrectionDeviceExpired())
  destroyEntity(game_effect__attachedTo)
  destroyEntity(eid)


[es(tag=server, on_appear, REQUIRE=self_resurrection_device)]
def action_on_appear_resurrection_device(evt : Event;
                                         eid aka new_device_eid : EntityId;
                                         playerOwnerEid aka new_device_playerOwnerEid : EntityId;
                                         var resurrect_device__builderTm : float3x4&)
  query(new_device_playerOwnerEid) <| $[es] (possessed : EntityId)
    query(possessed) <| $[es] (transform : float3x4)
      resurrect_device__builderTm = transform
  query() <| $ [es(REQUIRE=self_resurrection_device)] (eid aka old_device_eid : EntityId;
                                                       playerOwnerEid aka old_device_playerOwnerEid : EntityId;
                                                       resurrect_device__destroyEffectTemplate : string;
                                                       transform : float3x4)
    if old_device_playerOwnerEid == new_device_playerOwnerEid && old_device_eid != new_device_eid
      destroyEntity(eid)
      createEntity(resurrect_device__destroyEffectTemplate) <| $(init)
        init |> set("transform", transform)
  log("device inited for player {new_device_playerOwnerEid}")


[es(tag=server, REQUIRE=self_resurrection_device)]
def resurect_device_destroyed(evt : EventEntityDied;
                              eid : EntityId;
                              transform : float3x4;
                              resurrect_device__noiseRadius : float;
                              resurrect_device__noise : float;
                              resurrect_device__destroyEffectTemplate : string)
  var tm = IDENT_TM
  tm[3] = transform[3]
  destroyEntity(eid)
  createEntity(resurrect_device__destroyEffectTemplate) <| $(init)
    init |> set("transform", transform)
  createEntity("loud_noise_oneshot") <| $(init)
    init |> set("loud_noise__radius", resurrect_device__noiseRadius)
    init |> set("loud_noise__noise", resurrect_device__noise)
    init |> set("loud_noise__pos", transform[3])


[es(tag=gameClient, on_disappear, REQUIRE=self_resurrection_device)]
def resurect_device_destroyed_on_client(evt : Event;
                                        playerOwnerEid : EntityId)
  find_query() <| $[es(REQUIRE=hero)] (possessedByPlr : EntityId)
    if possessedByPlr == playerOwnerEid
      create_status_tip("status_tip_resurect_device_destroyed")
    return true
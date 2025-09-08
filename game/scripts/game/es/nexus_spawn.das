require app
require ecs
require ecs.safe
require DngNet
require player
require rapidjson
require ecs.common
require game.es.level_common
require game.es.revive_common
require game.es.nexus_common
require game.es.nexus_loadout_common
require game.events.player_events
require game.events.events_game
require game.events.events_active_matter


def destroy_spawned_possessed_for_player(player_eid : EntityId)
  query(player_eid) <| $ [es] (var possessed : EntityId&)
    if possessed != INVALID_ENTITY_ID
      nexus_log("SPAWN", "Player <{player_eid}> possessed <{possessed}> is destroyed")
      destroyEntity(possessed)
      possessed = INVALID_ENTITY_ID
    else
      nexus_logwarn("SPAWN", "Tried to destroy player <{player_eid}> possessed, but it doesn't exists")


def give_loadout_to_nexus_player(player : EntityId)
  var didGenerate = false
  query(player) <| $ [es] (possessed : EntityId;
                           nexus_player_loadout__chosenIndex : int;
                           var nexus_player_loadout__takenIndex : int&;
                           var player__loadoutRecieved : bool&;
                           var initialHeroItems : Array)
    var isPossessedAlive = false
    query(possessed) <| $ [es] (isALive : bool)
      isPossessedAlive = isALive
    if isPossessedAlive
      return


    find_query() <| $ [es] (nexus_loadouts__owner : EntityId;
                            var nexus_loadouts__allLoadouts : Array)
      if nexus_loadouts__owner != player
        return false

      assume index = nexus_player_loadout__chosenIndex
      nexus_log("SPAWN", "Giving loadout {nexus_player_loadout__chosenIndex} to player <{player}>")
      var loadoutPtr : Object?
      if index < 0 || length(nexus_loadouts__allLoadouts) <= index
        nexus_logwarn("SPAWN", "give_loadout_to_nexus_player: index \"{index}\" is invalid")
        return true

      loadoutPtr = nexus_loadouts__allLoadouts[index] as Object
      if loadoutPtr == null
        nexus_logwarn("SPAWN", "give_loadout_to_nexus_player: loadout \"{index}\" not found from \"{length(nexus_loadouts__allLoadouts)}\"")
        return true

      assume loadout = *loadoutPtr
      if loadout.locked ?? false
        nexus_logwarn("SPAWN", "give_loadout_to_nexus_player: loadout \"{index}\" is locked")
        return true

      find_query() <| $ [es] (var nexus_battle_item_unique_id_holder__nextUniqueId : int64&)
        nexus_battle_item_unique_id_holder__nextUniqueId += 1l
        clear(initialHeroItems)
        generate_loadout_items(loadout, initialHeroItems, nexus_battle_item_unique_id_holder__nextUniqueId)
        player__loadoutRecieved = true
        nexus_player_loadout__takenIndex = index
        didGenerate = true
        return true
      return true
  return didGenerate



def try_start_player_spawn_sequence(player_eid : EntityId;
                                    nexus_spawn_controller__spawnedPlayers : EidList;
                                    cur_time : float;
                                    replace_forced : bool;
                                    destroy_previous_possessed : bool)
  query(player_eid) <| $ [es] (var player__spawnPlaceId : int&)
    player__spawnPlaceId = -1 // we decide who will appear where
  nexus_log("SPAWN", "Player <{player_eid}> is processing for spawn sequence start")
  if has_value(nexus_spawn_controller__spawnedPlayers, player_eid)
    nexus_log("SPAWN", "Player <{player_eid}> already spawned")
    if !replace_forced
      nexus_logerr("SPAWN", "Spawn is canceled due to player <{player_eid}> already spawned")
      return false
    elif destroy_previous_possessed
      nexus_log("SPAWN", "Try to delete player <{player_eid}> previous possessed")
      destroy_spawned_possessed_for_player(player_eid)
    else
      nexus_log("SPAWN", "Player <{player_eid}> previous possessed will be abandoned")

  sendEvent(player_eid, CmdSpawnEntityForPlayer())
  nexus_log("SPAWN", "Player <{player_eid}> spawned at {cur_time}")
  return true


def try_schedule_player_spawn_sequence(player_eid : EntityId;
                                       spawn_controller_eid : EntityId;
                                       cur_time : float;
                                       spawn_time : float;
                                       replace_forced : bool;
                                       destroy_previous_possessed : bool;
                                       var spawn_sequence_start_time : float;
                                       var nexus_spawn_controller__spawningPlayers : EidList&)
  // TODO: if bots work on all maps, better to enable AI for disconnected players
  var isDisconnected = false
  query(player_eid) <| $ [es(REQUIRE_NOT=playerIsBot)] (disconnected : bool)
    isDisconnected = disconnected
  if isDisconnected
    nexus_log("SPAWN", "Player: <{player_eid}> disconnected, refusing to spawn")
    return

  let spawningPlayersIndex = nexus_spawn_controller__spawningPlayers |> find_index(player_eid)
  if spawningPlayersIndex >= 0
    nexus_log("SPAWN", "Player <{player_eid}> is already trying to spawn")
    let spawnSequenceIsScheduled = find_query() <| $ [es] (eid : EntityId;
                                                           nexus_spawn_scheduled__player : EntityId)
      if nexus_spawn_scheduled__player == player_eid
        if replace_forced
          destroyEntity(eid)
          erase(nexus_spawn_controller__spawningPlayers, spawningPlayersIndex)
          nexus_log("SPAWN", "Player <{player_eid}> previous spawn is deleted from schedule")
        return true
      return false
    if spawnSequenceIsScheduled && !replace_forced
      nexus_logerr("SPAWN", "Player <{player_eid}> can't spawn because previous spawn is already scheduled")
      return
    if !spawnSequenceIsScheduled
      nexus_logerr("SPAWN", "Player <{player_eid}> can't spawn because player possessed is currently appearing")
      return

  if !give_loadout_to_nexus_player(player_eid)
    nexus_logerr("SPAWN", "Player <{player_eid}> can't spawn because his loadout is unavaliable")
    return

  let shouldScheduleSquenceStart = cur_time < spawn_sequence_start_time
  if !shouldScheduleSquenceStart
    send_net_event(player_eid, CmdNexusStartSpawnSequence(endAt = spawn_time))
    spawn_sequence_start_time = -1.0

  nexus_spawn_controller__spawningPlayers |> push(player_eid)
  createEntity("nexus_spawn_scheduled") <| $(var init)
    init |> set("nexus_spawn_scheduled__spawnController", spawn_controller_eid)
    init |> set("nexus_spawn_scheduled__player", player_eid)
    init |> set("nexus_spawn_scheduled__spawnAtTime", spawn_time)
    init |> set("nexus_spawn_scheduled__startSequenceAtTime", spawn_sequence_start_time)
    init |> set("nexus_spawn_scheduled__replaceForced", replace_forced)
    init |> set("nexus_spawn_scheduled__destroyPreviousPossessed", destroy_previous_possessed)

  if shouldScheduleSquenceStart
    nexus_log("SPAWN", "Player <{player_eid}> spawn is scheduled for {spawn_time} and spawn sequence will start at {spawn_sequence_start_time} (current_time={cur_time};)")
  else
    nexus_log("SPAWN", "Player <{player_eid}> spawn is scheduled for {spawn_time} and spawn sequence already started (current_time={cur_time};)")


[es(tag=server, on_appear)]
def nexus_spawn_controller_on_appear(evt : Event;
                                     var nexus_spawn_controller__playersController : EntityId&)
  find_query() <| $ [es(REQUIRE=nexus_players_controller)] (eid : EntityId)
    nexus_spawn_controller__playersController = eid
    return true


[es(tag=server, REQUIRE=nexus_players_controller, on_appear)]
def nexus_spawn_controller_on_player_controller_appear(evt : Event;
                                                       eid : EntityId)
  find_query() <| $ [es] (var nexus_spawn_controller__playersController : EntityId&)
    nexus_spawn_controller__playersController = eid
    return true


[es(tag=server, no_order)]
def nexus_spawn_schedule_update(act : ParallelUpdateFrameDelayed;
                                eid : EntityId;
                                nexus_spawn_scheduled__spawnController : EntityId;
                                nexus_spawn_scheduled__player : EntityId;
                                nexus_spawn_scheduled__replaceForced : bool;
                                nexus_spawn_scheduled__destroyPreviousPossessed : bool;
                                nexus_spawn_scheduled__spawnAtTime : float;
                                var nexus_spawn_scheduled__startSequenceAtTime : float&)
  if nexus_spawn_scheduled__startSequenceAtTime > 0.0
    if nexus_spawn_scheduled__startSequenceAtTime <= act.curTime
      nexus_log("SPAWN", "Player <{nexus_spawn_scheduled__player}> spawn sequence is started (current_time={act.curTime}; spawn_time={nexus_spawn_scheduled__spawnAtTime};)")
      send_net_event(nexus_spawn_scheduled__player, CmdNexusStartSpawnSequence(endAt = nexus_spawn_scheduled__spawnAtTime))
      nexus_spawn_scheduled__startSequenceAtTime = -1.0

  if act.curTime < nexus_spawn_scheduled__spawnAtTime
    return

  query(nexus_spawn_scheduled__spawnController) <| $ [es] (nexus_spawn_controller__spawnedPlayers : EidList)
    try_start_player_spawn_sequence(nexus_spawn_scheduled__player, nexus_spawn_controller__spawnedPlayers, act.curTime,
                                    nexus_spawn_scheduled__replaceForced, nexus_spawn_scheduled__destroyPreviousPossessed)
    destroyEntity(eid)


[es(tag=server)]
def nexus_spawn_player(evt : CmdNexusSpawnPlayer;
                       eid : EntityId;
                       nexus_spawn_controller__spawnSequenceDelay : float;
                       var nexus_spawn_controller__spawningPlayers : EidList&)
  let curTime = get_sync_time()
  let earliestSpawnTime = curTime + nexus_spawn_controller__spawnSequenceDelay
  let spawnTime = max(earliestSpawnTime, evt.atTime)
  let spawnSequenceStartTime = spawnTime - nexus_spawn_controller__spawnSequenceDelay
  try_schedule_player_spawn_sequence(evt.playerEid, eid, curTime, spawnTime, evt.replaceForced, evt.destroyPreviousPossessed,
                                     spawnSequenceStartTime, nexus_spawn_controller__spawningPlayers)


[es(tag=server)]
def nexus_spawn_all_players(evt : CmdNexusSpawnAllPlayers;
                            eid : EntityId;
                            nexus_spawn_controller__playersController : EntityId;
                            nexus_spawn_controller__spawnSequenceDelay : float;
                            nexus_spawn_controller__spawnedPlayers : EidList;
                            var nexus_spawn_controller__spawningPlayers : EidList&)
  let curTime = get_sync_time()
  let earliestSpawnTime = curTime + nexus_spawn_controller__spawnSequenceDelay
  let spawnTime = max(earliestSpawnTime, evt.atTime)
  let spawnSequenceStartTime = spawnTime - nexus_spawn_controller__spawnSequenceDelay
  query(nexus_spawn_controller__playersController) <| $ [es] (nexus_players_controller__players : EidList)
    for playerEid in nexus_players_controller__players
      if evt.ignoreAlreadySpawned && (find_index(nexus_spawn_controller__spawnedPlayers, playerEid) != -1 || find_index(nexus_spawn_controller__spawningPlayers, playerEid) != -1)
        continue
      try_schedule_player_spawn_sequence(playerEid, eid, curTime, spawnTime, evt.replaceForced, evt.destroyPreviousPossessed,
                                         spawnSequenceStartTime, nexus_spawn_controller__spawningPlayers)


[es(tag=server)]
def nexus_spawn_despawn_all_players(evt : CmdNexusDespawnAllPlayers;
                                    nexus_spawn_controller__spawnedPlayers : EidList)
  nexus_log("SPAWN", "Despawn all spawned players")
  for player in nexus_spawn_controller__spawnedPlayers
    query(player) <| $ [es] (var possessed : EntityId&)
      destroyEntity(possessed)
      possessed = INVALID_ENTITY_ID


[es(tag=server)]
def nexus_spawn_cancel_scheduled_player_spawn(evt : EventNexusCancelScheduledSpawnAllPlayers;
                                              eid : EntityId;
                                              nexus_spawn_scheduled__player : EntityId;
                                              nexus_spawn_scheduled__spawnController : EntityId)
  nexus_log("SPAWN", "Player <{nexus_spawn_scheduled__player}> scheduled spawn is canceled")
  destroyEntity(eid)
  query(nexus_spawn_scheduled__spawnController) <| $ [es] (var nexus_spawn_controller__spawningPlayers : EidList&)
    let index = find_index(nexus_spawn_controller__spawningPlayers, nexus_spawn_scheduled__player)
    if index >= 0
      nexus_spawn_controller__spawningPlayers |> erase(index)
    else
      nexus_logwarn("SPAWN", "Player <{nexus_spawn_scheduled__player}> canceled spawn but he already wasn't in spawningPlayers list")


[es(tag=server, on_appear)]
def nexus_spawn_player_on_appear(evt : Event;
                                 var nexus_player__spawned : bool&)
  nexus_player__spawned = false

[es(tag=server, track=possessed)]
def nexus_spawn_player_track_spawned(evt : Event;
                                     eid : EntityId;
                                     possessed : EntityId;
                                     var nexus_player__spawned : bool&)
  nexus_player__spawned = possessed != INVALID_ENTITY_ID
  find_query() <| $ [es] (var nexus_spawn_controller__spawnedPlayers : EidList&;
                          var nexus_spawn_controller__spawningPlayers : EidList&)
    if nexus_player__spawned
      if !has_value(nexus_spawn_controller__spawnedPlayers, eid)
        nexus_spawn_controller__spawnedPlayers |> push(eid)
      else
        nexus_logwarn("SPAWN", "Player <{eid}> spawned militant but he already was in spawnedPlayers list")
      let index = find_index(nexus_spawn_controller__spawningPlayers, eid)
      if index >= 0
        nexus_spawn_controller__spawningPlayers |> erase(index)
      else
        nexus_logwarn("SPAWN", "Player <{eid}> spawned militant but he already wasn't in spawningPlayers list")
    else
      let index = find_index(nexus_spawn_controller__spawnedPlayers, eid)
      if index >= 0
        nexus_spawn_controller__spawnedPlayers |> erase(index)
      else
        nexus_logwarn("SPAWN", "Player <{eid}> dispawned militant but he already wasn't in spawnedPlayers list")
    return true


[es(tag=server, on_disappear)]
def nexus_spawn_player_on_disappear(evt : Event;
                                    eid : EntityId;
                                    nexus_player__spawned : bool)
  if nexus_player__spawned
    find_query() <| $ [es] (var nexus_spawn_controller__spawnedPlayers : EidList&)
      let index = find_index(nexus_spawn_controller__spawnedPlayers, eid)
      if index >= 0
        nexus_spawn_controller__spawnedPlayers |> erase(index)
      else
        nexus_logwarn("SPAWN", "Player <{eid}> dissapeared while spawned but he already wasn't in spawnedPlayers list")
      return true


[es(tag=server, track=nexus_player__spawned)]
def nexus_spawn_player_on_respawn(evt : Event;
                                  eid aka player_eid : EntityId;
                                  possessed : EntityId;
                                  team aka player_team : int;
                                  nexus_player__spawned : bool)
  if !nexus_player__spawned
    return

  // if we respawned not by joining spawn queue, we should leave it
  // and free currently chosen loadout
  find_query() <| $ [es] (var nexus_battle_spawn_controller__playersToSpawn : EidList)
    let index = find_index(nexus_battle_spawn_controller__playersToSpawn, player_eid)
    if index >= 0
      erase(nexus_battle_spawn_controller__playersToSpawn, index)
      var hasTeammateInQueue = false
      for player in nexus_battle_spawn_controller__playersToSpawn
        query(player) <| $ [es] (team : int)
          hasTeammateInQueue = (team == player_team)
        if hasTeammateInQueue
          break
      if !hasTeammateInQueue // no more teammates to spawn -> stop current wave
        find_query() <| $ [es] (var nexus_battle_additional_waves_spawn_controller__spawnAt : float&; team aka additional_spawner_team : int)
          if additional_spawner_team == player_team
            nexus_battle_additional_waves_spawn_controller__spawnAt = -1.0
            return true
          return false
    return true

  find_query() <| $ [es] (nexus_battle_initial_am__value : int;
                          var nexus_battle_initial_am__playersGiven : EidList)
    if has_value(nexus_battle_initial_am__playersGiven, player_eid)
      return true
    query(possessed) <| $ [es] (var am_storage__value : int&)
      push(nexus_battle_initial_am__playersGiven, player_eid)
      am_storage__value += nexus_battle_initial_am__value
    return true

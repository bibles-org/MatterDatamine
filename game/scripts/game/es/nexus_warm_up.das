require app
require ecs
require DngNet
require game.events.events_game
require game.events.events_active_matter
require game.es.level_common
require game.es.nexus_common
require game.es.damage_systems.damage_model_common
require game.es.damage_systems.damage_model_armor_common


def add_player(player_eid : EntityId;
               destroy_possesed_at_end : bool)
  nexus_log("WARM UP", "Player <{player_eid}> is added")
  var playerWarmUpTemplate = "nexus_warm_up"
  if destroy_possesed_at_end
    playerWarmUpTemplate = add_sub_template_name(playerWarmUpTemplate, "nexus_warm_up_player_destroy_possessed_at_end")
  remote_add_sub_template(player_eid, playerWarmUpTemplate)


def spawn_player(player_eid : EntityId;
                 spawn_controller_eid : EntityId;
                 at_time : float = 0.0;
                 leave_the_corpse : bool = false)
  nexus_log("WARM UP", "Player <{player_eid}> is processed for spawn")
  sendEvent(spawn_controller_eid, CmdNexusSpawnPlayer(destroyPreviousPossessed = !leave_the_corpse, replaceForced = true, playerEid = player_eid, atTime = at_time))


[es(tag=server, on_appear)]
def nexus_warm_up_on_appear(evt : Event;
                            var nexus_warm_up__spawnController : EntityId&)
  find_query() <| $ [es(REQUIRE=nexus_spawn_controller)] (eid : EntityId)
    nexus_warm_up__spawnController = eid
    return true


[es(tag=server, REQUIRE=nexus_spawn_controller, on_appear)]
def nexus_warm_up_on_spawn_controller_appear(evt : Event;
                                             eid : EntityId)
  find_query() <| $ [es] (var nexus_warm_up__spawnController : EntityId&)
    nexus_warm_up__spawnController = eid
    return true


[es(tag=gameClient, REQUIRE=(nexus_militant, nexus_warm_up, watchedByPlr, deadEntity), on_appear)]
def nexus_warm_up_militant_remove_observe(evt : Event;
                                          eid : EntityId)
  removeSubTemplate(eid, "observed_local")


[es(tag=server, REQUIRE=(nexus_militant, nexus_warm_up))]
def nexus_warm_up_militant_respawn(evt : EventEntityDied;
                                   possessedByPlr : EntityId)
  find_query() <| $ [es] (nexus_warm_up__spawnController : EntityId;
                          nexus_warm_up__spawnDealy : float;
                          nexus_warm_up__active : bool)
    if !nexus_warm_up__active
      return true
    spawn_player(possessedByPlr, nexus_warm_up__spawnController, nexus_warm_up__spawnDealy, true)
    return true


[es(tag=server, REQUIRE=(nexus_player, nexus_warm_up), on_appear)]
def nexus_warm_up_player_on_appear(evt : Event;
                                   eid aka player_eid : EntityId)
  find_query() <| $ [es(REQUIRE=nexus_warm_up_controller)] (nexus_warm_up_lock_shooting : Tag const?)
    if nexus_warm_up_lock_shooting != null
      sendEvent(player_eid, CmdNexusLockShootingForPlayer())
    return true


[es(tag=server, REQUIRE=(nexus_player, nexus_warm_up), track=possessed, on_appear)]
def nexus_warm_up_player_on_possessed_appear(evt : Event;
                                             possessed : EntityId)
  if possessed == INVALID_ENTITY_ID
    return
  remote_add_sub_template(possessed, "nexus_warm_up")

  find_query() <| $ [es(REQUIRE=nexus_warm_up_controller)] (nexus_warm_up_god_mode : Tag const?;
                                                            nexus_warm_up_disable_friendly_damage : Tag const?)
    if nexus_warm_up_god_mode != null
      human_damage_model_set_hp_in_percent(possessed, 99999f)
      human_damage_model_set_armor_hp_in_percent(possessed, 99999f)

    if nexus_warm_up_disable_friendly_damage != null
      remote_remove_sub_template(possessed, "allow_friendly_damage")

    return true


[es(tag=server, on_event=(EventNexusWaitingForEnoughPlayers, EventNexusWarmUp))]
def nexus_warm_up_start(evt : Event;
                        nexus_warm_up__spawnController : EntityId;
                        nexus_warm_up__spawnDealy : float;
                        var nexus_warm_up__active : bool&;
                        nexus_warm_up_remove_militants_at_end : Tag const?;
                        nexus_warm_up_spawn_without_choosing_loadout : Tag const?)
  if nexus_warm_up__active
    return
  nexus_log("WARM UP", "Starting")
  nexus_warm_up__active = true
  broadcastEvent(EventNexusWarmUpStarted())
  let atTime = get_sync_time() + nexus_warm_up__spawnDealy
  find_query() <| $ [es] (nexus_players_controller__players : EidList)
    for playerEid in nexus_players_controller__players
      add_player(playerEid, nexus_warm_up_remove_militants_at_end != null)
      find_query() <| $ [es] (nexus_loadouts__owner : EntityId)
        if nexus_loadouts__owner != playerEid
          return false
        if nexus_warm_up_spawn_without_choosing_loadout == null
          nexus_log("WARM UP", "Can't spawn player <{playerEid}> without choosing loadout")
        else
          spawn_player(playerEid, nexus_warm_up__spawnController, atTime)
        return true
    return true


[es(tag=server)]
def nexus_warm_up_end(evt : EventNexusGameStart;
                      var nexus_warm_up__active : bool&;
                      nexus_warm_up_remove_militants_at_end : Tag const?)
  nexus_log("WARM UP", "Finishing")
  if nexus_warm_up__active
    nexus_warm_up__active = false

  if nexus_warm_up_remove_militants_at_end != null
    broadcastEvent(EventNexusCancelScheduledSpawnAllPlayers())
  broadcastEvent(EventNexusWarmUpFinished())


[es(tag=server, REQUIRE=nexus_player)]
def nexus_warm_up_try_spawn_player(evt : RequestNexusSpawnPlayer;
                                   eid aka player_eid : EntityId)
  find_query() <| $ [es] (nexus_warm_up__spawnController : EntityId;
                          nexus_warm_up__active : bool)
    if !nexus_warm_up__active
      return true
    spawn_player(player_eid, nexus_warm_up__spawnController)
    return true


[es(tag=server)]
def nexus_warm_up_enable_loadout_change(evt : EventNexusWarmUpStarted;
                                        var nexus_loadout_controller__canChange : bool&)
  nexus_loadout_controller__canChange = true


[es(tag=server, REQUIRE=nexus_beacon_capture_device, REQUIRE_NOT=nexus_disable)]
def nexus_warm_up_disable_beacons(evt : EventNexusWarmUpStarted;
                                  eid : EntityId)
  remote_add_sub_template(eid, "nexus_warm_up+nexus_beacon_capture_device_inactive")


[es(tag=server, REQUIRE=(nexus_warm_up, nexus_beacon_capture_device_inactive))]
def nexus_warm_up_enable_beacons(evt : EventNexusWarmUpFinished;
                                 eid : EntityId;
                                 nexus_disable : Tag const?)
  if nexus_disable != null
    remote_remove_sub_template(eid, "nexus_warm_up")
  else
    remote_remove_sub_template(eid, "nexus_warm_up+nexus_beacon_capture_device_inactive")



[es(tag=server, REQUIRE=nexus_warm_up_protect_sphere)]
def nexus_warm_up_remove_protection_spheres(evt : EventNexusWarmUpFinished;
                                            eid : EntityId)
  destroyEntity(eid)


[es(tag=server, REQUIRE=(nexus_player, nexus_warm_up))]
def nexus_warm_up_remove_players(evt : EventNexusWarmUpFinished;
                                 eid aka player_eid : EntityId;
                                 var possessed : EntityId&;
                                 nexus_warm_up_player_destroy_possessed_at_end : Tag const?)
  nexus_log("WARM UP", "Player <{player_eid}> warm up tag is removed")
  remote_remove_sub_template(player_eid, "nexus_warm_up")
  if nexus_warm_up_player_destroy_possessed_at_end != null
    nexus_log("WARM UP", "Player <{player_eid}> possessed is removed")
    destroyEntity(possessed)
    possessed = INVALID_ENTITY_ID
  else
    find_query() <| $ [es(REQUIRE=nexus_warm_up_lock_shooting)] ()
      sendEvent(player_eid, CmdNexusUnlockShootingForPlayer())
      return true


[es(tag=server, REQUIRE=(nexus_militant, nexus_warm_up))]
def nexus_warm_up_remove_tags_from_millitants(evt : EventNexusWarmUpFinished;
                                              eid : EntityId)
  nexus_log("WARM UP", "Player <{eid}> warm up tag is removed")
  remote_remove_sub_template(eid, "nexus_warm_up")


[es(tag=server, REQUIRE=nexus_player, on_appear)]
def nexus_warm_up_add_players(evt : Event;
                              eid aka player_eid : EntityId)
  find_query() <| $ [es] (nexus_warm_up__active : bool;
                          nexus_warm_up_remove_militants_at_end : Tag const?)
    if !nexus_warm_up__active
      nexus_log("WARM UP", "Can't process player <{player_eid}> because warm up is finished or not started")
      return true
    add_player(player_eid, nexus_warm_up_remove_militants_at_end != null)
    return true


[es(tag=server, on_appear)]
def nexus_warm_up_spawn(evt : Event;
                        nexus_loadouts__owner : EntityId)
  if !has(nexus_loadouts__owner, "nexus_warm_up")
    nexus_log("WARM UP", "Can't spawn player <{nexus_loadouts__owner}> without warm up tag")
    return
  find_query() <| $ [es] (nexus_warm_up__active : bool;
                          nexus_warm_up__spawnController : EntityId;
                          nexus_warm_up__spawnDealy : float;
                          nexus_warm_up_spawn_without_choosing_loadout : Tag const?)
    if !nexus_warm_up__active
      nexus_log("WARM UP", "Can't spawn player <{nexus_loadouts__owner}> because warm up is finished or not started")
      return true
    if nexus_warm_up_spawn_without_choosing_loadout == null
      nexus_log("WARM UP", "Can't spawn player <{nexus_loadouts__owner}> without choosing loadout")
      return true

    let atTime = get_sync_time() + nexus_warm_up__spawnDealy
    spawn_player(nexus_loadouts__owner, nexus_warm_up__spawnController, atTime)
    return true

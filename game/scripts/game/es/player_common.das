module player_common shared public

require app
require DagorDataBlock
require DagorSystem
require ecs
require game.events.events
require game.events.player_events
require game.es.stat_bq_common
require game.es.ecs_common
require game.events.events_game
require game.utils.net_utils
require GameTimers
require level
require DngNet
require game.utils.team


def find_next_spec_target(team_id : int; cur_eid : EntityId; dir : int) : EntityId
  var entitiesToWatch : array<EntityId>
  query() <| $ [es(REQUIRE_NOT=deadEntity)] (eid : EntityId;
                                             isSpectatable, countAsAlive, isAlive : bool;
                                             allowEnemiesToSpectate : bool = false;
                                             team = TEAM_UNASSIGNED)
    assume isValidTeam = allowEnemiesToSpectate || (team == team_id || team_id == TEAM_UNASSIGNED)
    if isSpectatable && countAsAlive && isAlive && isValidTeam
      entitiesToWatch |> push(eid)
  let entitiesToWatchLen = length(entitiesToWatch)
  if entitiesToWatchLen < 2 || cur_eid == INVALID_ENTITY_ID
    return empty(entitiesToWatch) ? INVALID_ENTITY_ID : entitiesToWatch[0]
  entitiesToWatch |> sort() <| $(lhs, rhs)
    return uint(lhs) < uint(rhs) // i.e. don't assume that ES executes in stable order
  let curEidIdx = entitiesToWatch |> find_index(cur_eid)
  if curEidIdx == -1
    return entitiesToWatch[0]
  let newSpecTargetIdx = curEidIdx + ((dir >= 0) ? 1 : -1)
  return newSpecTargetIdx < 0 ? entitiesToWatch[entitiesToWatchLen - 1] : entitiesToWatch[newSpecTargetIdx % entitiesToWatchLen]

def send_enable_spectator_for_player(player_eid : EntityId)
  print("Send enable spectator for plr {int(uint(player_eid))}")
  send_net_event(player_eid, EnableSpectatorForPlayer(target = INVALID_ENTITY_ID), target_entity_conn(player_eid))

def send_enable_spectator_for_target(player_eid : EntityId; spec_target : EntityId) : void
  print("Send enable spectator for plr {int(uint(player_eid))} target {spec_target}")
  send_net_event(spec_target, EnableSpectatorForTarget(player = player_eid), target_entity_conn(player_eid))

def emit_hero_changed_event(new_hero : EntityId)
  print("emit_hero_changed_event {int(uint(new_hero))}")
  broadcastEvent(EventHeroChanged(eid = new_hero))

def player_respawn_try_reposses_or_spectate(eid : EntityId)
  var result = false
  query(eid) <| $ [es] (team : int;
                        userid : uint64;
                        connid : int;
                        var specTarget : EntityId&;
                        var possessed : EntityId&;
                        var clientNetFlags : int&)
    if possessed != INVALID_ENTITY_ID && !doesEntityExist(possessed)
      possessed = INVALID_ENTITY_ID
    print("player_respawn_default_implementation plr={eid}, conn=#{connid}, userid={userid} possessed={possessed}, specTarget={specTarget}")
    query(possessed) <| $ [es] (isAlive aka possessed_isAlive : bool)
      if possessed_isAlive
        print("The original possessed is alive. reposses it.")
        sendEvent(eid, PossessTargetByPlayer(target = possessed))
        result = true
        return
      else
        var hasValidSPecTarget = false
        query(specTarget) <| $ [es] (isAlive aka spec_isAlive : bool)
          if spec_isAlive
            hasValidSPecTarget = spec_isAlive
            print("The original specTarget is alive.")
        if !hasValidSPecTarget
          specTarget = find_next_spec_target(team, specTarget, +1)
          print("The original specTarget is not alive or doesn\t exist. Alternative target: {specTarget}")
        if specTarget != INVALID_ENTITY_ID
          clientNetFlags |= int(ClientNetFlags.CNF_REPLICATE_PHYS_ACTORS) // This enables grid_scope_adder
          sendEventImmediate(eid, CmdAddDefaultEntitiesInNetScopeForPlayer())
          // Sending to the target, so the event will wait for the target to be replicated
          send_enable_spectator_for_target(eid, specTarget)
          result = true
  return result


def player_respawn_in_world_common(eid : EntityId)
  print("player_respawn_in_world_common")
  if player_respawn_try_reposses_or_spectate(eid)
    return

  query(eid) <| $ [es] (connid : int; clientNetFlags : int)
    if (0 == (clientNetFlags & int(ClientNetFlags.CNF_SPAWNED_AT_LEAST_ONCE)))
      sendEvent(eid, CmdSpawnEntityForPlayer())
    else // shouldn't be happening (un-authorized spawn request?)
      var conn : IConnection? = get_client_connection(connid)
      logwarn("Diconnect player {int(uint(eid))} conn #{connection_getId(*conn)} as it's can't be spawn or spectate anything")
      if conn != null
        net_disconnect(*conn, DisconnectionCause.DC_CONNECTION_CLOSED)

def game_params_get_timer(timerName : string; fallback : float) : float
  return dgs_get_game_params() |> datablock_get_block_by_name("timers") |> datablock_getReal(timerName, fallback)

def settings_get_timer(timerName : string; fallback : float) : float
  return dgs_get_settings() |> datablock_get_block_by_name("timers") |> datablock_getReal(timerName, fallback)


def get_team_players_info(team_id : int)
  var info : string

  find_query() <| $ [es] (eid aka team_eid : EntityId;
                          team__id : int)
    if team__id != team_id
      return false

    var playersInfo : string
    var playersCount = 0
    query() <| $ [es(REQUIRE=player)] (eid aka player_eid : EntityId;
                                       team aka player_team : int)
      if team_id != player_team
        return

      playersInfo = "{playersInfo}  {get_player_info(player_eid)}\n"
      ++playersCount

    info = "{info}TEAM {get_entity_info(team_eid)} (team__id={team__id}):\n"
    if playersCount > 0
      info = "{info}  PLAYERS ({playersCount}):\n{playersInfo}"
    else
      info = "{info}  [NO PLAYERS]\n"

    return true

  return <- info
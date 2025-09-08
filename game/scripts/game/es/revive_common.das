module revive_common shared
require app
require ecs
require ecs.safe
require ecs.common
require game.events.events_game
require DagorMath


def create_test_player(team : int = 666666)
  var maxTestPlayerIndex = -1
  query() <| $ [es] (active_matter_player_test__index : int)
    maxTestPlayerIndex = max(maxTestPlayerIndex, active_matter_player_test__index)

  let playerIndex = maxTestPlayerIndex + 1
  let playerEid = createEntitySync("active_matter_player_test") <| $ [es] (var init : ComponentsInitializer)
    init |> set("active_matter_player_test__index", playerIndex)
    init |> set("name", "TestPlayer#{playerIndex}")
    init |> set("team", team)

  broadcastEvent(EventTeamMemberJoined(eid = playerEid, team = team))
  return playerEid


def get_current_revive_price(player_eid : EntityId)
  var result = 100
  query(player_eid) <| $ [es] (player__stats : Object; @shared_comp spawn_rules__respawnPrices : IntList)
    let deaths = player__stats["deaths"] ?? 0
    let beaconRevives = player__stats["resurrected_via_beacon"] ?? 0
    let idx = clamp(deaths - 1 - beaconRevives, 0, length(spawn_rules__respawnPrices) - 1)
    result = spawn_rules__respawnPrices[idx]
  return result


def deactivate_player_cortical(player : EntityId)
  find_query() <| $ [es(REQUIRE=cortical_vault)] (playerItemOwner : EntityId;
                                                  var cortical_vault__reviveAllowed : bool&)
    if playerItemOwner == player
      cortical_vault__reviveAllowed = false
      return true
    return false

require ecs
require net
require player
require game.events.events_game


[es(tag=server, track=item__humanOwnerEid, REQUIRE=dogtag_item)]
def track_confirmed_kill(evt : Event;
                         item__humanOwnerEid : EntityId;
                         cortical_vault_inactive__killerPlayerEid : EntityId)
  if cortical_vault_inactive__killerPlayerEid == INVALID_ENTITY_ID
    return

  var ownerTeam = TEAM_UNASSIGNED
  query(item__humanOwnerEid) <| $[es] (possessedByPlr : EntityId)
    query(possessedByPlr) <| $[es] (team : int)
      ownerTeam = team

  var teammates : array<EntityId>
  query(cortical_vault_inactive__killerPlayerEid) <| $[es] (team aka killer_team : int)
    if ownerTeam == killer_team
      query() <| $[es] (eid aka teammate_eid : EntityId;
                        team aka killer_teammmate_team : int)
        if ownerTeam == killer_teammmate_team
          teammates |> push(teammate_eid)
  if empty(teammates)
    return

  find_query() <| $ [es] (team__confirmedDailyContract : Object;
                          team__id : int;
                          var team__firstKillConfirmed : bool&)
    if ownerTeam == team__id
      if !team__firstKillConfirmed
        team__firstKillConfirmed = true
        let reward = team__confirmedDailyContract["kills_operative"] |> get_int() ?? -1
        if reward > 0
          for teammate in teammates
            send_net_event(teammate, EventRewardDailyContract(statName = "kills_operative", reward = reward))
      return true
    return false

require ecs
require ecs.safe
require game.utils.team
require game.events.events_game
require net
require strings


def private add_stat(var stat_obj : Object; stat_name : string; stat_value = 1)
  stat_obj |> set(stat_name, stat_value + stat_obj[stat_name] ?? 0)


def private reward_need_confirmed(stat : string)
  return stat == "kills_operative"

def private reward_need_ignore(stat : string)
  return stat == "kills" || stat == "kills_monster" || stat == "kills_operative_bot"

[es(tag=server)]
def userstat_kill_player_process(evt : EventEntityDied;
                                 possessedByPlr : EntityId const?;
                                 am_militant_bot : Tag const?;
                                 kill_tracking_tag : das_string const?)
  if evt.offender == evt.victim // suicide
    return

  let isVictimMonster = possessedByPlr == null || *possessedByPlr == INVALID_ENTITY_ID
  let isVictimBot = am_militant_bot != null

  query(evt.offender) <| $ [es] (possessedByPlr : EntityId; player_controlled_monster : Tag const?)
    let prefix = player_controlled_monster == null ? "" : "monster_"
    query(possessedByPlr) <| $ [es] (var player__stats : Object;
                                     team : int;
                                     player__dailyStatsReward : Object;
                                     player__dailyStatsRewardInfo : Object)
      var statsStrings : array<string>
      statsStrings |> push("{prefix}kills")
      if isVictimMonster
        statsStrings |> push("{prefix}kills_monster")
        if kill_tracking_tag != null
          let tag = string(*kill_tracking_tag)
          if tag == "flower_human"
            statsStrings |> push("{prefix}kills_monster_flowerman")
          elif tag == "flower_miniboss"
            statsStrings |> push("{prefix}kills_monster_flowerman")
            statsStrings |> push("{prefix}kills_monster_flowerman_boss")
          elif tag == "invisible_man"
            statsStrings |> push("{prefix}kills_monster_invisible")
          elif tag == "changed_human"
            statsStrings |> push("{prefix}kills_monster_changed")
          elif tag == "changed_miniboss"
            statsStrings |> push("{prefix}kills_monster_changed")
            statsStrings |> push("{prefix}kills_monster_changed_boss")
          elif tag == "swarm_snake_nest"
            statsStrings |> push("{prefix}kills_monster_worms")
          elif tag == "turned_soldier"
            statsStrings |> push("{prefix}kills_monster_corrupted_soldiers")
      elif !isVictimMonster
        statsStrings |> push("{prefix}kills_operative")
        if isVictimBot
          statsStrings |> push("{prefix}kills_operative_bot")

      for stat_name in statsStrings
        player__stats |> add_stat(stat_name)

        if reward_need_ignore(stat_name) || (player__stats[stat_name] ?? 0) > 1
          continue
        let oldValue = player__dailyStatsReward[stat_name] |> get_int() ?? 0
        let curValue = oldValue + player__stats[stat_name] ?? 0

        var rewardVal = -1
        for rewardInfo in player__dailyStatsRewardInfo
          let rewardKey = to_int(rewardInfo.key, false)
          if rewardKey >= curValue
            rewardVal = rewardInfo.value ?? -1
            break
        if rewardVal == -1
          continue

        if reward_need_confirmed(stat_name)
          query() $[es] (team__id : int;
                         var team__confirmedDailyContract : Object&)
            if team__id == team
              team__confirmedDailyContract |> set(stat_name, rewardVal)
        else
          send_net_event(possessedByPlr, EventRewardDailyContract(statName = stat_name, reward = rewardVal))


[es(tag=server, on_event=EventEntityDied, before=raid_player_killed)]
def userstat_death_player_process(evt : Event; possessedByPlr : EntityId; player_controlled_monster : Tag const?)
  let prefix = player_controlled_monster == null ? "" : "monster_"
  query(possessedByPlr) <| $ [es] (team : int; var player__stats : Object&)
    if team != TEAM_UNASSIGNED
      player__stats |> add_stat("{prefix}deaths")

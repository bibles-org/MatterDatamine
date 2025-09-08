options no_aot
require app
require game.events.events_active_matter
require game.es.net_console_macro


def team_win(team_id : int;
             reason : int)
  broadcast_net_event(EventNexusRoundModeRoundFinished(winnerTeam = team_id, reason = reason, time = get_sync_time()))


[net_console_cmd(name="nexus.round_win_hero")]
def nexus_round_mode_hero_win_cmd(@net_hero eid : EntityId;
                                  reason : int = 0)
  team_win(get_int(eid, "team") ?? TEAM_UNASSIGNED, reason)


[net_console_cmd(name="nexus.round_win_team")]
def nexus_round_mode_team_win_cmd(team_id : int;
                                  reason : int = 0)
  team_win(team_id, reason)

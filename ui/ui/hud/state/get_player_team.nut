import "%dngscripts/ecs.nut" as ecs
let { TEAM_UNASSIGNED } = require("team")

let get_player_team_Query = ecs.SqQuery("get_player_team_Query",  {comps_ro = [["team", ecs.TYPE_INT]]})
function get_player_team(player_eid) {
  return get_player_team_Query.perform(player_eid, @(_eid, comp) comp.team) ?? TEAM_UNASSIGNED
}

return get_player_team
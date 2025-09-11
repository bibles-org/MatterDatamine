from "team" import TEAM_UNASSIGNED

function is_teams_friendly(team1_id, team2_id){
  return team1_id == team2_id && team1_id !=TEAM_UNASSIGNED
}
return is_teams_friendly
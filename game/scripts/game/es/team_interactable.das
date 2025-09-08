require ecs
require game.events.events


[es(tag=server, before=(start_interaction_on_interactable_used, door_operations), REQUIRE=only_team_interactable)]
def check_only_team_on_interactable_used(cmd : CmdUse; team aka object_team : int; var interactable__blockThisInteraction : bool&)
  interactable__blockThisInteraction = true
  query(cmd.requesterEid) <| $ [es] (team aka player_team : int)
    interactable__blockThisInteraction = player_team != object_team

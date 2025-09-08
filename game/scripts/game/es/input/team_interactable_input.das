require ecs


[es(tag=input, REQUIRE=hero, REQUIRE_NOT=deadEntity,
  after=hero_human_use_object,
  before=hero_human_final_use_object_sync)]
def hero_human_use_check_only_team(act : UpdateStageInfoAct;
                                   team aka player_team : int;
                                   var human_use_object__blockReason : das_string&;
                                   var human_use_object__canUseSelected : bool&;
                                   human_use_object__selectedObject : EntityId)
  query(human_use_object__selectedObject) <| $ [es(REQUIRE=only_team_interactable)] (team aka object_team : int)
    human_use_object__canUseSelected = player_team == object_team
    if !human_use_object__canUseSelected
      human_use_object__blockReason := "Unaccessible"

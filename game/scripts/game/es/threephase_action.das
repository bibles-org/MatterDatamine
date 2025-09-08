require ecs
require PhysVars


[es(on_appear)]
def human_anim_threephase_action_appear(evt : Event;
                                        var phys_vars : PhysVars;
                                        var human_anim__threephaseActionProgressVarId : int&)
  human_anim__threephaseActionProgressVarId = phys_vars |> registerVar("threephase_action_progress", 0.0)
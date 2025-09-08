require ecs
require ecs.common

[es(tag=gameClient, on_appear)]
def friend_or_foe_tex_replace(evt : Event; friend_or_foe__texReplaceForFoe : Object; var animchar__objTexReplace : Object&; team : int)
  let charTeam = team
  query() <| $ [es] (team : int; is_local : bool)
    if !is_local || team == charTeam
      return
    for replace in friend_or_foe__texReplaceForFoe
      set(animchar__objTexReplace, replace.key, get_string(replace.value, ""))

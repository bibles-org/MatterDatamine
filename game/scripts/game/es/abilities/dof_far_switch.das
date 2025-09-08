require ecs
require game.utils.hero


[es(on_appear, REQUIRE=watchedByPlr)]
def dof_far_watched_by_plr_appear(evt : Event;
                                  eid : EntityId)
  find_query() <| $ [es] (var game_effect_dof__farDofAmountPercent : float&;
                          var game_effect_dof__farDofStart : float&;
                          var game_effect_dof__farDofEnd : float&;
                          var game_effect_dof__nearDofEnd : float&;
                          var game_effect_dof__on : bool&;
                          game_effect__attachedTo : EntityId)
    if game_effect__attachedTo == eid
      ecs::query() <| $ [es] (var dof__farDofAmountPercent : float&;
                              var dof__farDofStart : float&;
                              var dof__farDofEnd : float&;
                              var dof__nearDofEnd : float&;
                              var dof__on : bool&)
        if !dof__on
          swap(dof__farDofAmountPercent, game_effect_dof__farDofAmountPercent)
          swap(dof__farDofStart, game_effect_dof__farDofStart)
          swap(dof__farDofEnd, game_effect_dof__farDofEnd)
          swap(dof__nearDofEnd, game_effect_dof__nearDofEnd)
          swap(dof__on, game_effect_dof__on)
      return true
    return false


[es(on_appear, on_disappear)]
def dof_far_set_es(evt : Event;
                   var game_effect_dof__farDofAmountPercent : float&;
                   var game_effect_dof__farDofStart : float&;
                   var game_effect_dof__farDofEnd : float&;
                   var game_effect_dof__nearDofEnd : float&;
                   var game_effect_dof__on : bool&;
                   game_effect__attachedTo : EntityId)

  //swap used here how workaround to save previous dof parameters. may be need to change dof interface
  if has(game_effect__attachedTo, "watchedByPlr")
    ecs::query() <| $ [es] (var dof__farDofAmountPercent : float&;
                            var dof__farDofStart : float&;
                            var dof__farDofEnd : float&;
                            var dof__nearDofEnd : float&;
                            var dof__on : bool&)
      swap(dof__farDofAmountPercent, game_effect_dof__farDofAmountPercent)
      swap(dof__farDofStart, game_effect_dof__farDofStart)
      swap(dof__farDofEnd, game_effect_dof__farDofEnd)
      swap(dof__nearDofEnd, game_effect_dof__nearDofEnd)
      swap(dof__on, game_effect_dof__on)


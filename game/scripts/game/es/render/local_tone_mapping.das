require ecs


def apply_local_tone_mapping_affect(local_tone_mapping_affect__hq_shadows_multiplier : float;
                                    local_tone_mapping_affect__hq_highlights_multiplier : float;
                                    var local_tone_mapping_affect__prev_hq_shadows_multiplier : float&;
                                    var local_tone_mapping_affect__prev_hq_highlights_multiplier : float&)
  query() <| $ [es] (var local_tone_mapping__hq_shadows_multiplier : float&;
                     var local_tone_mapping__hq_highlights_multiplier : float&)
    local_tone_mapping_affect__prev_hq_shadows_multiplier = local_tone_mapping__hq_shadows_multiplier
    local_tone_mapping_affect__prev_hq_highlights_multiplier = local_tone_mapping__hq_highlights_multiplier
    local_tone_mapping__hq_shadows_multiplier = local_tone_mapping_affect__hq_shadows_multiplier
    local_tone_mapping__hq_highlights_multiplier = local_tone_mapping_affect__hq_highlights_multiplier


def revert_local_tone_mapping_affect(local_tone_mapping_affect__prev_hq_shadows_multiplier : float;
                                     local_tone_mapping_affect__prev_hq_highlights_multiplier : float)
  query() <| $ [es] (var local_tone_mapping__hq_shadows_multiplier : float&;
                     var local_tone_mapping__hq_highlights_multiplier : float&)
    local_tone_mapping__hq_shadows_multiplier = local_tone_mapping_affect__prev_hq_shadows_multiplier
    local_tone_mapping__hq_highlights_multiplier = local_tone_mapping_affect__prev_hq_highlights_multiplier


[es(tag=render, on_appear)]
def local_tone_mapping_affect_appear(evt : Event;
                                     game_effect__attachedTo : EntityId;
                                     local_tone_mapping_affect__hq_shadows_multiplier : float;
                                     local_tone_mapping_affect__hq_highlights_multiplier : float;
                                     var local_tone_mapping_affect__prev_hq_shadows_multiplier : float&;
                                     var local_tone_mapping_affect__prev_hq_highlights_multiplier : float&)
  if has(game_effect__attachedTo, "watchedByPlr")
    apply_local_tone_mapping_affect(local_tone_mapping_affect__hq_shadows_multiplier,
                                    local_tone_mapping_affect__hq_highlights_multiplier,
                                    local_tone_mapping_affect__prev_hq_shadows_multiplier,
                                    local_tone_mapping_affect__prev_hq_highlights_multiplier)


[es(tag=render, on_disappear)]
def local_tone_mapping_affect_disappear(evt : Event;
                                        game_effect__attachedTo : EntityId;
                                        local_tone_mapping_affect__prev_hq_shadows_multiplier : float;
                                        local_tone_mapping_affect__prev_hq_highlights_multiplier : float)
  if has(game_effect__attachedTo, "watchedByPlr")
    revert_local_tone_mapping_affect(local_tone_mapping_affect__prev_hq_shadows_multiplier,
                                     local_tone_mapping_affect__prev_hq_highlights_multiplier)


[es(tag=render, on_appear, REQUIRE=watchedByPlr)]
def actor_appear_update_local_tone_mapping_affect(evt : Event;
                                                  eid : EntityId)
  find_query() <| $ [es] (game_effect__attachedTo : EntityId;
                          local_tone_mapping_affect__hq_shadows_multiplier : float;
                          local_tone_mapping_affect__hq_highlights_multiplier : float;
                          var local_tone_mapping_affect__prev_hq_shadows_multiplier : float&;
                          var local_tone_mapping_affect__prev_hq_highlights_multiplier : float&)
    if game_effect__attachedTo == eid
      apply_local_tone_mapping_affect(local_tone_mapping_affect__hq_shadows_multiplier,
                                      local_tone_mapping_affect__hq_highlights_multiplier,
                                      local_tone_mapping_affect__prev_hq_shadows_multiplier,
                                      local_tone_mapping_affect__prev_hq_highlights_multiplier)
      return true
    return false

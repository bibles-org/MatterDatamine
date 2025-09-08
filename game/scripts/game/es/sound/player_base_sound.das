require ecs
require soundEvent
require game.events.events_active_matter
require game.es.traps_common


[es(tag=sound, on_appear)]
def player_base_state_onboarding_to_normal_step_sound_appear(evt : Event;
                                                             player_base_state_onboarding_to_normal_step__index : int)
  query() <| $ [es] (transform : float3x4;
                     player_base_onboarding_object_sound__path : string;
                     player_base_onboarding_object__stepIndex : int)
    if player_base_state_onboarding_to_normal_step__index == player_base_onboarding_object__stepIndex
      if player_base_onboarding_object_sound__path != ""
        oneshot(player_base_onboarding_object_sound__path, transform[3])

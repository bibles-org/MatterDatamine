require ecs
require soundEvent
require soundSystem
require strings
require game.events.events_active_matter


[es(tag=sound)]
def dash_sound_es(evt : EventOnPlayerDash;
                  dash_ability_sound__hero : string;
                  dash_ability_sound__enemy : string;
                  hero : Tag const?;
                  var ability_dash_sound__event : SoundEvent&)
  abandon(ability_dash_sound__event)
  let sound = hero != null ? dash_ability_sound__hero : dash_ability_sound__enemy
  if !empty(sound)
    ability_dash_sound__event |> play(sound, evt.to)
    ability_dash_sound__event.abandonOnReset = true
    if is_oneshot(ability_dash_sound__event)
      abandon(ability_dash_sound__event)

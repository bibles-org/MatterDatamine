require ecs
require ecs.safe
require game.events.events
require Gun

[es(track=gun__firingModeIndex)]
def gun_update_time_between_shots_es(evt : Event;
                                     gun : Gun;
                                     gun__firingModeIndex : int;
                                     gun__firingModes : Array;
                                     var gun__timeBetweenShots : float&)
  let gunModesSize = length(gun__firingModes)
  if gunModesSize == 0 || gun__firingModeIndex >= gunModesSize
    return

  let modeObj = gun__firingModes[gun__firingModeIndex] as Object
  if modeObj == null
    return

  assume gunProps = gun.gunProps
  gun__timeBetweenShots = gunProps.timeBetweenShots * ((*modeObj).shotFreqMult ?? 1.0)
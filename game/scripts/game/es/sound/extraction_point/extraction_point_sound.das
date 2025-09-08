require ecs
require app
require game.es.extraction_point.extraction_point_common
require sound_utils.modules.sound_player_common


def state_to_desc_name(extraction__currentState : int) : string
  if extraction__currentState == int(ExtractionPointState.DISABLED)
    return "disabled"
  elif extraction__currentState == int(ExtractionPointState.INACTIVE)
    return "inactive"
  elif extraction__currentState == int(ExtractionPointState.ACTIVATING)
    return "activating"
  elif extraction__currentState == int(ExtractionPointState.ACTIVE)
    return "active"
  elif extraction__currentState == int(ExtractionPointState.DEACTIVATING)
    return "deactivating"
  return "???"


[es(tag=sound, track=extraction__currentState)]
def extraction_point_sound_track_state(evt : Event;
                                       extraction__currentState : int;
                                       @shared_comp extraction_point_sound__statePaths : Object;
                                       transform : float3x4)

  let desc = get_desc(extraction_point_sound__statePaths, state_to_desc_name(extraction__currentState))
  if desc != null
    play_path(*desc, "", false, transform[3])

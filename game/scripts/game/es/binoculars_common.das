module binoculars_common shared
require ecs.enum_macro


[export_enum]
enum BinocularsUseState
  NONE
  IN
  IN_REVERSE
  WATCHING
  OUT
  DOWN_IDLE
  FINISHED
  INTERRUPTION


def operator ==(i : int; state : BinocularsUseState)
  return int(state) == i

def operator !=(i : int; state : BinocularsUseState)
  return int(state) != i


[export_enum]
enum BinocularsWatchingState
  NONE
  IN_FADEIN
  IN_FADE
  IN_FADEOUT
  IDLE
  OUT_FADEIN
  OUT_FADE
  OUT_FADEOUT


def operator ==(i : int; state : BinocularsWatchingState)
  return int(state) == i

def operator !=(i : int; state : BinocularsWatchingState)
  return int(state) != i


def stop_binoculars_use(var binoculars_controller__useState : int&)
  if binoculars_controller__useState == BinocularsUseState.WATCHING
    // Watching -> Out
    binoculars_controller__useState = int(BinocularsUseState.OUT)
  elif binoculars_controller__useState == BinocularsUseState.IN
    // In -> In Reverse
    binoculars_controller__useState = int(BinocularsUseState.IN_REVERSE)
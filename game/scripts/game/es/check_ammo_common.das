module check_ammo_common shared


enum CheckAmmoState
  NONE
  IN
  IN_REVERSE
  IDLE
  OUT
  FINISHED
  INTERRUPTION


def operator ==(i : int; state : CheckAmmoState)
  return int(state) == i

def operator !=(i : int; state : CheckAmmoState)
  return int(state) != i
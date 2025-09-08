module effect_controller_common shared
require ecs
require ecs.safe

struct EffectStateParams
  time : float2
  spawnRate : float2

def get_effect_state_params(effect_controller__states : Array; effect_controller__state : int) : EffectStateParams
  let obj = effect_controller__states[effect_controller__state] as Object
  if obj == null
    return EffectStateParams(time = float2(0, 0), spawnRate = float2(0, 0))
  let time = (*obj).time ?? float2(0, 0)
  let spawnRate = (*obj).spawnRate ?? float2(0, 0)
  return EffectStateParams(time = time, spawnRate = spawnRate)
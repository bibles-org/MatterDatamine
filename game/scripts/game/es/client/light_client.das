require ecs
require math.random
require game.es.system_common
require game.events.events_active_matter


[es(tag=gameClient, no_order)]
def light_blinker_update(act : ParallelUpdateFrameDelayed;
                         light_blinker__brightnessRange : float2;
                         light_blinker__brightnessBlinkInterval : float;
                         light_blinker__smoothKoef : float = 32.0;
                         var light_blinker__targetBrightness : float&;
                         var light_blinker__changeBrightnessAt : float&;
                         var light__brightness : float&)
  if act.curTime >= light_blinker__changeBrightnessAt
    light_blinker__targetBrightness = rnd_float(light_blinker__brightnessRange)
    light_blinker__changeBrightnessAt = act.curTime + light_blinker__brightnessBlinkInterval

  light__brightness = lerp(light__brightness, light_blinker__targetBrightness, light_blinker__smoothKoef * min_30_fps_dt(act.dt))

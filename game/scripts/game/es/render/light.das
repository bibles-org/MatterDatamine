require ecs
require daSkies
require game.events.events_active_matter
require game.es.render.light_common


[es(tag=render, on_appear)]
def light_turned_off_appear(evt : Event;
                            light_turned_off__newBrightness : float = 0.0;
                            var light__brightness : float&;
                            var light_turned_off__prevBrightness : float&)
  light_turned_off__prevBrightness = light__brightness
  light__brightness = light_turned_off__newBrightness


[es(tag=render, on_disappear)]
def light_turned_off_disappear(evt : Event;
                               light_turned_off__prevBrightness : float;
                               var light__brightness : float&)
  light__brightness = light_turned_off__prevBrightness


[es(tag=render, on_appear)]
def light_brightness_transition_init(evt : Event;
                                     light__brightness : float;
                                     var light_brightness_transition__prevBrightness : float&)
  light_brightness_transition__prevBrightness = light__brightness


[es(tag=render, no_order)]
def light_brightness_transition(act : UpdateStageInfoAct;
                                eid : EntityId;
                                light_brightness_transition__newBrightness : float;
                                light_brightness_transition__prevBrightness : float;
                                light_brightness_transition__time : float;
                                var light_brightness_transition__timer : float&;
                                var light__brightness : float&)
  light_brightness_transition__timer += act.dt
  let progress = light_brightness_transition__timer / light_brightness_transition__time
  if progress < 1.0
    light__brightness = lerp(light_brightness_transition__prevBrightness, light_brightness_transition__newBrightness, progress)
  else
    removeSubTemplate(eid, "light_brightness_transition")
    light__brightness = light_brightness_transition__newBrightness


[es(tag=render, on_appear)]
def light_brightness_to_zero_and_destroy_appear(evt : Event;
                                                eid : EntityId;
                                                light_brightness_to_zero_and_destroy__time : float)
  tween_light_brightness(eid, 0.0, light_brightness_to_zero_and_destroy__time)


[es(tag=render, on_disappear, REQUIRE=(light_brightness_transition__newBrightness, light_brightness_to_zero_and_destroy__time))]
def light_brightness_to_zero_and_destroy_finished(evt : Event;
                                                  eid : EntityId)
  destroyEntity(eid)


[es(tag=render)]
def change_skies_time(evt : CmdChangeSkiesTime)
  set_daskies_time(evt.time)
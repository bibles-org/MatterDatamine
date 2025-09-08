require ecs
require math.base
require DagorMath
require DngCamera
require soundEvent


[es(tag=sound, on_appear, track=sound_banks_state__isPresetLoaded)]
def am_pile_sound_toggle(evt : Event;
                         sound_banks_state__isPresetLoaded : bool;
                         am_pile_sound__path : string;
                         var am_pile_sound__range : float&;
                         var am_pile_sound__event : SoundEvent&)
  release_immediate(am_pile_sound__event)
  if sound_banks_state__isPresetLoaded
    am_pile_sound__range = get_max_distance(am_pile_sound__path)


[es(tag=sound, on_event=ParallelUpdateFrameDelayed, after=sound_begin_update_es, before=sound_end_update_es)]
def am_pile_sound_update(evt : Event;
                         sound_banks_state__isPresetLoaded : bool;
                         am_pile_sound__path : string;
                         am_pile_sound__range : float;
                         am_pile_sound__pitchFarNear : float2;
                         var am_pile_sound__event : SoundEvent&)

  if !sound_banks_state__isPresetLoaded
    return

  let listener = (get_cur_cam_entity() |> get_TMatrix("transform") ?? IDENT_TM)[3]
  var eventPos : float3
  var eventDistSq = square(am_pile_sound__range)

  query() <| $ [es(REQUIRE=amPileSoundSource)] (transform : float3x4)
    let distSq = distance_sq(transform[3], listener)
    if eventDistSq > distSq
      eventDistSq = distSq
      eventPos = transform[3]

  let isValidHandle = is_valid_handle_value(am_pile_sound__event)
  let inRange = (isValidHandle ? (eventDistSq < square(am_pile_sound__range)) :
                                 (eventDistSq < square(am_pile_sound__range * 0.9)))

  if inRange
    if !is_playing(am_pile_sound__event)
      release_immediate(am_pile_sound__event)
      am_pile_sound__event |> reset(play(am_pile_sound__path, listener))

    let t = square(cvt(sqrt(eventDistSq), 0., am_pile_sound__range, 1., 0.))
    set_volume(am_pile_sound__event, t)
    set_pitch(am_pile_sound__event, lerp(am_pile_sound__pitchFarNear.x, am_pile_sound__pitchFarNear.y, t))
    set_pos(am_pile_sound__event, (get_cur_cam_entity() |> get_TMatrix("transform") ?? IDENT_TM)[3])

  elif isValidHandle
    release(am_pile_sound__event)

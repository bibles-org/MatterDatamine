require ecs
require soundEvent
require DagorMath


[es(tag=sound, on_appear, after=rendinst_axis_force_initial_rotation_es, REQUIRE=rendinst_axis_rotation__enabled)]
def encounter_caponier_gate_sound_appear(evt : Event;
                                         var encounter_caponier_gate_sound__event : SoundEvent&;
                                         encounter_caponier_gate_sound__path : string;
                                         encounter_caponier_gate_sound__localPos : float3;
                                         transform : float3x4)
  encounter_caponier_gate_sound__event.abandonOnReset = true
  encounter_caponier_gate_sound__event |> play(encounter_caponier_gate_sound__path, transform * encounter_caponier_gate_sound__localPos)


[es(tag=sound, on_event=ParallelUpdateFrameDelayed, after=(rendinst_axis_rotation_es, sound_begin_update_es), before=sound_end_update_es, REQUIRE=rendinst_axis_rotation__enabled)]
def encounter_caponier_gate_sound_update(evt : Event;
                                         encounter_caponier_gate_sound__event : SoundEvent&;
                                         encounter_caponier_gate_sound__localPos : float3;
                                         transform : float3x4)
  set_pos(encounter_caponier_gate_sound__event, transform * encounter_caponier_gate_sound__localPos)

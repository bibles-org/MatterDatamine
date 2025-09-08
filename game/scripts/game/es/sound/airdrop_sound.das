require ecs
require soundEvent
require sound_utils.modules.sound_control_common


[es(tag=sound, on_appear, track=sound_control__state)]
def airdrop_sound_on_appear(evt : Event;
                            transform aka airdrop_transform : float3x4;
                            first_contact_listener__hadContact : bool;
                            airdrop_sound__flyPath : string;
                            sound_control__state : int;
                            var airdrop_sound__flyEvent : SoundEvent&)

  if have_sound(sound_control__state) && !first_contact_listener__hadContact
    airdrop_sound__flyEvent |> play(airdrop_sound__flyPath, airdrop_transform[3])


[es(tag=sound, on_event=ParallelUpdateFrameDelayed, after=sound_begin_update_es, before=sound_end_update_es)]
def airdrop_sound_on_update(evt : Event;
                            transform aka airdrop_transform : float3x4;
                            airdrop_sound__flyEvent : SoundEvent&)
  set_pos(airdrop_sound__flyEvent, transform[3])


[es(tag=sound, track=first_contact_listener__hadContact)]
def airdrop_sound_on_land(evt : Event;
                          transform aka airdrop_transform : float3x4;
                          first_contact_listener__hadContact : bool;
                          airdrop_sound__landPath : string;
                          var airdrop_sound__flyEvent : SoundEvent&)
  if first_contact_listener__hadContact
    abandon(airdrop_sound__flyEvent)
    oneshot(airdrop_sound__landPath, airdrop_transform[3])

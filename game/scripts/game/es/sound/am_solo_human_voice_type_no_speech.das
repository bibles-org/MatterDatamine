require ecs
require ecs.common
require math.random
require sound_utils.modules.sound_player_common


[es(tag=sound, on_appear, REQUIRE_NOT=humanNetSpeech)]
def am_solo_human_voice_type_no_speech_on_appear(evt : Event;
                                                 eid : EntityId;
                                                 am_solo_human_voice_type_no_speech__maxVoices : int;
                                                 var sound_flags : Object&)
  if am_solo_human_voice_type_no_speech__maxVoices > 0
    let voiceIdx = int(eid_frnd(eid) * float(am_solo_human_voice_type_no_speech__maxVoices)) % am_solo_human_voice_type_no_speech__maxVoices
    if voiceIdx > 0
      raise_sound_tag("voice{voiceIdx + 1}", sound_flags)

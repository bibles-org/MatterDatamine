require ecs
require sound_utils.modules.sound_player_common


[es(tag=sound, on_appear)]
def human_sound_tags_on_appear(evt : Event;
                               human_voice_sound__voiceTag : string;
                               var sound_flags : Object&)
  raise_sound_tag(human_voice_sound__voiceTag, sound_flags)

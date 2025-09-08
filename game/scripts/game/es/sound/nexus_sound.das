require ecs
require soundEvent


[es(tag=sound, on_appear)]
def nexus_militant_on_appear_sound(evt : Event;
                                   transform : float3x4;
                                   nexus_militant__onAppearSoundHero : string;
                                   nexus_militant__onAppearSoundOther : string;
                                   is_watched_sound : bool)

  if is_watched_sound
    oneshot(nexus_militant__onAppearSoundHero, transform[3])
  else
    oneshot(nexus_militant__onAppearSoundOther, transform[3])


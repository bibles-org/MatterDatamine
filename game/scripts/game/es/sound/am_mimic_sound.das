require ecs
require soundEvent
require soundSystem
require game.events.events_active_matter
require game.events.events_game

[es(tag=sound)]
def am_mimic_attack_sound_es(evt : EventMimicAttack;
                             am_mimic_sound__missPath : string;
                             am_mimic_sound__attackPath : string)
  oneshot(evt.success ? am_mimic_sound__attackPath : am_mimic_sound__missPath, evt.pos)


[es(tag=sound)]
def am_mimic_prepare_sound_es(evt : EventMimicAttackPrepare; transform : float3x4; am_mimic_sound__preparePath : string)
  oneshot(am_mimic_sound__preparePath, transform[3])

[es(tag=sound)]
def am_mimic_death_sound_es(evt : EventEntityDied; transform : float3x4; am_mimic_sound__deathPath : string)
  oneshot(am_mimic_sound__deathPath, transform[3])

[es(tag=sound)]
def am_mimic_step_sound_es(evt : EventamMimicStep; am_mimic_sound__stepPath : string)
  oneshot(am_mimic_sound__stepPath, evt.pos)

[es(tag=sound, on_appear)]
def am_mimic_appear_sound_es(evt : Event; transform : float3x4; am_mimic_sound__appearPath : string)
  oneshot(am_mimic_sound__appearPath, transform[3])

[es(tag=sound)]
def am_mimic_damaged_sound_es(evt : EventMimicDamaged; transform : float3x4; am_mimic_sound__damagedPath : string)
  oneshot(am_mimic_sound__damagedPath, transform[3])
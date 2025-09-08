require ecs
require sound_utils.modules.sound_player_common
require human_sounds.modules.human_voice_effect_common
require human_sounds.modules.human_sounds_events
require soundEvent
require soundHash
require DngHuman


[es(tag=sound, on_appear, before=human_voice_effect_on_change, track=human_net_phys__isHoldBreath)]
def human_voice_effect_hold_breath(evt : Event;
                                   eid : EntityId;

                                   human_net_phys : HumanActor&;

                                   human_net_phys__isHoldBreath : bool;
                                   var human_voice_effect__activeEffects : Object&;
                                   @shared_comp human_voice_effect__allOrderedEffects : StringList)
  if set_human_voice_effect("holdBreath", human_net_phys__isHoldBreath, human_voice_effect__activeEffects, human_voice_effect__allOrderedEffects)

    if human_net_phys__isHoldBreath
      sendEvent(eid, CmdHumanVoiceEffectOneshot(phrase = "holdBreathStart"))
    else
      sendEvent(eid, CmdHumanVoiceEffectOneshot(phrase = "holdBreathEnd", varName = "noairtime", varValue = human_net_phys.phys.currentState.breathShortness))

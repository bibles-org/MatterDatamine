require ecs
require ecs.safe
require soundEvent
require game.events.events_game


[es(tag=sound, on_appear)]
def onboarding_before_sound_init(evt : Event;
                                 onboarding_before_sound__path : string;
                                 var onboarding_before_sound__event : SoundEvent&)
  onboarding_before_sound__event.abandonOnReset = true
  onboarding_before_sound__event |> play(onboarding_before_sound__path)


[es(tag=sound, REQUIRE=hero)]
def onboarding_before_sound_on_irq(evt : EventAnimIrq;
                                   anim_irq__eventNames : Object)
  query() <| $ [es] (onboarding_before_sound__endIrq : string;
                     var onboarding_before_sound__event : SoundEvent&)
    let irqEventObj = anim_irq__eventNames[onboarding_before_sound__endIrq] ?as Object
    let irqId = irqEventObj?.irqId ?? 0
    if irqId == evt.irqType
      onboarding_before_sound__event |> abandon()

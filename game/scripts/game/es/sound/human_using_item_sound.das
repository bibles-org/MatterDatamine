require ecs
require ecs.common
require soundHash
require soundEvent
require sound_utils.modules.sound_player_common
require common_sounds.modules.common_sounds_events


[es(tag=sound, track=(human_inventory__entityToUse, isAlive), REQUIRE=humanSound)]
def human_using_item_sound(evt : Event;
                           sound_tags : Object;
                           human_inventory__entityToUse : EntityId;
                           var sound_event_group : SoundEventGroup&;
                           is_watched_sound : bool;
                           transform : float3x4;
                           isAlive : bool)
  reject_sound(sound_event_group, sound_hash("loot"))
  if human_inventory__entityToUse != INVALID_ENTITY_ID && isAlive && should_play(transform[3])
    query(human_inventory__entityToUse) <| $ [es] (@shared_comp using_item_sound__path : Object)
      play_path(using_item_sound__path, sound_tags, is_watched_sound, transform[3], sound_hash("loot"), sound_event_group)


[es(tag=sound)]
def using_item_irq_sound(evt : CmdSoundIrq;
                         human_inventory__entityToUse : EntityId;
                         sound_tags : Object;
                         is_watched_sound : bool;
                         transform : float3x4;
                         var sound_event_group : SoundEventGroup&)

  if evt.irqType == sound_hash("humanUsingItem")
    reject_sound(sound_event_group, sound_hash("usingItemIrq"))
    ecs::query(human_inventory__entityToUse) <| $ [es] (@shared_comp using_item_irq_sound__paths : Object)
      play_path(evt.irq, using_item_irq_sound__paths, sound_tags, is_watched_sound, transform[3], sound_hash("usingItemIrq"), sound_event_group)


[es(tag=sound, track=(human_inventory__entityToUse, isAlive, is_watched_sound), REQUIRE=(human_inventory__entityToUse, isAlive, is_watched_sound))]
def using_item_irq_sound_interrupt(evt : Event;
                                   var sound_event_group : SoundEventGroup&)
  reject_sound(sound_event_group, sound_hash("usingItemIrq"))

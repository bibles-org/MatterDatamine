require ecs
require ecs.safe
require soundEvent
require soundHash
require game.events.events_game
require active_matter.game.es.check_ammo_common
require common_sounds.modules.common_sounds_events
require sound_utils.modules.sound_player_common
require game.es.anim_common


[es(tag=sound, on_appear, before=anim_init_irq_listener_es)]
def loading_ammo_controller_sound_init(evt : Event;
                                       loading_ammo_controller_sound__bulletLoadedIrq : string;
                                       loading_ammo_controller_sound__bulletUnloadedIrq : string;
                                       var anim_irq__eventNames : Object)
  add_irq_event_name(anim_irq__eventNames, loading_ammo_controller_sound__bulletLoadedIrq)
  add_irq_event_name(anim_irq__eventNames, loading_ammo_controller_sound__bulletUnloadedIrq)


[es(tag=sound, on_appear, after=anim_init_irq_listener_es)]
def loading_ammo_controller_sound_irq_id_init(evt : Event;
                                              loading_ammo_controller_sound__bulletLoadedIrq : string;
                                              loading_ammo_controller_sound__bulletUnloadedIrq : string;
                                              anim_irq__eventNames : Object;
                                              var loading_ammo_controller_sound__bulletLoadedIrqId : int&;
                                              var loading_ammo_controller_sound__bulletUnloadedIrqId : int&)
  for event in anim_irq__eventNames
    if event.key == loading_ammo_controller_sound__bulletLoadedIrq
      loading_ammo_controller_sound__bulletLoadedIrqId = (event.value as Object)?.irqId ?? -1
    elif event.key == loading_ammo_controller_sound__bulletUnloadedIrq
      loading_ammo_controller_sound__bulletUnloadedIrqId = (event.value as Object)?.irqId ?? -1


[es(tag=sound)]
def loading_ammo_controller_sound_anim_irq(evt : EventAnimIrq;
                                           loading_ammo_controller_sound__bulletLoadedIrqId : int;
                                           loading_ammo_controller_sound__bulletUnloadedIrqId : int;
                                           @shared_comp human_ammo_loading_sound__path : Object;
                                           @shared_comp human_ammo_unloading_sound__path : Object;
                                           sound_tags : Object;
                                           is_watched_sound : bool;
                                           transform : float3x4)
  if loading_ammo_controller_sound__bulletLoadedIrqId == evt.irqType
    sound_player_common::play_path(human_ammo_loading_sound__path, sound_tags, is_watched_sound, transform[3])
  elif loading_ammo_controller_sound__bulletUnloadedIrqId == evt.irqType
    sound_player_common::play_path(human_ammo_unloading_sound__path, sound_tags, is_watched_sound, transform[3])
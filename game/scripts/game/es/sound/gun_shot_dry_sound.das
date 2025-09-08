require ecs
require app
require soundEvent
require DagorMath
require DagorRandom
require game.es.sound.gun_sound_common
require game.es.status_tip_common
require game.events.events_active_matter


[es(tag=sound, on_event=EventShotDry)]
def gun_shot_dry_sound(evt : Event;
                       gun_sound__isEnabled : bool;
                       gun_shot_dry_sound__path : string;
                       var gun_shot_dry_sound__nextTime : float&;
                       gun_shot_dry_sound__cooldown : float;
                       sound_banks_state__isPresetLoaded : bool;
                       gun__owner : EntityId;
                       animchar_bbox : bbox3f)
  if gun_sound__isEnabled && sound_banks_state__isPresetLoaded && get_sync_time() >= gun_shot_dry_sound__nextTime && is_watched_gun_sound(gun__owner)
    oneshot(gun_shot_dry_sound__path, get_gun_sound_pos(animchar_bbox))
  gun_shot_dry_sound__nextTime = get_sync_time() + gun_shot_dry_sound__cooldown

[es(tag=sound, on_event=EventShotDry, REQUIRE=watchedPlayerItem)]
def gun_shot_dry_out_of_ammo_tip(evt : Event;
                                 gun__owner : EntityId;
                                 gun_jamming__isJammed : bool = false)
  query(gun__owner) <| $ [es(REQUIRE=hero)] (watchedByPlr : EntityId;
                                             human_weap__outOfAmmoVoiceChance : float;
                                             var human_weap__outOfAmmoShotCount : int&;
                                             var human_weap__outOfAmmoLastShotAt : float&)
    ++human_weap__outOfAmmoShotCount
    human_weap__outOfAmmoLastShotAt = get_sync_time()

    if human_weap__outOfAmmoShotCount == 3
      if gun_jamming__isJammed
        create_status_tip("status_tip_jammed_gun")
      else
        create_status_tip("status_tip_out_of_ammo")

    if human_weap__outOfAmmoShotCount == 5 && rnd_float(0.0, 1.0) < human_weap__outOfAmmoVoiceChance
      if gun_jamming__isJammed
        sendEvent(watchedByPlr, CmdStartAssistantSpeak(scriptName = "hint_jammed_gun", skipBeepSound = true))
      else
        sendEvent(watchedByPlr, CmdStartAssistantSpeak(scriptName = "hint_out_of_ammo", skipBeepSound = true))


[es(tag=gameClient, no_order, REQUIRE=hero)]
def reset_out_of_ammo_shot_count(info : UpdateStageInfoAct;
                                 human_weap__outOfAmmoLastShotAt : float;
                                 human_weap__outOfAmmoShotTipCooldown : float;
                                 var human_weap__outOfAmmoShotCount : int&)
  if info.curTime >= human_weap__outOfAmmoLastShotAt + human_weap__outOfAmmoShotTipCooldown
    human_weap__outOfAmmoShotCount = 0

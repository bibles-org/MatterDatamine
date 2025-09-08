require ecs
require sound_utils.modules.sound_player_common
require DngHuman


[es(tag=sound, on_event=ParallelUpdateFrameDelayed, after=sound_begin_update_es, before=sound_end_update_es, REQUIRE=watchedByPlr, REQUIRE_NOT=deadEntity)]
def human_weapon_change_sound__update(evt : Event;
                                      @shared_comp human_weapon_change_sound__paths : Object;
                                      var human_weapon_change_sound__weapEquipCurState : int&;
                                      sound_tags : Object;
                                      human_net_phys : HumanActor&;
                                      transform : float3x4)
  assume sndState = human_weapon_change_sound__weapEquipCurState
  assume curState = human_net_phys.phys.currentState.weapEquipState.curState

  if sndState != int(curState)
    if curState == HUWeaponEquipState.EES_HOLSTERING
      sound_player_common::play_path("holstering", human_weapon_change_sound__paths, sound_tags, true/*is_watched_sound*/, transform[3])
    elif curState == HUWeaponEquipState.EES_EQUIPING
      sound_player_common::play_path("equiping", human_weapon_change_sound__paths, sound_tags, true/*is_watched_sound*/, transform[3])
    sndState = int(curState)

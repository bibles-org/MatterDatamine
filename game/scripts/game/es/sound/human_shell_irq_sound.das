require ecs
require HumanPhys
require soundEvent
require soundHash
require DaWeaponProps
require shellSoundProps
require strings
require common_sounds.modules.common_sounds_events
require sound_utils.modules.sound_player_common


[es(tag=sound)]
def human_shell_irq_sound(evt : CmdSoundIrq;
                          human_weap__gunEids : EidList;
                          is_watched_sound : bool;
                          transform : float3x4)
  if evt.irqType == sound_hash("grenadeActivate")
    query(human_weap__gunEids[int(HUWeaponSlots.EWS_GRENADE)]) <| $ [es] (gun__curShellId : ShellPropIds)
      let shellSoundProps = shell_sound_try_get_props(int(gun__curShellId.shellId))
      if shellSoundProps != null
        let path : string = is_watched_sound ? (*shellSoundProps).activateHero : (*shellSoundProps).activateEnemy
        if !empty(path)
          oneshot(path, transform[3])

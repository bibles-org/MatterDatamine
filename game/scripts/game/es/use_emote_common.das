module use_emote_common shared
require app
require ecs
require ecs.safe
require DngHuman
require danetlibs.human_sec_anim.human_sec_anim_events


def check_emote_interrupt(eid : EntityId; ct : HumanControlState; throwMode : bool)
  let isHctShootSet = is_control_bit_set(ct, HumanPhysControlType.HCT_SHOOT)
  let isHctThrowSet = is_control_bit_set(ct, HumanPhysControlType.HCT_THROW)
  let isHctThrowBackSet = is_control_bit_set(ct, HumanPhysControlType.HCT_THROW_BACK)
  if isHctShootSet || throwMode || isHctThrowSet || isHctThrowBackSet
    sendEvent(eid, CmdStopSecAnim(immediately = true))


def set_emote(hero_eid : EntityId; idx : int)
  query(hero_eid) <| $ [es] (@shared_comp human_sec_anim__config : Array;
                             var human_sec_anim__setup : das_string&;
                             var human_sec_anim__a2d : das_string&;
                             var human_sec_anim__hideMelee : bool&;
                             var human_sec_anim__hideWeapon : bool&;
                             var human_sec_anim__duration : float&)
    let emoteConfig = get_ecs_object(human_sec_anim__config[idx])
    human_sec_anim__setup := get_string(emoteConfig, "setup", "")
    human_sec_anim__a2d := get_string(emoteConfig, "a2d", "")
    human_sec_anim__hideMelee = emoteConfig?.hideMelee ?? false
    human_sec_anim__hideWeapon = emoteConfig?.hideWeapon ?? false
    human_sec_anim__duration = emoteConfig?.duration ?? 1f


def use_emote(emoteId : int;
              eid : EntityId;
              human_sec_anim__config : Array;
              human_sec_anim__play : bool;
              human_sec_anim__timeOffset : float = 0.1f;
              human_net_phys : HumanActor;
              human_weap_anim__reloadAtTime : float;
              action__running : bool;
              isAlive : bool;
              isDowned : bool;
              human_weap__throwMode : bool;
              human_sec_anim__interruptsMovement : bool)
  if !human_sec_anim__play
    if human_weap_anim__reloadAtTime < get_sync_time() && !is_control_bit_set(human_net_phys.phys.appliedCT, HumanPhysControlType.HCT_SHOOT) && !action__running
      if isAlive && !isDowned && !human_weap__throwMode && !(human_sec_anim__interruptsMovement && human_net_phys.phys.appliedCT.isMoving)
        if length(human_sec_anim__config) > emoteId
          set_emote(eid, emoteId)//todo sync across clients before animation starts playing
          sendEvent(eid, CmdStartSecAnim(startTime = get_sync_time() + human_sec_anim__timeOffset))
  else
    sendEvent(eid, CmdStopSecAnim(immediately = false))

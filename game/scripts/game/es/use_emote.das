require ecs
require DngHuman
require game.events.events
require game.es.use_emote_common
require game.events.events_active_matter
require danetlibs.human_sec_anim.human_sec_anim_events
require game.events.events_game


[es(no_order)]
def human_emote_interrupt_smooth_es(info : ParallelUpdateFrameDelayed;
                                    eid : EntityId;
                                    human_net_phys : HumanActor;
                                    human_weap_anim__reloadAtTime : float;
                                    action__running : bool;
                                    isDowned : bool;
                                    human_weap__throwMode : bool;
                                    human_sec_anim__interruptsMovement : bool;
                                    human_sec_anim__play : bool)
  if !human_sec_anim__play
    return

  var interruptAnim = human_weap_anim__reloadAtTime > info.curTime
  interruptAnim ||= action__running
  interruptAnim ||= isDowned
  interruptAnim ||= human_weap__throwMode
  interruptAnim ||= human_sec_anim__interruptsMovement && human_net_phys.phys.appliedCT.isMoving
  if interruptAnim
    sendEvent(eid, CmdStopSecAnim(immediately = false))


[es(tag=server, before=human_weap_es, REQUIRE_NOT=disableUpdate)]
def human_emote_interrupt_immediately_server_es(info : CmdPostPhysUpdate;
                                                eid : EntityId;
                                                isDowned : bool;
                                                human_net_phys : HumanActor;
                                                human_sec_anim__play : bool;
                                                human_weap__throwMode : bool)
  if !human_sec_anim__play || isDowned
    return
  check_emote_interrupt(eid, human_net_phys.phys.appliedCT, human_weap__throwMode)


[es]
def human_emote_interrupt_on_death_es(evt : EventEntityDied; eid : EntityId; human_sec_anim__play : bool)
  if human_sec_anim__play
    sendEventImmediate(eid, CmdStopSecAnim(immediately = true))


[es(tag=server)]
def human_use_emote_es(evt : CmdRequestUseEmote;
                       eid : EntityId;
                       @shared_comp human_sec_anim__config : Array;
                       human_sec_anim__play : bool;
                       human_sec_anim__timeOffset : float = 0.1f;
                       human_net_phys : HumanActor;
                       human_weap_anim__reloadAtTime : float;
                       action__running : bool;
                       isAlive : bool;
                       isDowned : bool;
                       human_weap__throwMode : bool;
                       human_sec_anim__interruptsMovement : bool)
  use_emote(evt.emoteId, eid, human_sec_anim__config, human_sec_anim__play, human_sec_anim__timeOffset,
            human_net_phys, human_weap_anim__reloadAtTime, action__running, isAlive, isDowned,
            human_weap__throwMode, human_sec_anim__interruptsMovement)


[es(tag=server)]
def human_cmd_use_emote_es(evt : CmdUseEmote;
                           eid : EntityId;
                           @shared_comp human_sec_anim__config : Array;
                           human_sec_anim__play : bool;
                           human_sec_anim__timeOffset : float = 0.1f;
                           human_net_phys : HumanActor;
                           human_weap_anim__reloadAtTime : float;
                           action__running : bool;
                           isAlive : bool;
                           isDowned : bool;
                           human_weap__throwMode : bool;
                           human_sec_anim__interruptsMovement : bool)
  use_emote(evt.emoteId, eid, human_sec_anim__config, human_sec_anim__play, human_sec_anim__timeOffset,
            human_net_phys, human_weap_anim__reloadAtTime, action__running, isAlive, isDowned,
            human_weap__throwMode, human_sec_anim__interruptsMovement)

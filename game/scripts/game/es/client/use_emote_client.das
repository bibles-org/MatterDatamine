require ecs
require DngHuman
require AnimV20
require DngHumanSecAnim
require game.es.use_emote_common
require game.events.events_active_matter


[es(tag=gameClient, before=human_weap_client_es)]
def human_emote_interrupt_immediately_client_es(info : ParallelUpdateFrameDelayed;
                                                eid : EntityId;
                                                isDowned : bool;
                                                human_net_phys : HumanActor;
                                                human_sec_anim__play : bool;
                                                human_weap__throwMode : bool)
  if !human_sec_anim__play || isDowned
    return
  check_emote_interrupt(eid, human_net_phys.phys.producedCT, human_weap__throwMode)


[es(tag=gameClient, track=human_sec_anim__a2d)]
def track_secondary_anim_a2d(evt : Event;
                             human_sec_anim__a2d : string;
                             var animchar : AnimcharBaseComponent;
                             var human_sec_anim : Animate2ndPassCtx)
  if !empty(human_sec_anim__a2d)
    human_sec_anim |> animate_2nd_pass_ctx_release(animchar)

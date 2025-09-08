require ecs
require app
require player
require AnimV20
require HumanPhys
require DngHuman
require game.events.events_game
require game.events.events_active_matter

[es(on_event=CmdPutOutFireStart)]
def put_out_fire_start(evt : Event; burning__isBurning : bool; var burning__isPuttingOut : bool&)
  if burning__isBurning
    burning__isPuttingOut = true

[es(track=burning__isBurning)]
def put_out_fire_burning_stop(evt : Event; burning__isBurning : bool; var burning__isPuttingOut : bool&)
  if !burning__isBurning
    burning__isPuttingOut = false

[es(tag=server, no_order)]
def put_out_progress(info : ParallelUpdateFrameDelayed; var burning__force : float&; burning__putOutForce : float; burning__isPuttingOut : bool;
                     human_net_phys : HumanActor)
  if !burning__isPuttingOut
    return
  assume ct = human_net_phys.phys.currentState
  if ct.standState == HUStandState.ESS_CRAWL && ct.moveState != HUMoveState.EMS_STAND
    return
  burning__force -= burning__putOutForce * info.dt

[es(on_appear)]
def init_put_out_fire_anim_vars(evt : Event;
                                burning__animPutOutEnumName : string;
                                var burning__animPutOutEnum : int&)
  burning__animPutOutEnum = animV20_get_enum_value_by_name(burning__animPutOutEnumName)
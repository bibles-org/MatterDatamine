require ecs
require app
require HumanPhys
require DngHuman
require DagorMath
require Dacoll
require RendInst
require game.events.events
require game.events.events_active_matter
require math.base


[es(after=keep_human_net_phys_cur_state_es)]
def keep_human_net_phys_zoom_render_state_es(info : UpdateStageInfoAct;
                                             human_net_phys__isZooming : bool;
                                             var human_net_phys__isZoomingRenderData : bool&)
  human_net_phys__isZoomingRenderData = human_net_phys__isZooming


[es(after=human_phys_es)]
def keep_human_net_phys_cur_state_es(info : ParallelUpdateFrameDelayed;
                                     human_net_phys : HumanActor;
                                     var human_net_phys__curMoveState : int&;
                                     var human_net_phys__isHoldBreath : bool&;
                                     var human_net_phys__isSwimming : bool&;
                                     var human_net_phys__isUnderwater : bool&;
                                     var human_net_phys__isAiming : bool&;
                                     var human_net_phys__isOnGround : bool&;
                                     var human_net_phys__isCrawl : bool&;
                                     var human_net_phys__isCrouch : bool&;
                                     var human_net_phys__deltaVelIgnoreAmount : float&;
                                     var human_net_phys__aimPosition : float&;
                                     var human_net_phys__standState : int&;
                                     var human_net_phys__isInAir : bool&;
                                     var human_net_phys__velocity : float3&;
                                     var human_net_phys__locationPos : DPoint3&;
                                     var human_net_phys__isZooming : bool&;
                                     var human_net_phys__moveSpeedMult : float&;
                                     var human_net_phys__torsoContactMatId : int&)
  assume currentState = human_net_phys.phys.currentState

  human_net_phys__curMoveState = int(currentState.moveState)
  human_net_phys__isHoldBreath = is_hold_breath(currentState)
  human_net_phys__isSwimming = human_phys_state_get_is_swimming(currentState)
  human_net_phys__isUnderwater = human_phys_state_get_is_underwater(currentState)
  human_net_phys__isAiming = currentState.isAiming
  human_net_phys__isCrawl = currentState.isCrawl
  human_net_phys__isCrouch = currentState.isCrouch
  human_net_phys__isOnGround = (uint(currentState.states) & uint(StateFlag.ST_ON_GROUND)) != 0u
  human_net_phys__deltaVelIgnoreAmount = currentState.deltaVelIgnoreAmount
  human_net_phys__velocity = currentState.velocity
  human_net_phys__aimPosition = currentState.aimPosition
  human_net_phys__standState = int(currentState.standState)
  human_net_phys__isInAir = (uint(currentState.isInAirHistory) & 1u) != 0u && (uint(currentState.states) & uint(StateFlag.ST_SWIM)) == 0u
  human_net_phys__locationPos = currentState.location.P
  human_net_phys__isZooming = human_net_phys.phys.currentState.isZooming
  human_net_phys__torsoContactMatId = human_net_phys.phys.currentState.torsoContactMatId
  human_net_phys__moveSpeedMult = currentState.moveSpeedMult


[es(after=before_net_phys_sync, before=after_net_phys_sync)]
def human_phys_save_weap_state_es(info : ParallelUpdateFrameDelayed;
                                  human_net_phys : HumanActor;
                                  var human_net_phys__weapEquipCurState : int&;
                                  var human_net_phys__weapEquipCurSlot : int&;
                                  var human_net_phys__weapEquipNextSlot : int&)
  human_net_phys__weapEquipCurState = int(human_net_phys.phys.currentState.weapEquipState.curState)
  human_net_phys__weapEquipCurSlot = int(human_net_phys.phys.currentState.weapEquipState.curSlot)
  human_net_phys__weapEquipNextSlot = int(human_net_phys.phys.currentState.weapEquipState.nextSlot)


[es(tag=(net, server), track=isAlive)]
def net_phys_disable_update_on_death_track_is_alive(evt : Event;
                                                    eid : EntityId;
                                                    net_phys__disableUpdateOnDeathTemplate : string;
                                                    isAlive : bool)
  if !isAlive
    addSubTemplate(eid, net_phys__disableUpdateOnDeathTemplate)
  else
    removeSubTemplate(eid, net_phys__disableUpdateOnDeathTemplate)

def is_in_air(human_phys__inAirTime : float)
  return human_phys__inAirTime != 0.

def was_in_air(human_phys__previousInAirTime : float; human_phys__inAirTimeThreshold : float)
  return human_phys__previousInAirTime > human_phys__inAirTimeThreshold

[es]
def human_phys_set_jump_start_time(update : CmdPostPhysUpdate;
                                   human_net_phys : HumanActor;
                                   var human_phys__jumpStartTime : float&)
  assume currentState = human_net_phys.phys.currentState
  assume previousState = human_net_phys.phys.previousState
  if (int(currentState.states) & int(StateFlag.ST_JUMP)) != 0 && (int(previousState.states) & int(StateFlag.ST_JUMP)) == 0
    human_phys__jumpStartTime = float(update.tick) * update.dt

[es]
def human_phys_set_in_air_time(update : CmdPostPhysUpdate;
                               human_net_phys : HumanActor;
                               var human_phys__previousInAirTime : float&;
                               var human_phys__inAirTime : float&;
                               isInVehicle : bool = false)
  assume currentState = human_net_phys.phys.currentState
  human_phys__previousInAirTime = human_phys__inAirTime
  let isInAir = (int(currentState.isInAirHistory) & 1) != 0 && (int(currentState.states) & int(StateFlag.ST_SWIM)) == 0 && !isInVehicle
  human_phys__inAirTime = isInAir ? (human_phys__inAirTime + update.dt) : 0.f

[es(after=human_phys_set_in_air_time)]
def human_phys_in_air_long(update : CmdPostPhysUpdate;
                           human_phys__previousInAirTime : float;
                           human_phys__inAirTime : float;
                           human_phys__inAirTimeThreshold : float;
                           human_phys__inAirSpeedThreshold : float;
                           var human_phys__isInAirLong : bool&;
                           human_net_phys : HumanActor;
                           var human_phys__jumpEndTime : float&)
  assume currentState = human_net_phys.phys.currentState

  let wasInAir = was_in_air(human_phys__previousInAirTime, human_phys__inAirTimeThreshold)
  let isInAir = is_in_air(human_phys__inAirTime)

  if isInAir && wasInAir
    human_phys__isInAirLong = abs(currentState.velocity.y) > human_phys__inAirSpeedThreshold
  if !isInAir && human_phys__isInAirLong
    let physTime = float(update.tick) * update.dt
    human_phys__jumpEndTime = physTime
    human_phys__isInAirLong = false


[es(after=(before_entity_mods_apply_sync_point, entity_speed_mod_apply),
    before=(update_phys_es, after_entity_mods_apply_sync_point))]
def human_phys_forbid_moving_while_transition_crawl(info : ParallelUpdateFrameDelayed;
                                                    human_anim__crawlThreshold : float;
                                                    human_net_phys__crawlTransitionMoveSpeedMult : float;
                                                    var human_net_phys : HumanActor&)
  assume currentState = human_net_phys.phys.currentState
  if currentState.height < human_anim__crawlThreshold && !is_equal_float(currentState.height, -1.f)
    currentState.moveSpeedMult = human_net_phys__crawlTransitionMoveSpeedMult
    currentState.crawlCrouchSpeedMult = human_net_phys__crawlTransitionMoveSpeedMult


[es(track=human_net_phys__isClimbing)]
def human_phys_force_stop_after_climbing_if_abyss_ahead(evt : Event;
                                                        human_net_phys__isClimbing : bool;
                                                        human_net_phys__stopAfterClimbingIfAbyssAhead : bool;
                                                        human_net_phys__stopAfterClimbingIfAbyssAheadThreshold : float = 0.1;
                                                        human_net_phys__stopAfterClimbingIfAbyssAheadHorzCheck : float = 1.0;
                                                        human_net_phys__stopAfterClimbingIfAbyssAheadVertCheck : float = 2.0;
                                                        human_net_phys__stopAfterClimbingIfAbyssAheadSafeImpulse : float = 0.5;
                                                        transform : float3x4;
                                                        var human_net_phys : HumanActor)
  if !human_net_phys__isClimbing && human_net_phys__stopAfterClimbingIfAbyssAhead
    let heroPosWithThreshold = transform[3] + transform[1] * human_net_phys__stopAfterClimbingIfAbyssAheadThreshold
    let traceAbyssPos = heroPosWithThreshold + transform[0]
    var t0 = human_net_phys__stopAfterClimbingIfAbyssAheadHorzCheck
    var t1 = human_net_phys__stopAfterClimbingIfAbyssAheadVertCheck

    var norm = float3()
    var riDesc = RendInstDesc()
    var pmid : int
    let frw = transform[0]
    let down = -transform[1]
    var outVel : float3
    if (!traceray_normalized(heroPosWithThreshold, frw, t0, pmid, norm, ETF_DEFAULT, riDesc, human_net_phys.phys.rayMatId) &&
       !traceray_normalized(traceAbyssPos, down, t1, pmid, norm, ETF_DEFAULT, riDesc, human_net_phys.phys.rayMatId) &&
       !trace_game_objects(traceAbyssPos, down, t1, outVel, 0, human_net_phys.phys.rayMatId))
      human_net_phys.phys.currentState.velocity = -transform[0] * human_net_phys__stopAfterClimbingIfAbyssAheadSafeImpulse
      human_net_phys.phys.currentState.moveState = HUMoveState.EMS_STAND

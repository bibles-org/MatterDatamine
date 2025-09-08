require ecs
require net
require math.base
require DngHuman
require DagorMath
require game.events.events
require game.events.events_game
require game.utils.net_utils
require ecs.soa_template
require game.es.entity_mods_common


[soa_template]
struct HeartrateTrackedHP
  heartrate__hpinfo__tick : int
  heartrate__hpinfo__hp : float


[soa_es, es(before=human_weapon_aim)]
def hearbeat_es(cmd : CmdPostPhysUpdate;
                heartrate__range : float2;
                heartrate__sprintMult : float2;
                heartrate__handStaminaMult : float2;
                heartrate__climbSpeedMult : float2;
                heartrate__holdBreathDrain : float2;
                heartrate__restoreBreath : float2;
                heartrate__changePos : float2;
                heartrate__recoverBreath : float2;
                heartrate__dodgeMulti : float2;
                heartrate__riseTau : float;
                heartrate__fallTau : float;
                heartrate__riseSpeedMulti : float;
                heartrate__fallSpeedMulti : float;
                heartrate__sprintPow : float;
                heartrate__walkHR : float;
                heartrate__sprintHR : float;
                heartrate__climbHR : float;
                heartrate__standUpHR : float;
                heartrate__jumpHR : float;
                heartrate__dodgeHR : float;
                heartrate__elevationGainHR : float;
                heartrate__damagedHR : float;
                heartrate__downhillMulti : float;
                heartrate__amortizationFractionPerSecond : float;
                heartrate__overflowHRToAmortizationRatio : float;
                heartrate__restCooldown : float;
                heartrate__fatigueThreshold : float;
                heartrate__maxStamina : float;
                heartrate__movementHRStaminaMult : float2;
                heartrate__normalizationSpeed : float2;
                heartrate__staminaRegenPeakHR : float;
                heartrate__staminaRegen : float3;
                heartrate__staminaDrain : float2;
                heartrate__fatigueHRRatio : float;
                heartrate__fatigueHRPow : float;
                heartrate__hpDelayTicks : int;
                heartrate_history__length : int = 0; // 0 on server
                human_ladder__attached : bool;
                entity_mods__changePosModsMulti : float;
                human_damage_model__sumMaxHpAllBodyParts : float;
                heartrate__damagedStaminaPow : float;
                heartrate__damagedStaminaMaxMulti : float;
                var heartrate__lastHighActivityAt : float&;
                var heartrate__amortization : float&;
                var human_net_phys : HumanActor;
                var heartrate__value : float&;
                var heartrate__debugInfoTarget : float4&;
                var heartrate__debugInfoAmort : float2&;
                var heartrate__stamina : float&;
                var heartrate__staminaRate : float&;
                var human_hand_stamina__HRMult : float&;
                var human_hold_breath__holdBreathDrain : float&;
                var human_hold_breath__restoreBreath : float&;
                var human_dodge__dodgeSpdMulti : float&;
                var human_breath__recoverBreathMult : float&;
                var hpinfo : HeartrateTrackedHP_SOA)
  assume state = human_net_phys.phys.currentState
  let currectMovementHRStaminaMult = cvt(heartrate__stamina,
                                          .0,
                                          heartrate__maxStamina,
                                          heartrate__movementHRStaminaMult.y,
                                          heartrate__movementHRStaminaMult.x)
  let (prevHP, curHP) = calc_relevant_hr_hp(cmd.tick, heartrate__hpDelayTicks + heartrate_history__length, hpinfo)

  // CmdPostPhysUpdate is sent before this flag updated (e.g. on phys resync on AAS apply)
  let human_net_phys__isInAir = (uint(state.isInAirHistory) & 1u) != 0u && (uint(state.states) & uint(StateFlag.ST_SWIM)) == 0u

  //Events, add one-shot actions to Amortization
  let isJumping = (int(state.states) & int(StateFlag.ST_JUMP)) != 0
  var eventsSum = .0
  if isJumping
    eventsSum += heartrate__jumpHR * state.jumpSpeedMult
  if state |> human_phys_state_get_isClimbing
    eventsSum += heartrate__climbHR
  if state.heightCurVel > 0.01
    eventsSum += heartrate__standUpHR * state.heightCurVel * cmd.dt
  if !human_net_phys__isInAir && human_net_phys.phys.appliedCT.dodgeState != DodgeState.No
    eventsSum += heartrate__dodgeHR
  heartrate__amortization += eventsSum * currectMovementHRStaminaMult
  if curHP < prevHP
    heartrate__amortization += heartrate__damagedHR * (prevHP - curHP)

  // Apply Amortization
  let thisAmort = heartrate__amortization * heartrate__amortizationFractionPerSecond * cmd.dt
  heartrate__amortization -= thisAmort
  heartrate__debugInfoAmort.x = thisAmort

  //Calculate target HR from activity
  let vertSpeed = dot(state.vertDirection, state.velocity)
  let isMoving = ((human_ladder__attached && abs(vertSpeed) > 0.01) ||
                  (!human_ladder__attached && length_sq(state.velocity) > 0.02))
  var targetHeartrate = heartrate__range.x + thisAmort

  heartrate__debugInfoTarget.x = .0
  if isMoving
    var movementHR = .0
    if state.moveState == HUMoveState.EMS_SPRINT
      movementHR += heartrate__sprintHR
    else
      movementHR += heartrate__walkHR

    if !human_net_phys__isInAir
      if vertSpeed > .0
        movementHR += heartrate__elevationGainHR * vertSpeed * cmd.dt
      else
        let slope = -atan2(vertSpeed, length(state.velocity - state.vertDirection * vertSpeed)) * 2.0 / PI
        let multi = lerp(1.0, heartrate__downhillMulti, slope)
        movementHR *= multi

    movementHR *= currectMovementHRStaminaMult
    targetHeartrate += movementHR
    heartrate__debugInfoTarget.x = movementHR
  heartrate__debugInfoTarget.y = targetHeartrate

  //Stamina drain/restore
  heartrate__staminaRate = .0
  let curTime = float(cmd.tick) * human_net_phys.phys.timeStep
  let canRest = curTime - heartrate__lastHighActivityAt > heartrate__restCooldown
  if targetHeartrate >= heartrate__fatigueThreshold
    heartrate__lastHighActivityAt = curTime
    if heartrate__value >= heartrate__fatigueThreshold
      heartrate__staminaRate = -cvt(heartrate__value,
                                      heartrate__fatigueThreshold,
                                      heartrate__range.y,
                                      heartrate__staminaDrain.x,
                                      heartrate__staminaDrain.y)
  elif targetHeartrate >= heartrate__staminaRegenPeakHR && canRest
    heartrate__staminaRate = cvt(targetHeartrate,
                                  heartrate__staminaRegenPeakHR,
                                  heartrate__fatigueThreshold,
                                  heartrate__staminaRegen.y,
                                  heartrate__staminaRegen.z)
  elif canRest
    heartrate__staminaRate = cvt(targetHeartrate,
                                  heartrate__range.x,
                                  heartrate__staminaRegenPeakHR,
                                  heartrate__staminaRegen.x,
                                  heartrate__staminaRegen.y)
  let damagedStaminMulti = cvt(pow(curHP, heartrate__damagedStaminaPow),
                              pow(human_damage_model__sumMaxHpAllBodyParts, heartrate__damagedStaminaPow), .0,
                              1.0, heartrate__damagedStaminaMaxMulti)
  heartrate__staminaRate *= heartrate__staminaRate > 0.0 ? 1.0 / damagedStaminMulti : damagedStaminMulti
  heartrate__stamina += cmd.dt * heartrate__staminaRate
  heartrate__stamina = clamp(heartrate__stamina, .0, heartrate__maxStamina)

  // Fatigue HR
  let missingStamina = heartrate__maxStamina - heartrate__stamina
  let maxHRFromFatigue = (heartrate__range.y - heartrate__range.x) * heartrate__fatigueHRRatio
  let fatigueHR = cvt(pow(missingStamina, heartrate__fatigueHRPow),
                      .0, pow(heartrate__maxStamina, heartrate__fatigueHRPow),
                      .0, maxHRFromFatigue)
  targetHeartrate += fatigueHR
  heartrate__debugInfoTarget.z = fatigueHR

  // Handle overflow
  heartrate__debugInfoAmort.y = .0
  if targetHeartrate > heartrate__range.y
    let overflowCarryOver = heartrate__overflowHRToAmortizationRatio * (targetHeartrate - heartrate__range.y)
    heartrate__amortization += heartrate__overflowHRToAmortizationRatio * (targetHeartrate - heartrate__range.y)
    targetHeartrate = heartrate__range.y
    heartrate__debugInfoAmort.y = overflowCarryOver
  targetHeartrate = clamp(targetHeartrate, heartrate__range.x, heartrate__range.y)

  //Set heart rate
  heartrate__debugInfoTarget.w = targetHeartrate
  if targetHeartrate > heartrate__value
    heartrate__value = approach(heartrate__value, targetHeartrate, cmd.dt * heartrate__riseSpeedMulti, heartrate__riseTau)
  else
    heartrate__value = approach(heartrate__value, targetHeartrate, cmd.dt * heartrate__fallSpeedMulti, heartrate__fallTau)
    heartrate__value -= cmd.dt * cvt(heartrate__stamina,
                                    .0,
                                    heartrate__maxStamina,
                                    heartrate__normalizationSpeed.y,
                                    heartrate__normalizationSpeed.x)
  heartrate__value = clamp(heartrate__value, heartrate__range.x, heartrate__range.y)

  //Effects caused by heartrate
  //Assumes it's the first ES modifing these multipliers
  state.sprintSpeedMult = cvt(pow(heartrate__value, heartrate__sprintPow),
                              pow(max(heartrate__fatigueThreshold, heartrate__range.x + heartrate__sprintHR), heartrate__sprintPow),
                              pow(heartrate__range.y, heartrate__sprintPow),
                              heartrate__sprintMult.x,
                              heartrate__sprintMult.y)
  human_hand_stamina__HRMult = cvt(heartrate__value,
                                   heartrate__fatigueThreshold,
                                   heartrate__range.y,
                                   heartrate__handStaminaMult.x,
                                   heartrate__handStaminaMult.y)
  state.climbingSpeedMult = cvt(heartrate__value,
                                heartrate__fatigueThreshold,
                                heartrate__range.y,
                                heartrate__climbSpeedMult.x,
                                heartrate__climbSpeedMult.y)
  let isTransitingToCrawl = state.height < 0.f
  state.fasterChangePoseMult = cvt(heartrate__value,
                                heartrate__fatigueThreshold,
                                heartrate__range.y,
                                heartrate__changePos.x,
                                heartrate__changePos.y) * (isTransitingToCrawl ? 1.f : entity_mods__changePosModsMulti)
  human_hold_breath__holdBreathDrain = cvt(heartrate__value,
                                            heartrate__fatigueThreshold,
                                            heartrate__range.y,
                                            heartrate__holdBreathDrain.x,
                                            heartrate__holdBreathDrain.y)
  human_hold_breath__restoreBreath = cvt(heartrate__value,
                                            heartrate__fatigueThreshold,
                                            heartrate__range.y,
                                            heartrate__restoreBreath.x,
                                            heartrate__restoreBreath.y)
  human_breath__recoverBreathMult = cvt(heartrate__value,
                                        heartrate__fatigueThreshold,
                                        heartrate__range.y,
                                        heartrate__recoverBreath.x,
                                        heartrate__recoverBreath.y)
  human_dodge__dodgeSpdMulti = cvt(heartrate__value,
                                    heartrate__fatigueThreshold,
                                    heartrate__range.y,
                                    heartrate__dodgeMulti.x,
                                    heartrate__dodgeMulti.y)


[es(tag=netClient, REQUIRE=watchedByPlr, after=after_entity_mods_apply_sync_point)]
def hearbeat_mod_jumpspeed_server(info : UpdateStageInfoAct;
                                  heartrate__value : float;
                                  heartrate__fatigueThreshold : float;
                                  heartrate__range : float2;
                                  heartrate__jumpSpeed : float2;
                                  var human_net_phys : HumanActor)
  assume state = human_net_phys.phys.currentState
  state.jumpSpeedMult *= cvt(heartrate__value,
                                heartrate__fatigueThreshold,
                                heartrate__range.y,
                                heartrate__jumpSpeed.x,
                                heartrate__jumpSpeed.y)


[es(tag=server, after=after_entity_mods_apply_sync_point)]
def hearbeat_mod_jumpspeed_client(info : UpdateStageInfoAct;
                                  heartrate__value : float;
                                  heartrate__fatigueThreshold : float;
                                  heartrate__range : float2;
                                  heartrate__jumpSpeed : float2;
                                  var human_net_phys : HumanActor)
  assume state = human_net_phys.phys.currentState
  state.jumpSpeedMult *= cvt(heartrate__value,
                                heartrate__fatigueThreshold,
                                heartrate__range.y,
                                heartrate__jumpSpeed.x,
                                heartrate__jumpSpeed.y)


[es(tag=server, after=hearbeat_es)]
def send_changed_hp_to_client(cmd : CmdPostPhysUpdate;
                              eid : EntityId;
                              possessedByPlr : EntityId;
                              human_damage_model__sumHpAllBodyParts : float;
                              heartrate__hpDelayTicks : int;
                              var heartrate__lastHp : float&)
  if human_damage_model__sumHpAllBodyParts != heartrate__lastHp
    heartrate__lastHp = human_damage_model__sumHpAllBodyParts
    send_net_event(eid, EventHeartRateHpChange(tick = cmd.tick + heartrate__hpDelayTicks, hp = heartrate__lastHp), possessed_and_spectated_player(possessedByPlr))


[soa_es, es]
def store_changed_hp_for_hr(evt : EventHeartRateHpChange; var hpinfo : HeartrateTrackedHP_SOA)
  hpinfo |> push(HeartrateTrackedHP(heartrate__hpinfo__tick = evt.tick, heartrate__hpinfo__hp = evt.hp))

[soa_es, es(on_appear, after=damage_model_calculate_hp_of_all_body_parts)]
def init_hr_hp_tracking(evt : Event;
                        human_damage_model__sumHpAllBodyParts : float;
                        var heartrate__lastHp : float&;
                        var heartrate__lastTrackedHp : float&;
                        var hpinfo : HeartrateTrackedHP_SOA)
  hpinfo |> push(HeartrateTrackedHP(heartrate__hpinfo__tick = 0, heartrate__hpinfo__hp = human_damage_model__sumHpAllBodyParts))
  heartrate__lastHp = human_damage_model__sumHpAllBodyParts
  heartrate__lastTrackedHp = human_damage_model__sumHpAllBodyParts


[soa_def]
def calc_relevant_hr_hp(tick, max_history : int; var hpinfo : HeartrateTrackedHP_SOA)
  var lastHp, curHp : float
  var firstPreservedIdx = -1
  for idx, v in iter_range(hpinfo), hpinfo
    if v.heartrate__hpinfo__tick < tick - max_history
      firstPreservedIdx = idx
    if v.heartrate__hpinfo__tick < tick
      curHp = v.heartrate__hpinfo__hp
      lastHp = curHp
    elif v.heartrate__hpinfo__tick == tick
      curHp = v.heartrate__hpinfo__hp
    elif v.heartrate__hpinfo__tick > tick
      break
  if firstPreservedIdx > 0 //Leave what's within history range + one more
    hpinfo |> erase(0, firstPreservedIdx)
  return lastHp, curHp


[es(on_appear, on_event=EventOnModsChanged, after=entity_mod_effect_calc)]
def init_values_based_on_modes(evt : Event;
                               entity_mod_values : Object;
                               heartrate__riseSpeedMultiDefault : float;
                               heartrate__fallSpeedMultiDefault : float;
                               heartrate__normalizationSpeedDefault : float2;
                               heartrate__movementHRStaminaMultDefault : float2;
                               heartrate__fatigueThresholdDefault : float;
                               heartrate__staminaRegenDefault : float3;
                               heartrate__staminaDrainDefault : float2;
                               var heartrate__riseSpeedMulti : float&;
                               var heartrate__fallSpeedMulti : float&;
                               var heartrate__normalizationSpeed : float2&;
                               var heartrate__movementHRStaminaMult : float2&;
                               var heartrate__fatigueThreshold : float&;
                               var heartrate__staminaRegen : float3&;
                               var heartrate__staminaDrain : float2&)
  heartrate__riseSpeedMulti = heartrate__riseSpeedMultiDefault * get_mod_value("hrRiseSpeedMulti", entity_mod_values, 1.0)
  heartrate__fallSpeedMulti = heartrate__fallSpeedMultiDefault * get_mod_value("hrFallSpeedMulti", entity_mod_values, 1.0)
  heartrate__normalizationSpeed = heartrate__normalizationSpeedDefault * get_mod_value("hrFallSpeedMulti", entity_mod_values, 1.0)
  heartrate__movementHRStaminaMult = heartrate__movementHRStaminaMultDefault * get_mod_value("hrActivityMulti", entity_mod_values, 1.0)
  heartrate__staminaRegen = heartrate__staminaRegenDefault * get_mod_value("hrStaminaRegenMulti", entity_mod_values, 1.0)
  heartrate__staminaDrain = heartrate__staminaDrainDefault * get_mod_value("hrStaminaDrainMulti", entity_mod_values, 1.0)
  heartrate__fatigueThreshold = heartrate__fatigueThresholdDefault + get_mod_value("hrFatigueThresholdAdd", entity_mod_values, 0.0)


[es(on_appear, REQUIRE=oneshot_set_pulse_effect)]
def oneshot_set_pulse_effect(evt : Event;
                             game_effect__attachedTo : EntityId;
                             oneshot_set_pulse_effect__stamina : float const?;
                             oneshot_set_pulse_effect__pulse : float const?)
  query(game_effect__attachedTo) <| $ [es] (var heartrate__value : float&; var heartrate__stamina : float&)
    if oneshot_set_pulse_effect__pulse != null
      heartrate__value = *oneshot_set_pulse_effect__pulse
    if oneshot_set_pulse_effect__stamina != null
      heartrate__stamina = *oneshot_set_pulse_effect__stamina

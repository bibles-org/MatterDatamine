require ecs
require DngHuman
require game.events.events

[es(REQUIRE_NOT=disableUpdate)]
def human_weapon_hold_breath(evt : CmdPostPhysUpdate;
                             human_hold_breath__startLevel : float = 0.3;
                             human_hold_breath__holdBreathDrain : float = 0.22;
                             human_hold_breath__restoreBreath : float = 0.13;
                             isDowned : bool = false;
                             var human_net_phys : HumanActor&)
  assume currentState = human_net_phys.phys.currentState
  assume appliedCT = human_net_phys.phys.appliedCT
  let stoppedHoldBreath = (currentState.breathShortness >= 1.0
    || (!is_hold_breath(currentState) && currentState.breathShortness > 1.0 - human_hold_breath__startLevel))
  let isAiming = (human_phys_state_can_aim(currentState)
    && is_control_bit_set(appliedCT, HumanPhysControlType.HCT_AIM)
    && currentState.weapEquipState.curState != HUWeaponEquipState.EES_DOWN
    && !human_phys_state_get_isClimbing(currentState)
    && !isDowned)
  currentState |> set_is_hold_breath(appliedCT |> is_control_bit_set(HumanPhysControlType.HCT_SPRINT) && isAiming && !stoppedHoldBreath)
  if is_hold_breath(currentState)
    currentState.breathShortness += evt.dt * human_hold_breath__holdBreathDrain
  else
    currentState.breathShortness -= evt.dt * human_hold_breath__restoreBreath

  currentState.breathShortness = saturate(currentState.breathShortness)

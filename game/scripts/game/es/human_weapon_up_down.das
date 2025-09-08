require ecs
require DngHuman
require game.events.events


[es(REQUIRE_NOT=disableUpdate)]
def human_weapon_up_down_phys(evt : CmdPostPhysUpdate;
                              human_weap__forceUpDownWeaponState : int;
                              var human_net_phys : HumanActor&)
  if human_weap__forceUpDownWeaponState == 0
    human_phys_state_set_forceWeaponUp(human_net_phys.phys.currentState, true)
  elif human_weap__forceUpDownWeaponState == 1
    human_phys_state_set_forceWeaponDown(human_net_phys.phys.currentState, true)


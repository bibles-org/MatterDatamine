require ecs
require DngHuman
require HumanPhys
require DagorInput
require game.events.input_events


def init(var human_weap_input__forceUpDownWeapon : int&)
  human_weap_input__forceUpDownWeapon = int(get_action_handle("Human.HoldUpWeapon", TYPEGRP_DIGITAL))


def reset(var human_weap_input__forceUpDownWeapon : int&)
  human_weap_input__forceUpDownWeapon = int(BAD_ACTION_HANDLE)


[es(tag=input, on_appear)]
def human_weapon_up_down_appear(evt : Event; var human_weap_input__forceUpDownWeapon : int&)
  init(human_weap_input__forceUpDownWeapon)


[es(tag=input, on_disappear)]
def human_weapon_up_down_disappear(evt : Event; var human_weap_input__forceUpDownWeapon : int&)
  reset(human_weap_input__forceUpDownWeapon)


[es(tag=input)]
def human_weapon_up_down_init_reset(evt : EventDaInputInit; var human_weap_input__forceUpDownWeapon : int&)
  if evt.init
    init(human_weap_input__forceUpDownWeapon)
  else
    reset(human_weap_input__forceUpDownWeapon)


[es(tag=input)]
def human_weapon_up_down_input_triggered(evt : EventDaInputActionTriggered;
                                         input__enabled : bool;
                                         human_weap_input__forceUpDownWeapon : int;
                                         var human_weap__forceUpDownWeaponState : int&)
  if input__enabled && int(evt.action) == human_weap_input__forceUpDownWeapon
    human_weap__forceUpDownWeaponState = (human_weap__forceUpDownWeaponState + 1) % 2

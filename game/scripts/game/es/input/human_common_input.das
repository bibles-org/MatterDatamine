require ecs
require app
require math.base
require game.events.events
require game.events.input_events
require game.es.input.input_common
require DagorInput
require HumanPhys
require DngHuman
require DagorSystem
require game.es.action_common
require game.es.render.camera_shaker_common
require game.events.events_game
require game.es.states_common
require DngNet
require game.events.events_active_matter


def init(var human_input__jump : int&;
         var human_input__crawl : int&;
         var human_input__crouch : int&;
         var human_input__sneak : int&;
         var human_input__holdCrouch : int&;
         var human_input__melee : int&;
         var human_input__reload : int&;
         var human_input__checkAmmo : int&;
         var human_input__recover : int&;
         var human_input__putOutFire : int&;
         var human_input__fastHeal : int&)
  human_input__jump = int(get_action_handle("Human.Jump", TYPEGRP_DIGITAL))
  human_input__crawl = int(get_action_handle("Human.Crawl", TYPEGRP_DIGITAL))
  human_input__crouch = int(get_action_handle("Human.Crouch", TYPEGRP_DIGITAL))
  human_input__sneak = int(get_action_handle("Human.Sneak", TYPEGRP_DIGITAL))
  human_input__holdCrouch = int(get_action_handle("Human.HoldCrouch", TYPEGRP_DIGITAL))
  human_input__melee = int(get_action_handle("Human.Melee", TYPEGRP_DIGITAL))
  human_input__reload = int(get_action_handle("Human.Reload", TYPEGRP_DIGITAL))
  human_input__checkAmmo = int(get_action_handle("Human.CheckAmmo", TYPEGRP_DIGITAL))
  human_input__recover = int(get_action_handle("Human.Recover", TYPEGRP_DIGITAL))
  human_input__putOutFire = int(get_action_handle("Human.PutOutFire", TYPEGRP_DIGITAL))
  human_input__fastHeal = int(get_action_handle("Human.FastHeal", TYPEGRP_DIGITAL))


def reset(var human_input__jump : int&;
          var human_input__crawl : int&;
          var human_input__crouch : int&;
          var human_input__sneak : int&;
          var human_input__holdCrouch : int&;
          var human_input__melee : int&;
          var human_input__reload : int&;
          var human_input__checkAmmo : int&;
          var human_input__recover : int&;
          var human_input__putOutFire : int&;
          var human_input__fastHeal : int&)
  human_input__jump = int(BAD_ACTION_HANDLE)
  human_input__crawl = int(BAD_ACTION_HANDLE)
  human_input__crouch = int(BAD_ACTION_HANDLE)
  human_input__sneak = int(BAD_ACTION_HANDLE)
  human_input__holdCrouch = int(BAD_ACTION_HANDLE)
  human_input__melee = int(BAD_ACTION_HANDLE)
  human_input__reload = int(BAD_ACTION_HANDLE)
  human_input__checkAmmo = int(BAD_ACTION_HANDLE)
  human_input__recover = int(BAD_ACTION_HANDLE)
  human_input__putOutFire = int(BAD_ACTION_HANDLE)
  human_input__fastHeal = int(BAD_ACTION_HANDLE)


[es(tag=input, on_appear)]
def human_common_appear_es(evt : Event;
                           var human_input__jump : int&;
                           var human_input__crawl : int&;
                           var human_input__crouch : int&;
                           var human_input__sneak : int&;
                           var human_input__holdCrouch : int&;
                           var human_input__melee : int&;
                           var human_input__reload : int&;
                           var human_input__checkAmmo : int&;
                           var human_input__recover : int&;
                           var human_input__putOutFire : int&;
                           var human_input__fastHeal : int&)
  init(human_input__jump, human_input__crawl, human_input__crouch, human_input__sneak,
       human_input__holdCrouch, human_input__melee, human_input__reload, human_input__checkAmmo, human_input__recover,
       human_input__putOutFire, human_input__fastHeal)

[es(tag=input)]
def human_common_input_es(evt : EventDaInputInit;
                          var human_input__jump : int&;
                          var human_input__crawl : int&;
                          var human_input__crouch : int&;
                          var human_input__sneak : int&;
                          var human_input__holdCrouch : int&;
                          var human_input__melee : int&;
                          var human_input__reload : int&;
                          var human_input__checkAmmo : int&;
                          var human_input__recover : int&;
                          var human_input__standState : int&;
                          var human_input__putOutFire : int&;
                          var human_input__fastHeal : int&)
  if evt.init
    init(human_input__jump, human_input__crawl, human_input__crouch, human_input__sneak, human_input__holdCrouch,
         human_input__melee, human_input__reload, human_input__checkAmmo, human_input__recover, human_input__putOutFire,
         human_input__fastHeal)
  else
    reset(human_input__jump, human_input__crawl, human_input__crouch, human_input__sneak, human_input__holdCrouch,
          human_input__melee, human_input__reload, human_input__checkAmmo, human_input__recover, human_input__putOutFire,
          human_input__fastHeal)
    human_input__standState = 0

[es(tag=input)]
def human_common_input_entity_reset_es(evt : EventOnEntityReset;
                                       human_input__jump : int;
                                       human_input__crawl : int;
                                       human_input__crouch : int;
                                       human_input__holdCrouch : int;
                                       human_input__melee : int;
                                       var human_net_phys : HumanActor&)
  assume ct = human_net_phys.phys.producedCT
  set_controlbit_touch(HumanPhysControlType.HCT_JUMP, uint16(human_input__jump), ct)
  set_controlbit(HumanPhysControlType.HCT_CRAWL, uint16(human_input__crawl), ct)
  set_controlbit(HumanPhysControlType.HCT_CROUCH, uint16(human_input__crouch), ct)
  set_controlbit(HumanPhysControlType.HCT_CROUCH, uint16(human_input__holdCrouch), ct)
  set_controlbit(HumanPhysControlType.HCT_MELEE, uint16(human_input__melee), ct)

[es(tag=gameClient, REQUIRE=human_state__forceStandUp, no_order)]
def human_input_force_stand_up_es(info : UpdateStageUpdateInput; game_effect__attachedTo : EntityId)
  ecs::query(game_effect__attachedTo) <| $ [es] (var human_input__standState : int&)
    human_input__standState = 0

[es(tag=input)]
def human_common_input_action_triggered_es(evt : EventDaInputActionTriggered;
                                           eid : EntityId;
                                           human_input__jump : int;
                                           human_input__crawl : int;
                                           human_input__crouch : int;
                                           human_input__holdCrouch : int;
                                           human_input__melee : int;
                                           var human_input__wishMelee : bool&;
                                           human_input__reload : int;
                                           human_input__recover : int;
                                           human_input__putOutFire : int;
                                           input__enabled : bool;
                                           var human_net_phys : HumanActor&;
                                           var human_input__standState : int&;
                                           var human_input__reloadAtTick : int&;
                                           jetpack__enabled : bool = false;
                                           isInVehicle : bool = false;
                                           burning__isBurning : bool = false)
  assume ct = human_net_phys.phys.producedCT
  let atTime = get_sync_time()
  let action = int(evt.action)
  if !input__enabled
    return
  if action == human_input__jump
    if human_net_phys.phys.canJump || jetpack__enabled
      ct |> human_control_state_set_control_bit(HumanPhysControlType.HCT_JUMP, true)
      human_input__standState = 0
  elif action == human_input__melee
    if !is_control_bit_set(ct, HumanPhysControlType.HCT_THROW_BACK)
      human_input__wishMelee = true
  elif action == human_input__crawl
    if !isInVehicle && human_net_phys.phys |> human_phys_isGoProneAllowed()
      human_input__standState = human_input__standState == int(HumanPhysControlType.HCT_CRAWL) ? 0 : int(HumanPhysControlType.HCT_CRAWL)
  elif action == human_input__crouch
    if !isInVehicle
      human_input__standState = human_input__standState == int(HumanPhysControlType.HCT_CROUCH) ? 0 : int(HumanPhysControlType.HCT_CROUCH)
  elif action == human_input__holdCrouch
    if !isInVehicle
      human_input__standState = int(HumanPhysControlType.HCT_CROUCH)
  elif action == human_input__reload
    ct |> human_control_state_set_control_bit(HumanPhysControlType.HCT_RELOAD, true)
    human_input__reloadAtTick = ct.producedAtTick
  elif action == human_input__recover
    if !burning__isBurning && check_action_precondition(eid, "recover")
      run_action(eid, "recover")
  elif action == human_input__putOutFire && burning__isBurning
    send_net_event(eid, CmdPutOutFireStart())


[es(tag=input, after=human_weap_update_es)]
def human_input_reset_request_reload(evt : ParallelUpdateFrameDelayed;
                                     human_input__reloadAtTick : int;
                                     var human_net_phys : HumanActor&)
  assume ct = human_net_phys.phys.producedCT
  if human_input__reloadAtTick < ct.producedAtTick
    ct |> human_control_state_set_control_bit(HumanPhysControlType.HCT_RELOAD, false)


[es(tag=input, no_order)]
def human_input_reset_crawling(evt : ParallelUpdateFrameDelayed;
                               human_net_phys : HumanActor;
                               var human_input__standState : int&)
  let isProneAllowed = human_net_phys.phys |> human_phys_isGoProneAllowed()
  if !isProneAllowed && human_input__standState == int(HumanPhysControlType.HCT_CRAWL)
    human_input__standState = 0


[es(tag=input)]
def human_input_on_reload_interrupt(evt : CmdInterruptReloadImmediately;
                                    var human_net_phys : HumanActor&)
  assume ct = human_net_phys.phys.producedCT
  ct |> human_control_state_set_control_bit(HumanPhysControlType.HCT_RELOAD, false)


[es(tag=input)]
def human_input_punch_camera_on_jump(evt : EventDaInputActionTriggered;
                                     state_counter__cameraPunchOnJump : int;
                                     human_input__jump : int)
  if int(evt.action) == human_input__jump && has_state_by_counter(state_counter__cameraPunchOnJump)
    add_punch_by_dir(float3(10.0, 0.0, 0.0))

[es(tag=input, after=human_weap_post_phys_es)]
def reset_melee_action_es(evt : CmdPostPhysUpdate;
                          var human_input__wishMelee : bool&)
  human_input__wishMelee = false

[es(tag=input)]
def human_common_input_action_terminated_es(evt : EventDaInputActionTerminated;
                                            human_input__holdCrouch : int;
                                            input__enabled : bool;
                                            var human_input__standState : int&;
                                            isInVehicle : bool = false)
  let action = int(evt.action)
  if !input__enabled
    return
  if action == human_input__holdCrouch
    if !isInVehicle
      human_input__standState = 0

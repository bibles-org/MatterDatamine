// require ecs
// require HumanPhys
// require DagorInput
// require DngHuman
// require game.events.events
// require game.events.input_events
// require game.events.events_active_matter
// require game.es.render.camera_shaker_common


// def init(var human_input__dodgeLeft : int&;
//          var human_input__dodgeRight : int&;
//          var human_input__dodgeBack : int&)
//   human_input__dodgeLeft = int(get_action_handle("Human.DodgeLeft", TYPEGRP_DIGITAL))
//   human_input__dodgeRight = int(get_action_handle("Human.DodgeRight", TYPEGRP_DIGITAL))
//   human_input__dodgeBack = int(get_action_handle("Human.DodgeBack", TYPEGRP_DIGITAL))


// def reset(var human_input__dodgeLeft : int&;
//           var human_input__dodgeRight : int&;
//           var human_input__dodgeBack : int&)
//   human_input__dodgeLeft = int(BAD_ACTION_HANDLE)
//   human_input__dodgeRight = int(BAD_ACTION_HANDLE)
//   human_input__dodgeBack = int(BAD_ACTION_HANDLE)


// [es(tag=input, on_appear, REQUIRE=human_input)]
// def human_input_dodge_appear(evt : Event;
//                              var human_input__dodgeLeft : int&;
//                              var human_input__dodgeRight : int&;
//                              var human_input__dodgeBack : int&)
//   init(human_input__dodgeLeft, human_input__dodgeRight, human_input__dodgeBack)


// [es(tag=input, on_disappear, REQUIRE=human_input)]
// def human_input_dodge_destroyed(evt : Event;
//                                 var human_input__dodgeLeft : int&;
//                                 var human_input__dodgeRight : int&;
//                                 var human_input__dodgeBack : int&)
//   reset(human_input__dodgeLeft, human_input__dodgeRight, human_input__dodgeBack)


// [es(tag=input, REQUIRE=human_input)]
// def human_input_dodge_init(evt : EventDaInputInit;
//                            input__enabled : bool;
//                            var human_input__dodgeLeft : int&;
//                            var human_input__dodgeRight : int&;
//                            var human_input__dodgeBack : int&)
//   if !input__enabled
//     return
//   if evt.init
//     init(human_input__dodgeLeft, human_input__dodgeRight, human_input__dodgeBack)
//   else
//     reset(human_input__dodgeLeft, human_input__dodgeRight, human_input__dodgeBack)


// def do_dodge(eid : EntityId; var ct : HumanControlState&; var is_dodging : bool&; direction : DodgeState)
//   is_dodging = true
//   createEntity("human_dodge_effect") <| $(var init)
//     init |> set("game_effect__attachedTo", eid)
//   ct |> human_control_state_set_control_bit(HumanPhysControlType HCT_JUMP, false)
//   ct |> human_control_state_set_dodge_state(direction)


// [es(tag=input, REQUIRE_NOT=deadEntity, after=after_input_sync)]
// def human_input_dodge_input(evt : EventDaInputActionTriggered;
//                             eid : EntityId;
//                             input__enabled, human_net_phys__isInAir : bool;
//                             human_input__dodgeLeft : int;
//                             human_input__dodgeRight : int;
//                             human_input__dodgeBack : int;
//                             human_net_phys__standState : int;
//                             human_net_phys__curMoveState : int;
//                             var human_dodge__isDodging : bool&;
//                             var human_net_phys : HumanActor&;
//                             human_dodge__cameraShakeAngle = 10.0)
//   assume ct = human_net_phys.phys.producedCT
//   assume currentState = human_net_phys.phys.currentState
//   let rightStandState = human_net_phys__standState == int(HUMoveState EMS_STAND)
//   let isInSprint = human_net_phys__curMoveState == int(HUMoveState EMS_SPRINT)
//   if input__enabled && rightStandState && !human_net_phys__isInAir && !isInSprint
//     if human_dodge__isDodging
//       ct |> human_control_state_set_control_bit(HumanPhysControlType HCT_JUMP, false)
//     elif int(evt.action) == human_input__dodgeLeft
//       do_dodge(eid, ct, human_dodge__isDodging, DodgeState Left)
//     elif int(evt.action) == human_input__dodgeRight
//       do_dodge(eid, ct, human_dodge__isDodging, DodgeState Right)
//     elif int(evt.action) == human_input__dodgeBack
//       do_dodge(eid, ct, human_dodge__isDodging, DodgeState Back)
//       add_punch(float3(-human_dodge__cameraShakeAngle, 0.0, 0.0))


// def is_action_active_and_pressed(action_id : int)
//   return is_action_active(uint16(action_id)) && get_digital_action_state(uint16(action_id)).bState


// [es(tag=input, REQUIRE_NOT=deadEntity, after=human_input_es)]
// def human_input_dodge_update(act : UpdateStageUpdateInput;
//                              human_input__dodgeLeft : int;
//                              human_input__dodgeRight : int;
//                              human_input__dodgeBack : int;
//                              human_input__jump : int;
//                              human_net_phys__curMoveState : int;
//                              human_net_phys__isInAir, human_dodge__isDodging : bool;
//                              var human_net_phys : HumanActor&)
//   if is_action_active_and_pressed(human_input__jump) && !human_net_phys__isInAir
//     let isInSprint = human_net_phys__curMoveState == int(HUMoveState EMS_SPRINT)
//     var activeDodge = false
//     activeDodge ||= human_dodge__isDodging
//     activeDodge ||= is_action_active_and_pressed(human_input__dodgeLeft) && !isInSprint
//     activeDodge ||= is_action_active_and_pressed(human_input__dodgeRight) && !isInSprint
//     activeDodge ||= is_action_active_and_pressed(human_input__dodgeBack)
//     if activeDodge
//       human_net_phys.phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType HCT_JUMP, false)


// [es(tag=gameClient, REQUIRE=human_dodge_effect, on_disappear)]
// def human_input_dodge_jump_block_end(evt : Event;
//                                      game_effect__attachedTo : EntityId)
//   query(game_effect__attachedTo) <| $ [es] (var human_dodge__isDodging : bool&)
//     human_dodge__isDodging = false

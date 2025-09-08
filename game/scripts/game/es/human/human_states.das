require ecs
require game.es.states_common
require DngHuman
require DngWeapon
require app


[es(on_appear, REQUIRE=state__disableJump)]
def disable_jump_appear(evt : Event;
                        game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var state_counter__disableJump : int&;
                                            var human_net_phys : HumanActor)
    state_counter__disableJump += 1
    human_net_phys.phys.canJump = false


[es(on_disappear, REQUIRE=state__disableJump)]
def disable_jump_disappear(evt : Event;
                           game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var state_counter__disableJump : int&;
                                            var human_net_phys : HumanActor)
    state_counter__disableJump -= 1
    if !has_state_by_counter(state_counter__disableJump)
      human_net_phys.phys.canJump = true


[es(on_appear, REQUIRE=state__disableWeaponSwitch)]
def disable_weapon_switch_appear(evt : Event;
                                 game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (human_weap__gunEids : EidList;
                                            var state_counter__disableWeaponSwitch : int&;
                                            var human_net_phys : HumanActor)
    state_counter__disableWeaponSwitch += 1
    let couldSwitch = human_net_phys.phys.canSwitchWeapon
    human_net_phys.phys.canSwitchWeapon = false
    if couldSwitch
      let slot = determine_current_weapon_slot(get_sync_time(), human_net_phys)
      forcibly_lock_weap_slot(game_effect__attachedTo, int(slot), human_weap__gunEids, human_net_phys)


[es(on_disappear, REQUIRE=state__disableWeaponSwitch)]
def disable_weapon_switch_disappear(evt : Event;
                                    game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var state_counter__disableWeaponSwitch : int&;
                                            var human_net_phys : HumanActor)
    state_counter__disableWeaponSwitch -= 1
    if !has_state_by_counter(state_counter__disableWeaponSwitch)
      human_net_phys.phys.canSwitchWeapon = true


[es(on_appear, REQUIRE=state__cameraPunchOnJump)]
def camera_punch_on_jump_appear(evt : Event;
                                game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var state_counter__cameraPunchOnJump : int&)
    state_counter__cameraPunchOnJump += 1


[es(on_disappear, REQUIRE=state__cameraPunchOnJump)]
def camera_punch_on_jump_disappear(evt : Event;
                                   game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var state_counter__cameraPunchOnJump : int&)
    state_counter__cameraPunchOnJump -= 1


[es(on_appear, REQUIRE=state__collisionDmgImmunity)]
def collision_immunity_appear(evt : Event;
                              game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var state_counter__collisionDmgImmunity : int&;
                                            var entity_mods__lessCollDmgMult : float&)
    state_counter__collisionDmgImmunity += 1
    entity_mods__lessCollDmgMult = 0.0f


[es(on_disappear, REQUIRE=state__collisionDmgImmunity)]
def collision_immunity_disappear(evt : Event;
                                 game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var state_counter__collisionDmgImmunity : int&;
                                            var entity_mods__lessCollDmgMult : float&;
                                            human_net_phys__isInAir : bool)
    state_counter__collisionDmgImmunity -= 1
    if !human_net_phys__isInAir && !has_state_by_counter(state_counter__collisionDmgImmunity)
      entity_mods__lessCollDmgMult = 1.0f


[es(track=human_net_phys__isInAir)]
def disable_collision_immunity(evt : Event;
                               human_net_phys__isInAir : bool;
                               state_counter__collisionDmgImmunity : int&;
                               var entity_mods__lessCollDmgMult : float&)
  if !has_state_by_counter(state_counter__collisionDmgImmunity) && !human_net_phys__isInAir
    entity_mods__lessCollDmgMult = 1.0f


[es(on_appear, REQUIRE=state__disableUseItems)]
def disable_use_items_appear(evt : Event;
                             game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var state_counter__disableUseItems : int&)
    state_counter__disableUseItems += 1


[es(on_disappear, REQUIRE=state__disableUseItems)]
def disable_use_items_disappear(evt : Event;
                                game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var state_counter__disableUseItems : int&)
    state_counter__disableUseItems -= 1


[es(track=(state_counter__disableUseItems, human_ladder__attached))]
def disable_use_items_track(evt : Event;
                            state_counter__disableUseItems : int;
                            human_ladder__attached : bool;
                            var human_inventory__canUseItems : bool&)
  human_inventory__canUseItems = !has_state_by_counter(state_counter__disableUseItems) && !human_ladder__attached


[es(on_appear, REQUIRE=state__lockMove)]
def lock_move_appear(evt : Event;
                     game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var state_counter__lockMove : int&;
                                            var human_net_phys : HumanActor)
    state_counter__lockMove++
    human_net_phys.phys.canMove = false


[es(on_disappear, REQUIRE=state__lockMove)]
def lock_move_disappear(evt : Event;
                        game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var state_counter__lockMove : int&;
                                            var human_net_phys : HumanActor)
    state_counter__lockMove--
    if !has_state_by_counter(state_counter__lockMove)
      human_net_phys.phys.canMove = true


[es(on_appear, REQUIRE=state__disableAmGather)]
def disable_am_gather_appear(evt : Event;
                             game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var state_counter__disableAmGather : int&;
                                            var resources_gatherer_hero__enabled : bool&)
    state_counter__disableAmGather += 1
    resources_gatherer_hero__enabled = !has_state_by_counter(state_counter__disableAmGather)


[es(on_disappear, REQUIRE=state__disableAmGather)]
def disable_am_gather_disappear(evt : Event;
                                game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var state_counter__disableAmGather : int&;
                                            var resources_gatherer_hero__enabled : bool&)
    state_counter__disableAmGather -= 1
    resources_gatherer_hero__enabled = !has_state_by_counter(state_counter__disableAmGather)


[es(on_appear, REQUIRE=state__disableStoneThrow)]
def disable_throw_stone_appear(evt : Event;
                               game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var human_stone_throw__lockThrow : int&;
                                            var human_stone_throw__enabled : bool&)
    human_stone_throw__lockThrow += 1
    human_stone_throw__enabled = !has_state_by_counter(human_stone_throw__lockThrow)


[es(on_disappear, REQUIRE=state__disableUseAbilities)]
def lock_use_ability_disappear(evt : Event;
                               game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var hero_ability__lockAbilityUse : int&;
                                            var hero_ability__disabledIndefinitely : bool&)
    hero_ability__lockAbilityUse -= 1
    hero_ability__disabledIndefinitely = has_state_by_counter(hero_ability__lockAbilityUse)


[es(on_appear, REQUIRE=state__disableUseAbilities)]
def lock_use_ability_appear(evt : Event;
                            game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var hero_ability__lockAbilityUse : int&;
                                            var hero_ability__disabledIndefinitely : bool&)
    hero_ability__lockAbilityUse += 1
    hero_ability__disabledIndefinitely = has_state_by_counter(hero_ability__lockAbilityUse)


[es(on_disappear, REQUIRE=state__disableStoneThrow)]
def disable_throw_stone_disappear(evt : Event;
                                  game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var human_stone_throw__lockThrow : int&;
                                            var human_stone_throw__enabled : bool&)
    human_stone_throw__lockThrow -= 1
    human_stone_throw__enabled = !has_state_by_counter(human_stone_throw__lockThrow)


[es(on_appear, REQUIRE=watchedByPlr)]
def disable_throw_stone_appear_human_entity(evt : Event;
                                            eid aka human_eid : EntityId;
                                            var human_stone_throw__lockThrow : int&;
                                            var human_stone_throw__enabled : bool&)
  query() <| $ [es(REQUIRE=state__disableStoneThrow)] (game_effect__attachedTo : EntityId)
    if game_effect__attachedTo == human_eid
      human_stone_throw__lockThrow += 1
  human_stone_throw__enabled = !has_state_by_counter(human_stone_throw__lockThrow)


[es(on_appear, REQUIRE=state__disableUseContainers)]
def disable_use_containers_appear(evt : Event;
                                  game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var state_counter__disableUseContainers : int&)
    state_counter__disableUseContainers += 1

[es(on_disappear, REQUIRE=state__disableUseContainers)]
def disable_use_containers_disappear(evt : Event;
                                     game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var state_counter__disableUseContainers : int&)
    state_counter__disableUseContainers -= 1
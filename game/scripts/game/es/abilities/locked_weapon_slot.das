require ecs
require game.es.game_effect_macro

[es(on_appear)]
def locked_weap_slot_set_es(evt : Event; game_effect__attachedTo : EntityId; locked_weapon__slot : int)
  ecs::query(game_effect__attachedTo) <| $ [es] (var human_weap__lockedWeaponSlot : int&)
    human_weap__lockedWeaponSlot = locked_weapon__slot

[es(on_event=EventEntityDestroyed, REQUIRE=locked_weapon__slot)]
def locked_weap_slot_unset_es(evt : Event; game_effect__attachedTo : EntityId)
  ecs::query(game_effect__attachedTo) <| $ [es] (var human_weap__lockedWeaponSlot : int&)
    human_weap__lockedWeaponSlot = -1


[es(on_appear, REQUIRE=locked_weapon__grenadeThrowing)]
def locked_weap_grenade_throwing_set_es(evt : Event; game_effect__attachedTo : EntityId)
  ecs::query(game_effect__attachedTo) <| $ [es] (var human_weap__lockedGrenadeThrowingCounter : int&)
    human_weap__lockedGrenadeThrowingCounter++

[es(on_event=EventEntityDestroyed, REQUIRE=locked_weapon__grenadeThrowing)]
def locked_weap_grenade_throwing_unset_es(evt : Event; game_effect__attachedTo : EntityId)
  ecs::query(game_effect__attachedTo) <| $ [es] (var human_weap__lockedGrenadeThrowingCounter : int&)
    if human_weap__lockedGrenadeThrowingCounter > 0
      human_weap__lockedGrenadeThrowingCounter--

[es(on_appear, REQUIRE=locked_weapon__reload)]
def locked_weap_reload_set_es(evt : Event; game_effect__attachedTo : EntityId)
  ecs::query(game_effect__attachedTo) <| $ [es] (var human_weap__lockWeaponReload : bool&)
    human_weap__lockWeaponReload = true

[es(on_event=EventEntityDestroyed, REQUIRE=locked_weapon__reload)]
def locked_weap_reload_unset_es(evt : Event; game_effect__attachedTo : EntityId)
  ecs::query(game_effect__attachedTo) <| $ [es] (var human_weap__lockWeaponReload : bool&)
    human_weap__lockWeaponReload = false

[es_game_effect(bool_flag=human_weap__blockAimingFromEffect, tag=locked_weapon__aim)]
def set_block_aiming_effect_es() { pass; }
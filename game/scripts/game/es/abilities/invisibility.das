require ecs
require ecs.common
require app
require math.base
require CapsuleApproximation
require HumanPhys
require DngHuman
require DagorSystem
require AnimV20
require GeomNodeTree
require strings
require game.es.game_effect_macro
require game.es.node_attach_common


def show_unit(game_effect__attachedTo : EntityId)
  ecs::query(game_effect__attachedTo) <| $ [es] (var human__visible : bool&;
                                                 var human_net_phys : HumanActor?;
                                                 var havePairCollision : bool?)
    human__visible = true
    if human_net_phys != null
      human_net_phys.phys.currentState |> human_phys_state_set_isVisible(true)
    if havePairCollision != null
      *havePairCollision = true


def hide_unit(game_effect__attachedTo : EntityId)
  ecs::query(game_effect__attachedTo) <| $ [es] (var human__visible : bool&;
                                                 var human_net_phys : HumanActor?;
                                                 var havePairCollision : bool?)
    human__visible = false
    if human_net_phys != null
      human_net_phys.phys.currentState |> human_phys_state_set_isVisible(false)
      human_net_phys.phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_SHOOT, false)
      human_net_phys.phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_THROW_BACK, false)
    if havePairCollision != null
      *havePairCollision = false


// game_effect__invisibleBody just hide unit body
[es(on_appear, REQUIRE=game_effect__invisibleBody)]
def invisible_body_set_es(evt : Event; game_effect__attachedTo : EntityId)
  hide_unit(game_effect__attachedTo)


[es(on_disappear, REQUIRE=game_effect__invisibleBody)]
def invisible_body_unset_es(evt : Event; game_effect__attachedTo : EntityId)
  show_unit(game_effect__attachedTo)


// game_effect__invisibility hide unit from another game play systems
[es(on_appear, REQUIRE=game_effect__invisibility)]
def invisibility_set_es(evt : Event; game_effect__attachedTo : EntityId)
  ecs::query(game_effect__attachedTo) <| $ [es] (var game_effect__invisible : bool&)
    game_effect__invisible = true


[es(on_appear, REQUIRE=game_effect__invisibility)]
def invisibility_set_duration_es(evt : Event; game_effect__attachedTo : EntityId; duration : float)
  ecs::query(game_effect__attachedTo) <| $ [es] (var ai_target__invisibleTimeTo : float&)
    ai_target__invisibleTimeTo = get_sync_time() + duration


[es(on_disappear, REQUIRE=game_effect__invisibility)]
def invisibility_unset_es(evt : Event; game_effect__attachedTo : EntityId)
  ecs::query(game_effect__attachedTo) <| $ [es] (var game_effect__invisible : bool&)
    game_effect__invisible = false


// inverse logic, be carreful, keeps unit invisible on destroy
[es(on_appear, REQUIRE=game_effect__visibility)]
def visibility_set_es(evt : Event; game_effect__attachedTo : EntityId)
  show_unit(game_effect__attachedTo)


[es(on_event=EventEntityDestroyed, REQUIRE=game_effect__visibility)]
def visibility_unset_es(evt : Event; game_effect__attachedTo : EntityId)
  hide_unit(game_effect__attachedTo)


// game_effect__untrackable hide unit from certain game play systems
[es_game_effect(bool_flag=game_effect__untrackable, tag=game_effect__untrackability)]
def set_untrackability_es() { pass; }

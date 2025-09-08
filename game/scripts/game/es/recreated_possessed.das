require ecs
require ecs.common
require ecs.safe
require DagorConsole
require DngActor
require DngHuman
require DagorMath
require GamePhys
require game.utils.spawn_base
require game.events.events_game
require game.es.item_equip_common
require game.events.events_active_matter
require game.events.player_events
require game.utils.spawn


[es(tag=server, on_appear, REQUIRE=recreated_possessed)]
def recreated_possessed_init_rotation(evt : Event;
                                      transform : float3x4;
                                      var human_net_phys : HumanActor;
                                      var camera__lookDir : float3&)
  human_net_phys.phys.producedCT |> human_control_state_set_wish_look_dir(transform[0])
  human_net_phys.phys.producedCT |> human_control_state_set_wish_shoot_dir(transform[0])

  let originX = normalize(transform[0])
  human_net_phys.phys.currentState.location.O |> orient_setYP0(originX)
  camera__lookDir = originX

require ecs
require ecs.common
require app
require math.base
require CapsuleApproximation
require HumanPhys
require DngHuman
require DagorSystem
require DagorRandom
require AnimV20
require GeomNodeTree
require strings
require game.events.events_game
require game.es.game_effect_macro
require game.es.node_attach_common


enum AnotherDimensionVisitorRenderMode
  UNDEFINED
  FROM_OUR_TO_OUR
  FROM_OUR_TO_ANOTHER
  FROM_ANOTHER_TO_OUR
  FROM_ANOTHER_TO_ANOTHER


def update_another_dimension_visitor_state(visitor_eid : EntityId;
                                           visitor_inside : bool;
                                           var human_net_phys : HumanActor?)
  if human_net_phys != null
    if visitor_inside
      human_net_phys.phys.currentState |> human_phys_state_set_isVisible(false)
      human_net_phys.phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_SHOOT, false)
      human_net_phys.phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_RELOAD, false)
      human_net_phys.phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_THROW_BACK, false)
      sendEvent(visitor_eid, CmdInterruptReloadImmediately())
    else
      human_net_phys.phys.currentState |> human_phys_state_set_isVisible(true)


def update_another_dimension_visitor_render_mode(hero_inside : bool;
                                                 target_inside : bool;
                                                 distance_sq_to_hero : float;
                                                 render_mode_in_distance_sq : float;
                                                 render_mode_out_distance_sq : float;
                                                 var another_dimension_visitor__renderMode : int&)
  if distance_sq_to_hero <= render_mode_in_distance_sq
    if hero_inside
      if target_inside
        another_dimension_visitor__renderMode = int(AnotherDimensionVisitorRenderMode.FROM_ANOTHER_TO_ANOTHER)
      else
        another_dimension_visitor__renderMode = int(AnotherDimensionVisitorRenderMode.FROM_ANOTHER_TO_OUR)
    else
      if target_inside
        another_dimension_visitor__renderMode = int(AnotherDimensionVisitorRenderMode.FROM_OUR_TO_ANOTHER)
      else
        another_dimension_visitor__renderMode = int(AnotherDimensionVisitorRenderMode.FROM_OUR_TO_OUR)
  if distance_sq_to_hero >= render_mode_out_distance_sq
    another_dimension_visitor__renderMode = int(AnotherDimensionVisitorRenderMode.UNDEFINED)


def update_another_dimension_visitor_render_mode(target_inside : bool;
                                                 target_pos : float3;
                                                 var another_dimension_visitor__renderMode : int&)
  query() <| $ [es(REQUIRE=watchedByPlr)] (another_dimension_visitor__inside aka hero_another_dimension_visitor__inside : bool;
                                           transform aka hero_transform : float3x4;
                                           another_dimension_visitor__renderModeInDistanceSq : float;
                                           another_dimension_visitor__renderModeOutDistanceSq : float)
    assume heroInAnotherDimension = hero_another_dimension_visitor__inside
    let sqDistanceToHero = distance_sq(hero_transform[3], target_pos)
    update_another_dimension_visitor_render_mode(heroInAnotherDimension, target_inside,
                                                 sqDistanceToHero,
                                                 another_dimension_visitor__renderModeInDistanceSq,
                                                 another_dimension_visitor__renderModeOutDistanceSq,
                                                 another_dimension_visitor__renderMode)


def update_another_dimension_visitors(hero_transform : float3x4;
                                      hero_in_another_dimension : bool;
                                      render_mode_in_distance_sq : float;
                                      render_mode_out_distance_sq : float)
  query() <| $ [es(REQUIRE_NOT=watchedByPlr)] (another_dimension_visitor__inside aka target_another_dimension_visitor__inside : bool;
                                               transform aka target_transform : float3x4;
                                               var another_dimension_visitor__renderMode aka target_another_dimension_visitor__renderMode : int&)
    assume targetInAnotherDimension = target_another_dimension_visitor__inside
    let sqDistanceToHero = distance_sq(hero_transform[3], target_transform[3])
    update_another_dimension_visitor_render_mode(hero_in_another_dimension, targetInAnotherDimension,
                                                 sqDistanceToHero,
                                                 render_mode_in_distance_sq,
                                                 render_mode_out_distance_sq,
                                                 target_another_dimension_visitor__renderMode)


[es(tag=gameClient, on_appear, track=another_dimension_visitor__inside, REQUIRE=(watchedByPlr, another_dimension_visitor__inside))]
def another_dimension_visitor_hero_track_server(evt : Event;
                                                eid : EntityId;
                                                another_dimension_visitor__inside aka hero_another_dimension_visitor__inside : bool;
                                                var human_net_phys : HumanActor?)
  update_another_dimension_visitor_state(eid, hero_another_dimension_visitor__inside, human_net_phys)


[es(tag=gameClient, on_appear, track=another_dimension_visitor__inside, REQUIRE=(watchedByPlr, another_dimension_visitor__inside))]
def another_dimension_visitor_hero_track_client(evt : Event;
                                                another_dimension_visitor__inside aka hero_another_dimension_visitor__inside : bool;
                                                transform aka hero_transform : float3x4;
                                                another_dimension_visitor__renderModeInDistanceSq : float;
                                                another_dimension_visitor__renderModeOutDistanceSq : float;
                                                var another_dimension_visitor__renderMode aka hero_another_dimension_visitor__renderMode : int&)
  update_another_dimension_visitors(hero_transform, hero_another_dimension_visitor__inside,
                                    another_dimension_visitor__renderModeInDistanceSq,
                                    another_dimension_visitor__renderModeOutDistanceSq)
  if hero_another_dimension_visitor__inside
    hero_another_dimension_visitor__renderMode = int(AnotherDimensionVisitorRenderMode.FROM_ANOTHER_TO_ANOTHER)
  else
    hero_another_dimension_visitor__renderMode = int(AnotherDimensionVisitorRenderMode.FROM_OUR_TO_OUR)


[es(tag=gameClient, on_appear, REQUIRE_NOT=watchedByPlr)]
def another_dimension_visitor_target_init(evt : Event;
                                          another_dimension_visitor__renderModeUpdateInterval : float;
                                          var another_dimension_visitor__renderModeNextUpdateAt : float&)
  another_dimension_visitor__renderModeNextUpdateAt = gfrnd() * another_dimension_visitor__renderModeUpdateInterval


[es(tag=gameClient, no_order, REQUIRE_NOT=watchedByPlr)]
def another_dimension_visitor_target_update(act : UpdateStageInfoAct;
                                            another_dimension_visitor__inside aka target_another_dimension_visitor__inside : bool;
                                            transform aka target_transform : float3x4;
                                            another_dimension_visitor__renderModeUpdateInterval : float;
                                            var another_dimension_visitor__renderModeNextUpdateAt : float&;
                                            var another_dimension_visitor__renderMode : int&)
  if act.curTime < another_dimension_visitor__renderModeNextUpdateAt
    return
  another_dimension_visitor__renderModeNextUpdateAt = (another_dimension_visitor__renderModeNextUpdateAt +
                                                      another_dimension_visitor__renderModeUpdateInterval)
  update_another_dimension_visitor_render_mode(target_another_dimension_visitor__inside,
                                               target_transform[3],
                                               another_dimension_visitor__renderMode)


[es(tag=server, on_appear, track=another_dimension_visitor__inside, REQUIRE_NOT=watchedByPlr)]
def another_dimension_visitor_target_track_server(evt : Event;
                                                  eid : EntityId;
                                                  another_dimension_visitor__inside aka target_another_dimension_visitor__inside : bool;
                                                  var human_net_phys : HumanActor?)
  update_another_dimension_visitor_state(eid, target_another_dimension_visitor__inside, human_net_phys)


[es(tag=gameClient, on_appear, track=another_dimension_visitor__inside, REQUIRE_NOT=watchedByPlr)]
def another_dimension_visitor_target_track_client(evt : Event;
                                                  another_dimension_visitor__inside aka target_another_dimension_visitor__inside : bool;
                                                  transform aka target_transform : float3x4;
                                                  var another_dimension_visitor__renderMode : int&)
  assume targetInAnotherDimension = target_another_dimension_visitor__inside
  update_another_dimension_visitor_render_mode(targetInAnotherDimension, target_transform[3],
                                               another_dimension_visitor__renderMode)


def create_render_mode_affect(tmpl : string; eid : EntityId)
  let res = createEntity(tmpl) <| $(var init : ComponentsInitializer)
    set(init, "game_effect__attachedTo", eid)
  return res


def create_render_mode_affects(eid : EntityId;
                               templates : StringList;
                               var another_dimension_visitor__renderModeAffectEids : EidList)
  for tmpl in templates
    let res = create_render_mode_affect(tmpl |> string(), eid)
    another_dimension_visitor__renderModeAffectEids |> push(res)


[es(tag=gameClient, on_appear, track=another_dimension_visitor__renderMode)]
def another_dimension_visitor_render_mode_track(evt : Event;
                                                eid : EntityId;
                                                another_dimension_visitor__renderMode : int;
                                                another_dimension_visitor__renderModeFromOurToOurAffectTemplates : StringList;
                                                another_dimension_visitor__renderModeFromOurToAnotherAffectTemplates : StringList;
                                                another_dimension_visitor__renderModeFromAnotherToOurAffectTemplates : StringList;
                                                another_dimension_visitor__renderModeFromAnotherToAnotherAffectTemplates : StringList;
                                                var another_dimension_visitor__renderModeAffectEids : EidList)
  let renderMode = another_dimension_visitor__renderMode

  for renderModeAffectEid in another_dimension_visitor__renderModeAffectEids
    destroyEntity(renderModeAffectEid)
  another_dimension_visitor__renderModeAffectEids |> clear()

  if renderMode == int(AnotherDimensionVisitorRenderMode.FROM_OUR_TO_OUR)
    create_render_mode_affects(eid, another_dimension_visitor__renderModeFromOurToOurAffectTemplates,
                               another_dimension_visitor__renderModeAffectEids)
  elif renderMode == int(AnotherDimensionVisitorRenderMode.FROM_OUR_TO_ANOTHER)
    create_render_mode_affects(eid, another_dimension_visitor__renderModeFromOurToAnotherAffectTemplates,
                               another_dimension_visitor__renderModeAffectEids)
  elif renderMode == int(AnotherDimensionVisitorRenderMode.FROM_ANOTHER_TO_OUR)
    create_render_mode_affects(eid, another_dimension_visitor__renderModeFromAnotherToOurAffectTemplates,
                               another_dimension_visitor__renderModeAffectEids)
  elif renderMode == int(AnotherDimensionVisitorRenderMode.FROM_ANOTHER_TO_ANOTHER)
    create_render_mode_affects(eid, another_dimension_visitor__renderModeFromAnotherToAnotherAffectTemplates,
                               another_dimension_visitor__renderModeAffectEids)
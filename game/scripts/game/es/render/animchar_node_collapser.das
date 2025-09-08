require ecs
require danetlibs.node_collapser.render.node_collapser_events
require danetlibs.node_collapser.render.node_collapser_common
require AnimV20
require ecs.soa_template

[soa_es, es(REQUIRE=watchedByPlr, REQUIRE_NOT=hero, before=animchar_before_render_es)]
def on_animchar_node_collapser_spectator(evt : HideNodesEvent;
                                         var animchar_render : AnimcharRendComponent&;
                                         animchar_visbits : animchar_visbits_t;
                                         animchar_bsph : vec4f;
                                         animchar_node_collapser : AnimcharNodeCollapser_SOA;
                                         animchar_node_collapser__children : IntList;
                                         animchar_node_collapser__camThreshold : float = 0.3;
                                         animchar_node_collapser__origin_threshold_sq : float = 100.0)
  collapser(evt.at, animchar_render, animchar_visbits, float4(animchar_bsph).xyz,
            animchar_node_collapser, animchar_node_collapser__children,
            animchar_node_collapser__camThreshold, animchar_node_collapser__origin_threshold_sq)


[soa_es, es(REQUIRE=watchedPlayerItem, before=animchar_before_render_es)]
def on_animchar_node_collapser_watched_by_player_item(evt : HideNodesEvent;
                                                      var animchar_render : AnimcharRendComponent&;
                                                      animchar_visbits : animchar_visbits_t;
                                                      animchar_bsph : vec4f;
                                                      animchar_node_collapser : AnimcharNodeCollapser_SOA;
                                                      animchar_node_collapser__children : IntList;
                                                      animchar_node_collapser__camThreshold : float = 0.3;
                                                      animchar_node_collapser__origin_threshold_sq : float = 100.0)
  collapser(evt.at, animchar_render, animchar_visbits, float4(animchar_bsph).xyz,
            animchar_node_collapser, animchar_node_collapser__children,
            animchar_node_collapser__camThreshold, animchar_node_collapser__origin_threshold_sq)

module game_effect_geomtree_common shared
require ecs
require ecs.soa_template


[soa_template]
struct GameEffectGeomtreeNodesCache
  game_effect_geomtree_nodes_cache__ctm : float3x4
  game_effect_geomtree_nodes_cache__ctmVolume : float
  game_effect_geomtree_nodes_cache__nodeIdx : int


def make_tm_for_capsule_node(data) : float3x4
  var result : float3x4
  result[3] = (data.a + data.b) * 0.5
  result[0][0] = length(data.a - data.b) + 2.f * data.rad
  result[1][1] = data.rad * 2.f
  result[2][2] = data.rad * 2.f
  return <- result

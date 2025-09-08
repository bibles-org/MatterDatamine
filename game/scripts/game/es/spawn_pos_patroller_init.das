require ecs

[es(on_appear, REQUIRE_NOT=patroller__customAroundPos)]
def spawn_pos_patroller_init(evt : Event; transform : float3x4; var patroller__aroundPos : float3&)
  patroller__aroundPos = transform[3]

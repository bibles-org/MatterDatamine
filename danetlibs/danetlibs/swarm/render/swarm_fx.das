require ecs
require fx

[es(on_appear, REQUIRE=flyingSwarmObject, REQUIRE_NOT=(swarm__disabled, steer__dasScript, flying_critters))]
def swarm_create_fx_init(evt : Event; swarm__shoot_fx_name : string; var swarm__shoot_fx_id : int&)
  swarm__shoot_fx_id = get_type_by_name(swarm__shoot_fx_name)
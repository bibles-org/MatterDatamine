require ecs


[es(tag=netClient, on_appear, REQUIRE=animchar__dirtyWhenAppearsOnClient)]
def init_nesting_swarm_nest_anim_client(evt : Event; var animchar__animStateDirty : bool&)
  animchar__animStateDirty = true
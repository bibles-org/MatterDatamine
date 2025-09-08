require ecs


[es(REQUIRE=net_stash_entity, on_appear)]
def client_disable_animchar_in_net_stash(evt : Event; var animchar__updatable : bool&)
  animchar__updatable = false


[es(REQUIRE=net_stash_entity, on_disappear)]
def client_enable_animchar_out_of_net_stash(evt : Event; var animchar__updatable : bool&)
  animchar__updatable = true

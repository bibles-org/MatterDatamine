require ecs


[es(tag=server, on_appear, REQUIRE=loud_noise_reaction)]
def enable_animchar_on_loud_noise_reaction(evt : Event; var animchar__updatable : bool&)
  animchar__updatable = true

[es(tag=server, on_disappear, REQUIRE=loud_noise_reaction, before=enable_animchar_on_sleeping_monster_disappear)]
def disable_animchar_on_end_of_loud_noise_reaction(evt : Event; var animchar__updatable : bool&)
  animchar__updatable = false
require ecs


[es(tag=server, on_disappear, REQUIRE=sleeping_monster)]
def enable_animchar_on_sleeping_monster_disappear(evt : Event; var animchar__updatable : bool&)
  animchar__updatable = true

[es(tag=server, on_appear, REQUIRE=sleeping_monster)]
def disable_animchar_on_sleeping_monster_appear(evt : Event; var animchar__updatable : bool&)
  animchar__updatable = false
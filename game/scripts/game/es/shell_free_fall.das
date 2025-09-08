require ecs
require math.base
require Dacoll
require DagorRandom
require game.events.events_active_matter


[es(tag=server, on_event=(EventEntityCreated, EventEntityRecreated), REQUIRE=shell_free_fall_effect)]
def free_fall_shell_appear(evt : Event; shell_free_fall_effect__addHeight : float;
                           var shell_free_fall_effect__fallOn : float3&; var transform : float3x4&)
  var height = 300f
  transform[3] += float3(cos(rnd_float(0f, TWOPI)), 0f, sin(rnd_float(0f, TWOPI))) * rnd_float(0.5f, 1f)
  shell_free_fall_effect__fallOn = transform[3]
  if tracedown_normalized(transform[3], height, ETF_DEFAULT)
    shell_free_fall_effect__fallOn.y = transform[3].y - height + shell_free_fall_effect__addHeight


[es(tag=server, no_order)]
def free_fall_shell_act(info : ParallelUpdateFrameDelayed; eid : EntityId; item__count : int const?;
                        shell_free_fall_effect__fallOn : float3; transform : float3x4;
                        shell_free_fall_effect__recreateOnFallTemplate : string)
  if transform[3].y <= shell_free_fall_effect__fallOn.y
    let templ = ((item__count == null) ? shell_free_fall_effect__recreateOnFallTemplate
                  : "{shell_free_fall_effect__recreateOnFallTemplate}+coin_item_count_{item__count}")
    createEntity(templ) <| $(var init)
      set(init, "transform", transform)
    destroyEntity(eid)

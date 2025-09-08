require ecs
require strings
require math.base
require DagorMath


[es(tag=server, on_appear)]
def item_scale_by_count(evt : Event;
                        var item__scaleMult : float&;
                        var transform : float3x4&;
                        item__count = 1;
                        item__animcharAfterLooting : das_string const?)
  if item__scaleMult > 0f
    let scale = item__scaleMult * float(item__count)
    transform = transform * scale_tm(scale)

    if item__animcharAfterLooting != null
      // Since when an item is dropped from the inventory,
      // it will be recreated, we no longer need to scale it
      item__scaleMult = -1f


[es(tag=server, on_appear)]
def item_scale_by_count_rng(evt : Event;
                            item__scaleMultCountRng : float2;
                            var item__scaleMultRng : float2&;
                            var transform : float3x4&;
                            item__count = 1;
                            item__animcharAfterLooting : das_string const?)
  if item__scaleMultRng.x > 0f && item__scaleMultRng.y > 0f
    let scale = cvt(float(item__count),
      item__scaleMultCountRng.x, item__scaleMultCountRng.y,
      item__scaleMultRng.x, item__scaleMultRng.y)
    transform = transform * scale_tm(scale)

    if item__animcharAfterLooting != null
      // Since when an item is dropped from the inventory,
      // it will be recreated, we no longer need to scale it
      item__scaleMultRng.x = -1f
      item__scaleMultRng.y = -1f

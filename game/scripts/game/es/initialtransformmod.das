require ecs

[es(on_appear)]
def initial_transform_mod(evt : Event; var transform : float3x4&; initialTransformMod : float3x4)
  transform = transform * initialTransformMod


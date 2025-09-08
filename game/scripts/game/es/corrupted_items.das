require ecs
require math.base
require DagorMath
require DagorRandom

[es(tag=gameClient, on_appear, after=drop_item_created_es)]
def corrupted_item_effect_init(evt : Event;
                               transform : float3x4;
                               item_corrupted__effectName : string;
                               item_corrupted__effectScaleRng : float2;
                               item_corrupted__effectOffsets : Point3List;
                               var item_corrupted__effectEids : EidList&)
  for offset in item_corrupted__effectOffsets
    var tm = scale_tm(rnd_float(item_corrupted__effectScaleRng.x, item_corrupted__effectScaleRng.y))
    var rotTm : float3x4
    var rotQuat : quat
    let angleRad = TWOPI
    euler_to_quat(rnd_float(0.0, angleRad), rnd_float(0.0, angleRad), rnd_float(0.0, angleRad), rotQuat)
    make_tm(rotQuat, rotTm)
    tm = tm * rotTm
    tm[3] = transform[3] + rotate(transform, offset)
    let effectEid = createEntity(item_corrupted__effectName) <| $(var init)
      init |> set("transform", tm)
    item_corrupted__effectEids |> push(effectEid)


[es(tag=gameClient, on_disappear, REQUIRE=transform)]
def corrupted_item_effect_destroy(evt : Event; var item_corrupted__effectEids : EidList&)
  for effect in item_corrupted__effectEids
    destroyEntity(effect)
  item_corrupted__effectEids |> clear()


[es(tag=gameClient, track=transform)]
def corrupted_item_effect_change(evt : Event;
                                 item_corrupted__effectEids : EidList;
                                 item_corrupted__effectOffsets : Point3List;
                                 transform aka owner_transform : float3x4)
  for i in iter_range(item_corrupted__effectEids)
    query(item_corrupted__effectEids[i]) <| $ [es] (var transform : float3x4&)
      transform[3] = owner_transform[3] + rotate(owner_transform, item_corrupted__effectOffsets[i])

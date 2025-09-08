require ecs
require Dacoll
require RendInst
require DagorMath
require inventory
require game.events.events_game
require math.base
require game.es.grav_zones_common
require game.es.inventory_drop_common


def drop_rendinst_attach(eid : EntityId; var transform : float3x4; drop_tm : float3x4 const?)
  var t = 50.0
  var norm : float3
  let down = get_grav_dir(transform[3])
  if traceray_normalized(transform[3], down, t, norm)
    let end = transform[3] + down * t
    align_item(end, norm, transform)
    if drop_tm != null
      transform = transform * deref(drop_tm)
  else
    destroyEntity(eid)


[es(tag=server, REQUIRE_NOT=rendinst_attach__dropOnRiDestroy)]
def destroy_rendinst_attach_es(evt : EventRendinstDestroyed; eid : EntityId; rendinst_attach__riexHandle : riex_handle_t)
  if evt.riexHandle == rendinst_attach__riexHandle
    destroyEntity(eid)


[es(tag=server, REQUIRE=rendinst_attach__dropOnRiDestroy)]
def drop_rendinst_attach_es(evt : EventRendinstDestroyed; eid : EntityId; rendinst_attach__riexHandle : riex_handle_t; var transform : float3x4; dropTm : float3x4 const?)
  if evt.riexHandle == rendinst_attach__riexHandle
    drop_rendinst_attach(eid, transform, dropTm)


[es(tag=server, on_appear, REQUIRE_NOT=rendinst_attach__dropOnRiDestroy)]
def destroy_invalid_rendinst_attach_es(evt : Event; eid : EntityId; rendinst_attach__riexHandle : riex_handle_t)
  if !riex_isRiGenExtraValid(rendinst_attach__riexHandle)
    destroyEntity(eid)


[es(tag=server, on_appear, REQUIRE=rendinst_attach__dropOnRiDestroy)]
def drop_invalid_rendinst_attach_es(evt : Event; eid : EntityId; rendinst_attach__riexHandle : riex_handle_t; var transform : float3x4; dropTm : float3x4 const?)
  if !riex_isRiGenExtraValid(rendinst_attach__riexHandle)
    drop_rendinst_attach(eid, transform, dropTm)


[es(track=transform, REQUIRE=rendinst_axis_rotation__axis)]
def rotate_rendinst_attach_es(evt : Event; eid : EntityId; transform aka riex_transform : float3x4)
  ecs::query() <| $ [es] (var transform : float3x4; rendinst_attach__riexEid : EntityId; rendinst_attach__localTm : float3x4)
    if rendinst_attach__riexEid == eid
      transform = riex_transform * rendinst_attach__localTm

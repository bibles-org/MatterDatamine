options no_aot
require ecs
require DagorConsole
require DagorDebug3D

[console_cmd(name="migration.lauch_all")]
def console_migration_lauch_all()
  query() <| $ [es] (var migration__migrateAt : float&)
    if migration__migrateAt != FLT_MAX
      migration__migrateAt = 0.0


[console_cmd(name="migration.finish_all")]
def console_migration_finish_all()
  query() <| $ [es] (var migration__updateAt : float&; var migration__path : Point3List; var transform : float3x4; var migration__waitingTimeLeft : float&)
    if migration__updateAt != FLT_MAX && length(migration__path) > 0
      migration__updateAt = 0.0
      migration__waitingTimeLeft = 0.0
      clear(migration__path)
      transform[3] = migration__path[length(migration__path) - 1]


[console_cmd(name="migration.debug")]
def console_migration_debug()
  query() <| $ [es] (var migration__debug : bool&)
    migration__debug = !migration__debug


[es(tag=dev, no_order)]
def migration_debug_es(act : UpdateStageInfoRenderDebug;
                       eid : EntityId;
                       migration__debug : bool;
                       transform aka migration_transform : float3x4;
                       migration__radius : float;
                       migration__migrateAt : float;
                       migration__path : Point3List)
  if migration__debug && migration__migrateAt == FLT_MAX
    let lastPoint = length(migration__path) > 0 ? migration__path[length(migration__path) - 1] : migration_transform[3]
    let color = E3DCOLOR(0xFFFFFF00)
    let color2 = E3DCOLOR(0xFFFF5500)
    begin_draw_cached_debug_lines(true, false, false)
    draw_cached_debug_sphere(migration_transform[3], migration__radius, color, 48)
    var lastP = migration_transform[3]
    for p in migration__path
      draw_cached_debug_line(lastP, p, color2)
      lastP = p
    draw_cached_debug_sphere(lastPoint, migration__radius, color2, 48)
    query() <| $ [es] (migration__leaderEid : EntityId; transform aka follower_transform : float3x4)
      if migration__leaderEid == eid
        draw_cached_debug_line(migration_transform[3], follower_transform[3], color)
    end_draw_cached_debug_lines()

require ecs
require math.base
require math.random
require DagorMath
require DagorRandom
require pathfinder
require game.es.am_core_warrior_common

[es(tag=server, on_appear)]
def spawn_core_warriors(evt : Event;
                        eid : EntityId;
                        transform : float3x4;
                        protected_by_warriors__enabled : bool;
                        protected_by_warriors__count : int2;
                        protected_by_warriors__template : string;
                        protected_by_warriors__spawnRadius : float;
                        protected_by_warriors__minProximity : float;
                        var protected_by_warriors__origin : float3&)
  let count = rnd_int(protected_by_warriors__count)
  var origin = transform[3]
  var positions : array<float3>
  if project_to_nearest_navmesh_point(origin, protected_by_warriors__minProximity)
    add_core_warrior_spawn_positions(origin, protected_by_warriors__spawnRadius, protected_by_warriors__minProximity, count, count * 10, positions)
  protected_by_warriors__origin = origin
  for p in positions
    createEntity(protected_by_warriors__template) <| $(init)
      var tm = IDENT_TM
      if !protected_by_warriors__enabled
        init |> set("am_core_warrior__state", int(CoreWarriorState.HIDDEN))
        tm[3] = transform[3]
      else
        tm[3] = p

      init |> set("transform", tm)
      init |> set("am_core_warrior__parentEid", eid)
      init |> set("am_core_warrior__origin", tm[3])
      init |> set("am_core_warrior__spawnPosition", p)


[es(on_appear)]
def init_core_warriror(evt : Event;
                       eid : EntityId;
                       am_core_warrior__moveAmplitudeRnd : float;
                       am_core_warrior__moveFreqRnd : float;
                       am_core_warrior__elevationRnd : float2;
                       var am_core_warrior__moveAmplitude : float&;
                       var am_core_warrior__moveFreq : float&;
                       var am_core_warrior__moveTimeOffset : float&;
                       var am_core_warrior__origin : float3&)
  var seed = int(uint(eid))
  am_core_warrior__moveAmplitude += _rnd_float(seed, -am_core_warrior__moveAmplitudeRnd, am_core_warrior__moveAmplitudeRnd)
  am_core_warrior__moveFreq += _rnd_float(seed, -am_core_warrior__moveFreqRnd, am_core_warrior__moveFreqRnd)
  am_core_warrior__moveTimeOffset = _rnd_float(seed, 0.0, 1.0 / am_core_warrior__moveFreq)
  am_core_warrior__origin.y += _rnd_float(seed, am_core_warrior__elevationRnd)
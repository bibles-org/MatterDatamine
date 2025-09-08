import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *
let { Point3 } = require("dagor.math")

let warningsCompsTrack = [
  ["ui_perf_stats__server_tick_warn", 0],
  ["ui_perf_stats__low_fps_warn", 0],
  ["ui_perf_stats__latency_warn", 0],
  ["ui_perf_stats__latency_variation_warn", 0],
  ["ui_perf_stats__packet_loss_warn", 0],
  ["ui_perf_stats__low_tickrate_warn", 0],
]

let warnings = Watched(warningsCompsTrack.totable())
let serverStatsAvailable = Watched(false)
let serverFps = Watched(0.0)
let serverDtMinMaxAvg = Watched(Point3())

ecs.register_es("script_perf_stats_es",
  {
    [["onChange", "onInit"]] = @(_evt, _eid, comp) warnings(clone comp)
  },
  {comps_track=warningsCompsTrack.map(@(v) [v[0], ecs.TYPE_INT])}
)

ecs.register_es("server_stats_controller_ui_es",
  {
    [["onChange", "onInit"]] = function(_evt, _eid, comp){
      serverStatsAvailable(true)
      serverFps(comp.server_stats_controller__fps)
      serverDtMinMaxAvg(comp.server_stats_controller__dtMinMaxAvg)
    },
    onDestroy = function(_evt, _eid, _comp){
      serverStatsAvailable(false)
    }
  },
  {
    comps_track=[
      ["server_stats_controller__fps", ecs.TYPE_FLOAT],
      ["server_stats_controller__dtMinMaxAvg", ecs.TYPE_POINT3]
    ]
  }
)

return {
  warnings
  serverStatsAvailable
  serverFps
  serverDtMinMaxAvg
}

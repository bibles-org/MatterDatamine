from "settings" import get_setting_by_blk_path
from "videomode" import get_performance_display_mode_support

from "%ui/ui_library.nut" import *


const PERF_METRICS_BLK_PATH = "video/perfMetrics"

const PERF_METRICS_OFF = 0
const PERF_METRICS_FPS = 1
const PERF_METRICS_COMPACT = 2
const PERF_METRICS_FULL = 3

let perfMetricsToString = static {
  [PERF_METRICS_OFF] = "options/off",
  [PERF_METRICS_FPS] = "options/perf_fps",
  [PERF_METRICS_COMPACT] = "options/perf_compact",
  [PERF_METRICS_FULL] = "options/perf_full"
}

let perfMetricsAvailable = WatchedRo(function() {
  let ret = [
    PERF_METRICS_OFF
  ]
  let options = [
    PERF_METRICS_FPS,
    PERF_METRICS_COMPACT,
    PERF_METRICS_FULL
  ]
  foreach (mode in options) {
    if (get_performance_display_mode_support(mode))
      ret.append(mode)
  }
  return ret
}())

let perfMetricsValueChosen = Watched(get_setting_by_blk_path(PERF_METRICS_BLK_PATH))

let perfMetricsSetValue = @(v) perfMetricsValueChosen.set(v)

let perfMetricsValue = Computed(function() {
  let available = perfMetricsAvailable.get()
  let chosen = perfMetricsValueChosen.get()
  return available.contains(chosen) ? chosen
    : available.contains(PERF_METRICS_FPS) ? PERF_METRICS_FPS
    : PERF_METRICS_OFF
})

return freeze({
  PERF_METRICS_BLK_PATH
  PERF_METRICS_OFF
  PERF_METRICS_FPS
  PERF_METRICS_COMPACT
  PERF_METRICS_FULL
  perfMetricsAvailable
  perfMetricsValue
  perfMetricsToString
  perfMetricsSetValue
})

from "%ui/ui_library.nut" import *

let {basic_text_shadow} = require("%ui/fonts_style.nut")
let { warnings, serverStatsAvailable, serverFps, serverDtMinMaxAvg } = require("%ui/hud/state/perf_stats_es.nut")
let {safeAreaHorPadding, safeAreaVerPadding} = require("%ui/options/safeArea.nut")
let {setTooltip} = require("%ui/components/cursors.nut")
let picSz = fsh(3.3)
let {hudIsInteractive} = require("%ui/hud/state/interactive_state.nut")
let {round_by_value} = require("%sqstd/math.nut")

function pic(name) {
  return Picture("ui/skin#qos/{0}.svg:{1}:{1}:K".subst(name, picSz.tointeger()))
}

let icons = {
  ["ui_perf_stats__server_tick_warn"] = {pic = pic("server_perfomance"), loc="hud/server_tick_warn_tip"},
  ["ui_perf_stats__low_fps_warn"] = {pic = pic("low_fps"), loc="hud/low_fps_warn_tip"},
  ["ui_perf_stats__latency_warn"] = {pic = pic("high_latency"), loc="hud/latency_warn_tip"},
  ["ui_perf_stats__latency_variation_warn"] = {pic = pic("latency_variation"), loc ="hud/latency_variation_warn_tip"},
  ["ui_perf_stats__packet_loss_warn"] = {pic = pic("packet_loss"), loc="hud/packet_loss_warn_tip"},
  ["ui_perf_stats__low_tickrate_warn"] = {pic = pic("low_tickrate"), loc="hud/low_tickrate_warn_tip"},
}

let colorMedium = Color(160, 120, 0, 160)
let colorHigh = Color(200, 50, 0, 160)
let debugWarnings = Watched(false)
function mkidx() {
  local i = 0
  return @() i++
}

let cWarnings = Computed(function() {
  let idx = mkidx()
  return debugWarnings.value ? icons.map(@(_v,_i) 1+(idx()%2)) : warnings.value
})
console_register_command(@() debugWarnings(!debugWarnings.value),"ui.debug_perf_stats")

function root() {
  let children = []

  foreach (key, val in cWarnings.value) {
    if (val > 0) {
      let hint = loc(icons[key]["loc"], "")
      let onHover = @(on) setTooltip(on ? hint : null)
      children.append({
        key = key
        size = [picSz, picSz]
        image = icons[key]["pic"]
        behavior = hudIsInteractive.value ? Behaviors.Button : null
        skipDirPadNav = true
        onHover = onHover
        rendObj = ROBJ_IMAGE
        color = (val==2) ? colorHigh : colorMedium
      })
    }
  }

  return {
    watch = [cWarnings, safeAreaHorPadding, hudIsInteractive, serverStatsAvailable,
      serverFps, serverDtMinMaxAvg]
    size = [sw(100), sh(100)]
    padding = [max(safeAreaVerPadding.get(), fsh(2)), max(safeAreaHorPadding.get(), fsh(45))]
    children = [
      {
        flow = FLOW_HORIZONTAL
        hplace = ALIGN_RIGHT
        children = children
      }
      !serverStatsAvailable.get() ? null : {
        rendObj = ROBJ_TEXT
        text = $"Server FPS: {round_by_value(serverFps.value, 0.1)} ({round_by_value(1000.0 * serverDtMinMaxAvg.value.x, 0.1)}<{round_by_value(1000.0 * serverDtMinMaxAvg.value.y, 0.1)} {round_by_value(1000.0 * serverDtMinMaxAvg.value.z, 0.1)})"
        transform = { translate = [sh(35.0), -sh(0.125)] }
        color = serverFps.value <= 12.0 ? Color(255, 0, 0, 255) : (serverFps.value <= 24.0 ? Color(30, 255, 30, 255) : Color(155, 120, 255, 250))
      }.__update(basic_text_shadow, {
        font = Fonts.system
        fontSize = fsh(1.209)
      })
    ]
  }
}

return root

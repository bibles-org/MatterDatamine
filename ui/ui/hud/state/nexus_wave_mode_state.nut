from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let nexusWaveModeNextGameEndTimer = Watched(-1)

ecs.register_es("nexus_wave_mode_reset_data_on_game_start", {
  [["onChange", "onInit"]] = function(_evt, _eid, comp) {
    nexusWaveModeNextGameEndTimer.set(comp.nexus_wave_mode_game_controller__timeOutAt)
  },
  onDestroy = function(_evt, _eid, _comp) {
    nexusWaveModeNextGameEndTimer.set(-1.0)
  }
},
{
  comps_track = [
    ["nexus_wave_mode_game_controller__timeOutAt", ecs.TYPE_FLOAT]
  ]
},
{
  tags = "gameClient"
})

return {
  nexusWaveModeNextGameEndTimer
}

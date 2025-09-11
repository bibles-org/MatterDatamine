from "settings" import get_setting_by_blk_path
from "%ui/mainMenu/menus/options/options_lib.nut" import getOnlineSaveData, mkSliderWithText, optionCtor

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *


let setCameraFovQuery = ecs.SqQuery("setCameraFovQuery", {
  comps_rw = [ ["fovSettings", ecs.TYPE_FLOAT] ],
  comps_ro = [ ["fovLimits", ecs.TYPE_POINT2], ["camera__fovSettingsPath", ecs.TYPE_STRING] ]
})

function optionCameraFovTextSliderCtor(opt, group, xmbNode, optionPath) {
  let optSetValue = opt.setValue
  function setValue(val) {
    optSetValue(val)
    setCameraFovQuery.perform(function(_eid, comp) {
        if (optionPath == comp["camera__fovSettingsPath"])
          comp["fovSettings"] = clamp(val, comp.fovLimits.x, comp.fovLimits.y)
      })
  }
  opt = opt.__merge({setValue})
  return mkSliderWithText(opt, group, xmbNode)
}

function mkCameraFovOption(title, field, settings={}) {
  let blkPath = $"gameplay/{field}"
  let { watch, setValue } = getOnlineSaveData(blkPath,
    @() get_setting_by_blk_path(blkPath) ?? settings?.defVal ?? 90.0)
  return optionCtor({
    name = title
    tab = "Game"
    widgetCtor = @(opt, group, xmbNode) optionCameraFovTextSliderCtor(opt, group, xmbNode, field)
    var = watch
    setValue = setValue
    defVal = settings?.defVal ?? 90.0
    min = settings?.minVal ?? 50.0
    max = settings?.maxVal ?? 100.0
    unit = settings?.unit ?? 0.05
    pageScroll = 1
    restart = false
    blkPath = blkPath
  })
}

return mkCameraFovOption

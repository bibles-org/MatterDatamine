from "%ui/mainMenu/menus/options/quality_preset_common.nut" import graphicsPresetUpdate
from "%ui/mainMenu/menus/options/render_options.nut" import optShadowsQuality, optEffectsShadows, optGiAlgorithm, optGiAlgorithmQuality,
  optSkiesQuality, optSsaoQuality, optCloudsQuality, optVolumeFogQuality,
  optWaterQuality, optGroundDisplacementQuality, optGroundDeformations, optAnisotropy,
  optOnlyonlyHighResFx, optScreenSpaceWeatherEffects, optSSRQuality, optScopeImageQuality,
  optTexQuality, optFFTWaterQuality, optEnvironmentDetailQuality, optHQProbeReflections,
  optSSSS, optRendinstTesselation, optHQVolumetricClouds, optHQVolfog, optHQSSR, optScopeZoomMode
from "dagor.debug" import logerr
from "%ui/mainMenu/menus/options/options_lib.nut" import optionCtor, optionSpinner, loc_opt
from "%ui/ui_library.nut" import *


let platform = require("%dngscripts/platform.nut")
let { MINIMUM, LOW, MEDIUM, HIGH, ULTRA, CUSTOM, graphicsPresetBlkPath, graphicsPreset } = require("%ui/mainMenu/menus/options/quality_preset_common.nut")







let presetsRequired = freeze([MINIMUM, LOW, MEDIUM, HIGH, ULTRA])
let numPresets = presetsRequired.len()
let avPresets = freeze([].extend(presetsRequired).append(CUSTOM))

let mapOptionsByPreset = {
   
   
   
   
   
   
   
  [optTexQuality]                = ["low", "medium", "high", "high", "high"],
  [optGiAlgorithm]               = ["low", "medium", "medium", "high", "high"],
  [optGiAlgorithmQuality]        = [0.5,    0.5,      1.0,     0.5,     0.8],
  [optAnisotropy]                = [1,        2,       4,       8,      16],
  [optSkiesQuality]              = ["low", "low", "medium", "high", "high"],
  [optSsaoQuality]               = ["low", "low", "medium", "high", "high"],
  [optShadowsQuality]            = ["low", "low", "medium", "high", "ultra"],
  [optEffectsShadows]            = [false,  false,   false,    true,   true],
  [optCloudsQuality]             = ["default", "default", "default", "highres", "volumetric"],
  [optVolumeFogQuality]          = ["close", "close", "medium", "medium", "far"],
  [optWaterQuality]              = ["low", "low", "low", "medium",   "high"],
  [optGroundDisplacementQuality] = [0,        0,       1,       1,     2],
  [optGroundDeformations]        = ["off", "low", "medium", "high",  "high"],
  [optOnlyonlyHighResFx]         = ["lowres", "lowres", "medres", "medres", "highres"],
  [optScreenSpaceWeatherEffects] = [false, false,    true,     true,   true],
  [optSSRQuality]                = ["low", "low", "low", "medium", "high"],
  [optScopeImageQuality]         = [3,       3,        3,        3,     3  ],
  [optFFTWaterQuality]           = ["low", "medium", "high", "ultra", "ultra"],
  [optEnvironmentDetailQuality]  = ["low", "low",    "low",   "high", "high"],
  [optHQProbeReflections]        = [false, false,    true,   true,    true],
  [optSSSS]                      = ["off", "off",   "low",   "high",  "high"],
  [optRendinstTesselation]       = [false, false,    false,     false,    true],
  [optHQVolumetricClouds]        = [false, false,   false,    false,    false], 
  [optHQVolfog]                  = [false, false,   false,    false,    false], 
  [optHQSSR]                     = [false, false,   false,    false,    false], 
  [optScopeZoomMode]             = [false, true, true, true, true]
}

let optGraphicsQualityPreset = optionCtor({
  name = loc("options/graphicsPreset")
  isAvailable = @() platform.is_pc
  widgetCtor = optionSpinner
  var = graphicsPreset
  setValue = graphicsPresetUpdate
  defVal = graphicsPreset.get()
  tab = "Graphics"
  available = avPresets
  valToString = loc_opt
  blkPath = graphicsPresetBlkPath
  hint = loc("guiHints/graphicsPreset")
})

foreach(o, q in mapOptionsByPreset){
  let opt = o
  let qualities = q
  let qNum = qualities.len()
  assert(qNum <= numPresets, "preset is missed")
  if (numPresets > qNum){
    qualities.resize(numPresets, qualities[qNum-1])
  }
  foreach(v in qualities){
    if ("available" in opt && !opt.available.contains(v)) {
      logerr($"incorrect preset value: '{v}'")
    }
  }
  opt.var.subscribe(function(_optVal){
    if (graphicsPreset.get() == CUSTOM)
      return
    if (!(opt?.isAvailable() ?? true))
      return
    defer(function() {
      if (opt.var.get() == qualities?[presetsRequired.indexof(graphicsPreset.get())])
        return
      graphicsPresetUpdate(CUSTOM)
    })
  })
}

function setOptionsByPreset(...){
  let gp = graphicsPreset.get()
  if (gp == CUSTOM || !optGraphicsQualityPreset.isAvailable())
    return
  let idx = presetsRequired.indexof(gp)
  if (idx == null)
    return
  foreach (o, q in mapOptionsByPreset){
    let opt = o
    let qualities = q
    if ("isAvailable" in opt && !opt.isAvailable())
      continue
    if ("isDisabled" in opt && opt.isDisabled())
      continue
    let val = qualities[idx]
    if (opt?.var.get() ==  val)
      continue
    if ("setValue" in opt)
      opt.setValue(val)
    else if ("var" in opt)
      opt.var.set(val)
  }
}

graphicsPreset.subscribe_with_nasty_disregard_of_frp_update(setOptionsByPreset)
setOptionsByPreset()

return {
  optGraphicsQualityPreset
}

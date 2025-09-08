from "%ui/ui_library.nut" import *

let { floor } = require("%sqstd/math.nut")
let {get_setting_by_blk_path} = require("settings")
let {safeAreaAmount, safeAreaBlkPath, safeAreaList, safeAreaSetAmount,
  safeAreaCanChangeInOptions} = require("%ui/options/safeArea.nut")
let platform = require("%dngscripts/platform.nut")
let { DBGLEVEL, dgs_get_settings } = require("dagor.system")

let {loc_opt, defCmp, getOnlineSaveData, mkSliderWithText,
  optionPercentTextSliderCtor, optionCheckBox, optionCombo, optionSlider,
  mkDisableableCtor, optionSpinner,
  optionCtor
} = require("options_lib.nut")
let { resolutionList, resolutionValue } = require("resolution_state.nut")
let { DLSS_BLK_PATH, DLSS_OFF, dlssAvailable, dlssValue, dlssToString,
  dlssSetValue, dlssNotAllowLocId, DLSSG_BLK_PATH, dlssgAvailable, dlssgValue, dlssgSetValue,
  dlssgNotAllowLocId, dlssgToString, DLSSG_OFF
} = require("dlss_state.nut")
let { LOW_LATENCY_BLK_PATH, LOW_LATENCY_OFF, LOW_LATENCY_NV_ON,
  LOW_LATENCY_NV_BOOST, lowLatencyAvailable, lowLatencyValue,
  lowLatencySetValue, lowLatencyToString, lowLatencySupported
} = require("low_latency_options.nut")
let { PERF_METRICS_BLK_PATH, PERF_METRICS_FPS,
  perfMetricsAvailable, perfMetricsValue, perfMetricsSetValue, perfMetricsToString
} = require("performance_metrics_options.nut")
let { is_dx12, is_vulkan, is_hdr_available,
  is_hdr_enabled, change_paper_white_nits, change_gamma,
  is_rendinst_tessellation_supported, is_only_low_gi_supported } = require("videomode")
let { availableMonitors, monitorValue, get_friendly_monitor_name } = require("monitor_state.nut")
let { fpsList, UNLIMITED_FPS_LIMIT } = require("fps_list.nut")
let {isBareMinimum} = require("quality_preset_common.nut")
let { logerr } = require("dagor.debug")
let { nestWatched } = require("%dngscripts/globalState.nut")
let { showMsgbox } = require("%ui/components/msgbox.nut")

let resolutionToString = @(v) typeof v == "string" ? v : $"{v[0]} x {v[1]}"

let gammaCorrectionSave = getOnlineSaveData("graphics/gamma_correction",
  @() 1.0,
  @(p) clamp(p, 0.5, 1.5)
)

let bareOffText = Computed(@() isBareMinimum.value ? loc("option/off") : null)
let bareLowText = Computed(@() isBareMinimum.value ? loc("option/low") : null)

let consoleGfxSettingsBlk = get_setting_by_blk_path("graphics/consoleGfxSettings")
let consoleSettingsEnabled = (consoleGfxSettingsBlk != null) && (consoleGfxSettingsBlk == true)

let isOptAvailable = @() platform.is_pc || (DBGLEVEL > 0 && (platform.is_sony || platform.is_xbox) && consoleSettingsEnabled)
let isPcDx12 = @() platform.is_pc && is_dx12()

let optSafeArea = optionCtor({
  name = loc("options/safeArea")
  widgetCtor = optionSpinner
  tab = "Graphics"
  isAvailable = safeAreaCanChangeInOptions
  blkPath = safeAreaBlkPath
  var = safeAreaAmount
  setValue = safeAreaSetAmount
  defVal = 1.0
  available = safeAreaList
  valToString = @(s) $"{s*100}%"
  isEqual = defCmp
  hint = loc("guiHints/safeArea")
})

const defVideoMode = "fullscreen"
let originalValVideoMode = get_setting_by_blk_path("video/mode") ?? defVideoMode
let videoModeVar = Watched(originalValVideoMode)

let optVideoMode = optionCtor({
  name = loc("options/mode")
  widgetCtor = optionSpinner
  tab = "Graphics"
  blkPath = "video/mode"
  isAvailable = isOptAvailable
  defVal = defVideoMode
  available = platform.is_windows ? ["windowed", "fullscreenwindowed", "fullscreen"] : ["windowed", "fullscreen"]
  originalVal = originalValVideoMode
  var = videoModeVar
  restart = !platform.is_windows
  valToString = @(s) loc($"options/mode_{s}")
  isEqual = defCmp
  hint = loc("guiHints/mode")
})

let optMonitorSelection = optionCtor({
  name = loc("options/monitor", "Monitor")
  widgetCtor = mkDisableableCtor(
    Computed(@() videoModeVar.value == "windowed" ? loc("options/auto") : null),
    optionSpinner)
  tab = "Graphics"
  blkPath = "video/monitor"
  isAvailable = isOptAvailable
  defVal = availableMonitors.current
  available = availableMonitors.list
  originalVal = availableMonitors.current
  var = monitorValue
  valToString = @(v) (v == "auto") ? loc("options/auto") : get_friendly_monitor_name(v)
  isEqual = defCmp
  hint = loc("guiHints/monitor")
})

videoModeVar.subscribe(function(val){
  if (["fullscreenwindowed", "fullscreen"].indexof(val)!=null)
    resolutionValue("auto")
  else
    monitorValue("auto")
})

let normalize_res_string = @(res) typeof res == "string" ? res.replace(" ", "") : res

let optResolution = optionCtor({
  name = loc("options/resolution")
  widgetCtor = optionCombo
  tab = "Graphics"
  originalVal = resolutionValue
  blkPath = "video/resolution"
  isAvailable = isOptAvailable
  var = resolutionValue
  defVal = resolutionValue
  available = resolutionList
  restart = !(platform.is_windows || platform.is_xboxone)
  valToString = @(v) (v == "auto") ? loc("options/auto") : "{0} x {1}".subst(v[0], v[1])
  isEqual = function(a, b) {
    if (typeof a == "string" || typeof b == "string")
      return normalize_res_string(a) == normalize_res_string(b)
    return a[0]==b[0] && a[1]==b[1]
  }
  convertForBlk = resolutionToString
  hint = loc("guiHints/resolution")
})

let optHdr = optionCtor({
  name = loc("options/hdr", "HDR")
  tab = "Graphics"
  blkPath = "video/enableHdr"
  isAvailable = isPcDx12
  widgetCtor = mkDisableableCtor(
    Computed(@() is_hdr_available(monitorValue.value) ? null : "{0} ({1})".subst(loc("option/off"), loc("option/monitor_does_not_support", "Monitor doesn't support"))),
    optionCheckBox)
  defVal = false
  hint = loc("guiHints/enableHdr")
})

let hdrWatched = optHdr.var

const MIN_PAPER_WHITE_NITS = 100
const MAX_PAPER_WHITE_NITS = 1000
const PAPER_WHITE_NITS_STEP = 10
const DEF_PAPER_WHITE_NITS = 200

let optionPaperWhiteNitsSliderCtor = mkSliderWithText

let originalValPaperWhiteNits = get_setting_by_blk_path("video/paperWhiteNits") ?? DEF_PAPER_WHITE_NITS
let paperWhiteNitsVar = Watched(originalValPaperWhiteNits)

paperWhiteNitsVar.subscribe(change_paper_white_nits)

let optPaperWhiteNits = optionCtor({
  name = loc("options/paperWhiteNits", "Paper White Nits")
  tab = "Graphics"
  blkPath = "video/paperWhiteNits"
  isAvailable = is_hdr_enabled
  widgetCtor = optionPaperWhiteNitsSliderCtor
  var = paperWhiteNitsVar
  min = MIN_PAPER_WHITE_NITS
  max = MAX_PAPER_WHITE_NITS
  pageScroll = PAPER_WHITE_NITS_STEP
  step = PAPER_WHITE_NITS_STEP.tofloat()
  convertForBlk = @(v) (v < MIN_PAPER_WHITE_NITS || v > MAX_PAPER_WHITE_NITS) ? DEF_PAPER_WHITE_NITS : (v).tointeger()
  hint = loc("guiHints/paperWhiteNits")
})

let optVsync = optionCtor({
  name = loc("options/vsync")
  tab = "Graphics"
  isAvailable = isOptAvailable
  widgetCtor = mkDisableableCtor(
    Computed(@() lowLatencyValue.value != LOW_LATENCY_NV_ON && lowLatencyValue.value != LOW_LATENCY_NV_BOOST ? null
                   : "{0} ({1})".subst(loc("option/off"), loc("option/off_by_reflex"))),
    optionCheckBox)
  restart = !platform.is_windows
  blkPath = "video/vsync"
  defVal = false
  hint = loc("guiHints/vsync")
})

let optFpsLimit = optionCtor({
  name = loc("options/fpsLimit")
  tab = "Graphics"
  isAvailable = isOptAvailable
  widgetCtor = optionCombo
  blkPath = "video/fpsLimit"
  defVal = UNLIMITED_FPS_LIMIT
  available = fpsList
  restart = false
  valToString = @(v) (v == UNLIMITED_FPS_LIMIT) ? loc("option/off") : loc("options/fpsLimit/hertz", { value = v })
  convertForBlk = @(v) (v == UNLIMITED_FPS_LIMIT) ? 0 : floor(v + 0.5).tointeger()
  convertFromBlk = @(v) (v == 0) ? UNLIMITED_FPS_LIMIT : v
  hint = loc("guiHints/fpsLimit")
})

let optLatency = optionCtor({
  name = loc("option/latency", "NVIDIA Reflex Low Latency")
  tab = "Graphics"
  widgetCtor = mkDisableableCtor(
    Computed(@() isBareMinimum.value ?
                 loc("option/off") :
                 (lowLatencySupported.value ?
                   (dlssgValue.value > 0 ?
                     "{0} ({1})".subst(loc("option/nv_boost"), loc("option/forced_by_frame_generation")) :
                     null) :
                   "{0} ({1})".subst(loc("option/off"), loc("option/unavailable")))),
    optionSpinner)
  isAvailable = isOptAvailable
  blkPath = LOW_LATENCY_BLK_PATH
  defVal = LOW_LATENCY_OFF
  var = lowLatencyValue
  setValue = lowLatencySetValue
  available = lowLatencyAvailable
  valToString = @(v) loc(lowLatencyToString[v])
  hint = loc("guiHints/latency")
})
let isDevBuild = @() platform.is_pc && DBGLEVEL != 0
let optPerformanceMetrics = optionCtor({
  name = loc("options/perfMetrics", "Performance Metrics")
  tab = "Graphics"
  widgetCtor = optionSpinner
  isAvailable = isOptAvailable
  blkPath = PERF_METRICS_BLK_PATH
  defVal = PERF_METRICS_FPS
  var = perfMetricsValue
  setValue = perfMetricsSetValue
  available = perfMetricsAvailable
  valToString = @(v) loc(perfMetricsToString[v])
  hint = loc("guiHints/perfMetrics")
})
let optShadowsQuality = optionCtor({
  name = loc("options/shadowsQuality", "Shadow Quality")
  widgetCtor = mkDisableableCtor(bareLowText, optionSpinner)
  tab = "Graphics"
  isAvailable = isOptAvailable
  blkPath = "graphics/shadowsQuality"
  defVal = "low"
  available = [ "low", "medium", "high", "ultra" ]
  restart = false
  valToString = loc_opt
  isEqual = defCmp
  getMoreBlkSettings = function(val){
    return [
      {blkPath = "graphics/dynamicShadowsQuality", val = val}
    ]
  }
  hint = loc("guiHints/shadowsQuality")
})
let optEffectsShadows = optionCtor({
  name = loc("options/effectsShadows", "Shadows from Effects")
  tab = "Graphics"
  isAvailable = isOptAvailable
  widgetCtor = mkDisableableCtor(bareOffText, optionCheckBox)
  blkPath = "graphics/effectsShadows"
  defVal = true
  restart = false
  hint = loc("guiHints/effectsShadows")
})


let giLowText = Computed(@() (isBareMinimum.value || is_only_low_gi_supported()) ? loc("option/low") : null)

let optGiAlgorithm = optionCtor({
  name = loc("options/giAlgorithm")
  widgetCtor = mkDisableableCtor(giLowText, optionSpinner)
  tab = "Graphics"
  isAvailable = isOptAvailable
  blkPath = "graphics/giAlgorithm"
  available = [ "low", "medium", "high" ]
  defVal = "medium"
  restart = false
  valToString = loc_opt
  hint = loc("guiHints/giAlgorithm")
})


let optGiAlgorithmQuality = optionCtor({
  name = loc("options/giAlgorithmQuality")
  widgetCtor = mkDisableableCtor(giLowText, optionSlider)
  tab = "Graphics"
  isAvailable = isOptAvailable
  blkPath = "graphics/giAlgorithmQuality"
  defVal = 1.0
  min = 0.0 max = 1.0 unit = 0.1 pageScroll = 0.1
  restart = false
  hint = loc("guiHints/giAlgorithmQuality")
})

let optSkiesQuality = optionCtor({
  name = loc("options/skiesQuality", "Atmospheric Scattering Quality")
  widgetCtor = mkDisableableCtor(bareLowText, optionSpinner)
  tab = "Graphics"
  isAvailable = isOptAvailable
  blkPath = "graphics/skiesQuality"
  defVal = "medium"
  available = [ "low", "medium", "high" ]
  restart = false
  valToString = loc_opt
  hint = loc("guiHints/skiesQuality")
})

let optSsaoQuality = optionCtor({
  name = loc("options/ssaoQuality", "Ambient Occlusion Quality")
  widgetCtor = mkDisableableCtor(bareOffText, optionSpinner)
  tab = "Graphics"
  isAvailable = isOptAvailable
  blkPath = "graphics/aoQuality"
  available = [ "low", "medium", "high" ]
  valToString = loc_opt
  defVal = "medium"
  restart = false
  isEqual = defCmp
  hint = loc("guiHints/aoQuality")
})
let optObjectsDistanceMul = optionCtor({
  name = loc("options/objectsDistanceMul")
  widgetCtor = optionSlider
  isAvailable = isDevBuild
  tab = "Graphics"
  blkPath = "graphics/objectsDistanceMul"
  defVal = 1.0
  min = 0.0 max = 1.5 unit = 0.05 pageScroll = 0.05
  restart = false
  getMoreBlkSettings = function(val){
    return [
      {blkPath = "graphics/rendinstDistMul", val = val},
      {blkPath = "graphics/riExtraMulScale", val = val}
    ]
  }
})

let optCloudsQuality = optionCtor({
  name = loc("options/cloudsQuality", "Clouds Quality")
  blkPath = "graphics/cloudsQuality"
  widgetCtor = mkDisableableCtor(bareLowText, optionSpinner)
  defVal = "default"
  tab = "Graphics"
  isAvailable = isOptAvailable
  available = [ "default", "highres", "volumetric" ]
  restart = false
  valToString = loc_opt
  isEqual = defCmp
  hint = loc("guiHints/cloudsQuality")
})

let optVolumeFogQuality = optionCtor({
  name = loc("options/volumeFogQuality", "Fog Distance")
  widgetCtor = mkDisableableCtor(bareLowText, optionSpinner)
  tab = "Graphics"
  isAvailable = isOptAvailable
  blkPath = "graphics/volumeFogQuality"
  defVal = "medium"
  available = [ "close", "medium", "far" ]
  restart = false
  valToString = loc_opt
  isEqual = defCmp
  hint = loc("guiHints/volumeFogQuality")
})

let optWaterQuality = optionCtor({
  name = loc("options/waterQuality", "Water Quality")
  widgetCtor = mkDisableableCtor(bareLowText, optionSpinner)
  tab = "Graphics"
  isAvailable = isOptAvailable
  blkPath = "graphics/waterQuality"
  defVal = "low"
  available = [ "low", "medium", "high" ]
  restart = false
  valToString = loc_opt
  isEqual = defCmp
  hint = loc("guiHints/waterQuality")
})

let optGroundDisplacementQuality = optionCtor({
  name = loc("options/groundDisplacementQuality", "Terrain Tessellation Quality")
  widgetCtor = mkDisableableCtor(bareLowText, optionSpinner)
  tab = "Graphics"
  isAvailable = isOptAvailable
  blkPath = "graphics/groundDisplacementQuality"
  defVal = 1
  available = [ 0, 1, 2 ]
  restart = false
  valToString = loc_opt
  isEqual = defCmp
  hint = loc("guiHints/groundDisplacementQuality")
})

let optRendinstTesselation = optionCtor({
  name = loc("options/rendinstTesselation", "Object Tessellation")
  tab = "Graphics"
  isAvailable = @() (isOptAvailable() && is_rendinst_tessellation_supported())
  widgetCtor = mkDisableableCtor(bareOffText, optionCheckBox)
  blkPath = "graphics/rendinstTesselation"
  defVal = true
  restart = false
  hint = loc("guiHints/rendinstTesselation")
})

let optGroundDeformations = optionCtor({
  name = loc("options/groundDeformations", "Dynamic Terrain Deformations")
  widgetCtor = mkDisableableCtor(bareOffText, optionSpinner)
  tab = "Graphics"
  isAvailable = isDevBuild
  blkPath = "graphics/groundDeformations"
  defVal = "off"
  available = [ "off", "low", "medium", "high" ]
  restart = false
  valToString = loc_opt
  isEqual = defCmp
  hint = loc("guiHints/groundDeformations")
})

let optImpostor = optionCtor({
  name = loc("options/impostor", "Impostor quality")
  widgetCtor = optionSpinner
  isAvailable = isDevBuild
  tab = "Graphics"
  blkPath = "graphics/impostor"
  defVal = 0
  available = [ 0, 1, 2 ]
  restart = false
  valToString = loc_opt
  isEqual = defCmp
})

enum antiAliasingMode {
  OFF = 0
  FXAA = 1,
  TSR = 3,
  DLSS = 4,
  SSAA = 8
};

let antiAliasingModeToString = {
  [antiAliasingMode.OFF]  = { optName = "option/off",  defLocString = "Off" },
  [antiAliasingMode.FXAA] = { optName = "option/fxaa", defLocString = "FXAA" },
  [antiAliasingMode.TSR]  = { optName = "option/tsr",  defLocString = "Temporal Super Resolution" },
  [antiAliasingMode.DLSS] = { optName = "option/dlss", defLocString = "NVIDIA DLSS" },
  [antiAliasingMode.SSAA] = { optName = "options/optSSAA", defLocString = "SSAA" },
}

let antiAliasingModeDefault = Computed(@() platform.is_nswitch || isBareMinimum.value ? antiAliasingMode.FXAA : antiAliasingMode.TSR)
let antiAliasingModeChosen = Watched(get_setting_by_blk_path("video/antiAliasingMode") ?? antiAliasingModeDefault.value)
let antiAliasingModeSetValue = @(v) antiAliasingModeChosen(v)
let antiAliasingModeAvailable = Computed(@() [ platform.is_nswitch ? antiAliasingMode.OFF : null,
                                               antiAliasingMode.FXAA,
                                               !platform.is_nswitch ? antiAliasingMode.TSR : null,
                                               dlssNotAllowLocId.get() == null && !is_vulkan() ? antiAliasingMode.DLSS : null,
                                               antiAliasingMode.SSAA
                                              ].filter(@(q) q != null))
let antiAliasingModeValue = Computed(@() isBareMinimum.value ? antiAliasingMode.FXAA : (antiAliasingModeAvailable.value.contains(antiAliasingModeChosen.value) ?
                                                                                        antiAliasingModeChosen.value :
                                                                                        antiAliasingModeDefault.value))

let optAntiAliasingMode = optionCtor({
  name = loc("options/antiAliasingMode", "Anti-aliasing Mode")
  widgetCtor = mkDisableableCtor(Computed(@() isBareMinimum.value ? loc("option/fxaa", "FXAA") : null), optionSpinner)
  tab = "Graphics"
  originalVal = antiAliasingModeValue
  blkPath = "video/antiAliasingMode"
  isAvailable = @() platform.is_pc || platform.is_nswitch
  var = antiAliasingModeValue
  defVal = antiAliasingModeDefault
  available = antiAliasingModeAvailable
  valToString = @(v) loc(antiAliasingModeToString[v].optName, antiAliasingModeToString[v].defLocString)
  setValue = antiAliasingModeSetValue
  hint = loc("guiHints/antiAliasingMode")
  getMoreBlkSettings = function(v){
    return [
      {blkPath = "video/overrideAAforAutoResolution", val = v == 3},
    ]
  }
})

function is_dlss_selected() {
  let nvidia_app_id = dgs_get_settings()?["nvidia_app_id"]
  if (nvidia_app_id == 231313132) {
    logerr($"Game is using nVidia sample app ID: {nvidia_app_id}! Make sure to get a proper app ID before release!")
  }

  return true
}

let optDlss = optionCtor({
  name = loc("options/dlssQuality", "NVIDIA DLSS Quality")
  tab = "Graphics"
  widgetCtor = mkDisableableCtor(
    Computed(@() dlssNotAllowLocId.value == null ? null : "{0} ({1})".subst(loc("option/off"), loc(dlssNotAllowLocId.value))),
    optionSpinner)
  isAvailableWatched = Computed(@() isOptAvailable() && antiAliasingModeValue.value == antiAliasingMode.DLSS && is_dlss_selected())
  blkPath = DLSS_BLK_PATH
  defVal = DLSS_OFF
  var = dlssValue
  setValue = dlssSetValue
  available = dlssAvailable
  valToString = @(v) loc(dlssToString[v])
  hint = loc("guiHints/dlssQuality")
})


let optDlssFrameGeneration = optionCtor({
  name = loc("options/dlssFrameGeneration", "Frame Generation")
  blkPath = DLSSG_BLK_PATH
  widgetCtor = mkDisableableCtor(
    Computed(@() dlssgNotAllowLocId.value == null ? null : "{0} ({1})".subst(loc("option/off"), loc(dlssgNotAllowLocId.value))),
    optionSpinner)
  defVal = DLSSG_OFF
  tab = "Graphics"
  isAvailableWatched = Computed(@() isOptAvailable() && isPcDx12() && antiAliasingModeValue.value == antiAliasingMode.DLSS)
  var = dlssgValue
  setValue = dlssgSetValue
  available = dlssgAvailable
  valToString = @(v) loc(dlssgToString[v])
  hint = loc("guiHints/dlssFrameGeneration")
})

const TSR_QUALITY_BLK_PATH = "graphics/tsrQuality"
const TSR_QUALITY_LOW = 0
const TSR_QUALITY_HIGH = 1
let tsrQualityValue = Watched(get_setting_by_blk_path(TSR_QUALITY_BLK_PATH) ?? TSR_QUALITY_HIGH)

let optTemporalUpsamplingRatio = optionCtor({
  name = loc("options/temporal_upsampling_ratio", "Temporal Resolution Scale")
  tab = "Graphics"
  isAvailableWatched = Computed(@() isOptAvailable() && resolutionValue.value != "auto" && antiAliasingModeValue.value == antiAliasingMode.TSR && tsrQualityValue.value == TSR_QUALITY_HIGH)
  widgetCtor = optionPercentTextSliderCtor
  blkPath = "video/temporalUpsamplingRatio"
  defVal = 100.0
  min = 50.0
  max = 100.0
  unit = 5.0/100.0
  pageScroll = 5.0
  restart = false
  hint = loc("guiHints/temporal_upsampling_ratio")
})

let optStaticResolutionScale = optionCtor({
  name = loc("options/static_resolution_scale", "Static Resolution Scale")
  tab = "Graphics"
  isAvailableWatched = Computed(@() isOptAvailable() && isBareMinimum.value)
  widgetCtor = optionPercentTextSliderCtor
  blkPath = "video/staticResolutionScale"
  defVal = 100.0
  min = 50.0
  max = 100.0
  unit = 5.0/50.0
  pageScroll = 5.0
  restart = false
  hint = loc("guiHints/static_resolution_scale")
})

let optGammaCorrection = optionCtor({
  name = loc("options/gamma_correction", "Gamma correction")
  tab = "Graphics"
  isAvailable = @() !is_hdr_enabled()
  widgetCtor = optionPercentTextSliderCtor
  blkPath = "graphics/gamma_correction"
  var = gammaCorrectionSave.watch
  setValue = function(v) {
      gammaCorrectionSave.setValue(v)
      change_gamma(v)
    }
  defVal = 1.0
  min = 0.5 max = 1.5 unit = 0.05 pageScroll = 0.05
  restart = false
  hint = loc("guiHints/gamma_correction")
  valToString = @(v) v
})

let optTexQuality = optionCtor({
  name = loc("options/texQuality")
  widgetCtor = mkDisableableCtor(bareLowText, optionSpinner)
  isAvailable = isOptAvailable
  tab = "Graphics"
  blkPath = "graphics/texquality"
  defVal = "high"
  available = ["low", "medium", "high"]
  restart = true
  valToString = loc_opt
  isEqual = defCmp
  hint = loc("guiHints/texQuality")
})

let optAnisotropy = optionCtor({
  name = loc("options/anisotropy")
  widgetCtor = mkDisableableCtor(bareOffText, optionSpinner)
  tab = "Graphics"
  isAvailable = isOptAvailable
  blkPath = "graphics/anisotropy"
  defVal = 4
  available = [1, 2, 4, 8, 16]
  restart = false
  valToString = @(v) (v==1) ? loc("option/off") : $"{v}X"
  isEqual = defCmp
  hint = loc("guiHints/anisotropy")
})

let optOnlyonlyHighResFx = optionCtor({
  name = loc("options/onlyHighResFx")
  tab = "Graphics"
  isAvailable = isOptAvailable
  widgetCtor = mkDisableableCtor(bareOffText, optionSpinner)
  defVal = "medres"
  blkPath = "graphics/fxTarget"
  available = ["lowres", "medres", "highres"]
  restart = true
  valToString = loc_opt
  hint = loc("guiHints/onlyHighResFx")
})

let optScreenSpaceWeatherEffects = optionCtor({
  name = loc("options/screenSpaceWeatherEffects")
  tab = "Graphics"
  isAvailable = @() platform.is_pc || platform.is_nswitch
  widgetCtor = mkDisableableCtor(bareOffText, optionCheckBox)
  blkPath = "graphics/screenSpaceWeatherEffects"
  defVal = true
  restart = false
  hint = loc("guiHints/screenSpaceWeatherEffects")
})

let optFXAAQuality = optionCtor({
  name = loc("options/FXAAQuality")
  tab = "Graphics"
  isAvailableWatched = Computed(@() antiAliasingModeValue.value == antiAliasingMode.FXAA)
  widgetCtor = optionSpinner
  defVal = "medium"
  blkPath = "graphics/fxaaQuality"
  available = ["low", "medium", "high"]
  restart = false
  valToString = loc_opt
  hint = loc("guiHints/FXAAQuality")
})

let optSSRQuality = optionCtor({
  name = loc("options/SSRQuality")
  tab = "Graphics"
  isAvailable = isOptAvailable
  widgetCtor = mkDisableableCtor(bareLowText, optionSpinner)
  blkPath = "graphics/ssrQuality"
  available = ["low", "medium", "high"]
  defVal = "low"
  restart = false
  valToString = loc_opt
  hint = loc("guiHints/SSRQuality")
})

let optScopeImageQuality = optionCtor({
  name = loc("options/scopeImageQuality", "Scope Image Quality")
  tab = "Graphics"
  isAvailable = isOptAvailable
  widgetCtor = mkDisableableCtor(bareLowText, optionSpinner)
  blkPath = "graphics/scopeImageQuality"
  defVal = 0
  available = [0, 1, 2, 3]
  valToString = loc_opt
  restart = false
  isEqual = defCmp
  hint = loc("guiHints/scopeImageQuality")
})

const SCREENSHOT_FORMAT_BLK_PATH = "screenshots/format"
const SCREENSHOT_FORMAT_JPEG = "jpeg"
const SCREENSHOT_FORMAT_TGA = "tga"
const SCREENSHOT_FORMAT_PNG = "png"
const SCREENSHOT_FORMAT_EXR = "exr"

let screenshotFormatAvailable = Computed(@() is_hdr_available(monitorValue.value) && hdrWatched.value ?
                                [SCREENSHOT_FORMAT_JPEG, SCREENSHOT_FORMAT_PNG, SCREENSHOT_FORMAT_TGA, SCREENSHOT_FORMAT_EXR] :
                                [SCREENSHOT_FORMAT_JPEG, SCREENSHOT_FORMAT_PNG, SCREENSHOT_FORMAT_TGA])

let screenshotFormatValueChosen = Watched(get_setting_by_blk_path(SCREENSHOT_FORMAT_BLK_PATH) ?? SCREENSHOT_FORMAT_JPEG)

let screenshotFormatSetValue = @(v) screenshotFormatValueChosen(v)

let screenshotFormatValue = Computed(@() screenshotFormatAvailable.value.indexof(screenshotFormatValueChosen.value) != null
  ? screenshotFormatValueChosen.value : SCREENSHOT_FORMAT_JPEG)

let optScreenshotFormat = optionCtor({
  optId = "screenshotFormat"
  name = loc("options/screenshotFormat")
  blkPath = SCREENSHOT_FORMAT_BLK_PATH
  widgetCtor = optionSpinner
  defVal = SCREENSHOT_FORMAT_JPEG
  tab = "Graphics"
  isAvailable = isOptAvailable
  restart = false
  var = screenshotFormatValue
  setValue = screenshotFormatSetValue
  available = screenshotFormatAvailable
  valToString = loc_opt
  hint = loc("guiHints/screenshotFormat")
})

let optFSR = optionCtor({
  name = loc("options/optFSR", "AMD FidelityFX Super Resolution 1.0")
  tab = "Graphics"
  isAvailableWatched = Computed(@() isOptAvailable() && (antiAliasingModeValue.value == antiAliasingMode.TSR && tsrQualityValue.value == TSR_QUALITY_LOW))
  widgetCtor = mkDisableableCtor(bareOffText, optionSpinner)
  defVal = "off"
  blkPath = "video/fsr"
  available = ["off", "ultraquality", "quality", "balanced", "performance"]
  restart = false
  valToString = loc_opt
  hint = loc("guiHints/optFSR")
})

let optFFTWaterQuality = optionCtor({
  name = loc("options/fft_water_quality", "Water Ripples Quality")
  tab = "Graphics"
  isAvailable = isOptAvailable
  widgetCtor = mkDisableableCtor(bareLowText, optionSpinner)
  defVal = "high"
  blkPath = "graphics/fftWaterQuality"
  available = ["low", "medium", "high", "ultra"]
  restart = false
  valToString = loc_opt
  hint = loc("guiHints/fft_water_quality")
})

let optEnvironmentDetailQuality = optionCtor({
  name = loc("options/environment_detail_quality", "Environment Detail")
  tab = "Graphics"
  isAvailable = isOptAvailable
  widgetCtor = mkDisableableCtor(bareLowText, optionSpinner)
  defVal = "low"
  blkPath = "graphics/environmentDetailsQuality"
  available = ["low", "high"]
  restart = false
  valToString = loc_opt
  hint = loc("guiHints/environment_detail_quality")
})

let optHQProbeReflections = optionCtor({
  name = loc("options/HQProbeReflections")
  tab = "Graphics"
  isAvailable = @() platform.is_pc
  widgetCtor = mkDisableableCtor(bareOffText, optionCheckBox)
  blkPath = "graphics/HQProbeReflections"
  defVal = true
  restart = false
  hint = loc("guiHints/HQProbeReflections")
})

let optHQVolumetricClouds = optionCtor({
  name = loc("options/HQVolumetricClouds")
  tab = "Graphics"
  isAvailable = @() platform.is_pc
  widgetCtor = mkDisableableCtor(bareOffText, optionCheckBox)
  defVal = false
  blkPath = "graphics/HQVolumetricClouds"
  restart = false
  hint = loc("guiHints/HQVolumetricClouds")
})

let optHQVolfog= optionCtor({
  name = loc("options/HQVolfog")
  tab = "Graphics"
  isAvailable = @() platform.is_pc
  widgetCtor = mkDisableableCtor(bareOffText, optionCheckBox)
  defVal = false
  blkPath = "graphics/HQVolfog"
  restart = false
  hint = loc("guiHints/HQVolfog")
})

let optSSSS = optionCtor({
  name = loc("options/ssss")
  tab = "Graphics"
  isAvailable = isOptAvailable
  widgetCtor = mkDisableableCtor(bareOffText, optionSpinner)
  defVal = "low"
  blkPath = "graphics/ssssQuality"
  available = ["off", "low",  "high"]
  restart = false
  valToString = loc_opt
  hint = loc("guiHints/ssss")
})

let optChromaticAberration = optionCtor({
  name = loc("options/chromaticAberration")
  tab = "Graphics"
  isAvailable = @() true
  defVal = false
  blkPath = "graphics/chromaticAberration"
  widgetCtor = optionCheckBox
  restart = false
  hint = loc("guiHints/chromaticAberration")
})

let optFilmGrain = optionCtor({
  name = loc("options/filmGrain")
  tab = "Graphics"
  isAvailable = @() true
  defVal = false
  blkPath = "graphics/filmGrain"
  widgetCtor = optionCheckBox
  restart = false
  hint = loc("guiHints/filmGrain")
})

let optMotionBlur = optionCtor({
  name = loc("options/motionBlur")
  tab = "Graphics"
  isAvailable = @() true
  defVal = 0.0
  blkPath = "graphics/motionBlurStrength"
  widgetCtor = optionPercentTextSliderCtor
  min = 0.0
  max = 100.0
  unit = 5.0/50.0
  pageScroll = 5.0
  restart = false
  hint = loc("guiHints/motionBlur")
})

let wasSSAAWarningShown  = nestWatched("wasSSAAWarningShown", false)
let wasSSAAWarningShownUpdate = @(v) wasSSAAWarningShown.set(v)

antiAliasingModeValue.subscribe(function(mode) {
  if (!wasSSAAWarningShown.value && mode == antiAliasingMode.SSAA) {
    wasSSAAWarningShownUpdate(true)
    showMsgbox({text=loc("settings/ssaa_warning")})
  }
})

return {
  resolutionToString
  optResolution
  optSafeArea
  optVideoMode
  optMonitorSelection
  optHdr
  optPaperWhiteNits
  optPerformanceMetrics
  optLatency
  optVsync
  optFpsLimit
  optShadowsQuality
  optEffectsShadows
  optGiAlgorithm
  optGiAlgorithmQuality
  optSkiesQuality
  optSsaoQuality
  optObjectsDistanceMul
  optCloudsQuality
  optVolumeFogQuality
  optWaterQuality
  optGroundDisplacementQuality
  optRendinstTesselation
  optGroundDeformations
  optImpostor
  optGammaCorrection
  optTexQuality
  optAnisotropy
  optOnlyonlyHighResFx
  optScreenSpaceWeatherEffects
  optSSRQuality
  optScopeImageQuality
  optScreenshotFormat
  optDlss
  optTemporalUpsamplingRatio
  optStaticResolutionScale
  optFSR
  optFFTWaterQuality
  optEnvironmentDetailQuality
  optHQProbeReflections
  optSSSS
  optAntiAliasingMode
  optHQVolumetricClouds
  optHQVolfog

  renderOptions = [
    optSafeArea,

    
    {name = loc("group/display", "Display") isSeparator=true tab="Graphics"},
    optResolution,
    optVideoMode,
    optMonitorSelection,
    optHdr,
    optPaperWhiteNits,
    optGammaCorrection,
    optPerformanceMetrics,
    optLatency,
    optVsync,
    optFpsLimit,

    
    {name = loc("group/antialiasing", "Antialiasing") isSeparator=true tab="Graphics"},
    optAntiAliasingMode,
    optTemporalUpsamplingRatio,
    optStaticResolutionScale,
    optFXAAQuality,
    optFSR,
    optDlss,
    optDlssFrameGeneration,

    
    {name = loc("group/shadows_n_lighting", "Shadows & Lighting") isSeparator=true tab="Graphics"},
    optShadowsQuality,
    optEffectsShadows,

    
    optGiAlgorithm,
    optGiAlgorithmQuality,
    optSkiesQuality,
    optSsaoQuality,
    optSSRQuality,
    optHQProbeReflections,
    optSSSS,

    {name = loc("group/details_n_textures", "Details & Textures") isSeparator=true tab="Graphics"},
    
    optTexQuality,
    optAnisotropy,
    
    optCloudsQuality,
    optVolumeFogQuality,
    optWaterQuality,
    optFFTWaterQuality,
    optEnvironmentDetailQuality,
    optGroundDisplacementQuality,
    optRendinstTesselation,
    optGroundDeformations,
    optOnlyonlyHighResFx,
    optScopeImageQuality,

    
    {name = loc("group/postfx_effects", "Postfx effects") isSeparator=true tab="Graphics"},
    optScreenSpaceWeatherEffects,
    optChromaticAberration,
    optFilmGrain,
    optMotionBlur,

    
    {name = loc("group/other", "Other")
     isSeparator=true
     tab="Graphics"
     isAvailable = optScreenshotFormat.isAvailable },  
    optScreenshotFormat,

    
    {name = "Dev options" isSeparator=true tab="Graphics" isAvailable = isDevBuild },
    optImpostor,
    optObjectsDistanceMul,

    
    { name = loc("group/advanced", "Advanced options"), isSeparator = true, tab = "Graphics" },
    optHQVolumetricClouds,
    optHQVolfog,
  ]
}

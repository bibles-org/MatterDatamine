from "settings" import get_setting_by_blk_path
from "videomode" import get_low_latency_modes, is_nvidia_gpu, is_amd_gpu, is_intel_gpu

from "%ui/ui_library.nut" import *


const LOW_LATENCY_BLK_PATH__NVIDIA = "video/nvidia_latency"
const LOW_LATENCY_BLK_PATH__AMD = "video/amd_latency"
const LOW_LATENCY_BLK_PATH__INTEL = "video/intel_latency"


const LOW_LATENCY_OFF = 0
const LOW_LATENCY_ON = 1
const LOW_LATENCY_NV_BOOST = 2

let lowLatencyToString = static {
  [LOW_LATENCY_OFF] = "option/off",
  [LOW_LATENCY_ON] = "option/on",
  [LOW_LATENCY_NV_BOOST] = "option/nv_boost",
}

let lowLatencyAvailable = WatchedRo(function() {
  let supportedModes = get_low_latency_modes()
  let ret = [LOW_LATENCY_OFF]
  if (supportedModes & LOW_LATENCY_ON)
    ret.append(LOW_LATENCY_ON)
  if ((supportedModes & LOW_LATENCY_NV_BOOST) && is_nvidia_gpu())
    ret.append(LOW_LATENCY_NV_BOOST)
  return ret
}())

let lowLatencySupported = WatchedRo(get_low_latency_modes() > 0)

let lowLatencyValueChosen_NV = Watched(get_setting_by_blk_path(LOW_LATENCY_BLK_PATH__NVIDIA))
let lowLatencyValueChosen_AMD = Watched(get_setting_by_blk_path(LOW_LATENCY_BLK_PATH__AMD))
let lowLatencyValueChosen_Intel = Watched(get_setting_by_blk_path(LOW_LATENCY_BLK_PATH__INTEL))

let lowLatencySetValue_NV = @(v) lowLatencyValueChosen_NV.set(v)
let lowLatencySetValue_AMD = @(v) lowLatencyValueChosen_AMD.set(v)
let lowLatencySetValue_Intel = @(v) lowLatencyValueChosen_Intel.set(v)

let lowLatencyValue_NV = Computed(@() lowLatencyAvailable.get().indexof(lowLatencyValueChosen_NV.get()) != null
  ? lowLatencyValueChosen_NV.get() : LOW_LATENCY_OFF)
let lowLatencyValue_AMD = Computed(@() lowLatencyAvailable.get().indexof(lowLatencyValueChosen_AMD.get()) != null
  ? lowLatencyValueChosen_AMD.get() : LOW_LATENCY_OFF)
let lowLatencyValue_Intel = Computed(@() lowLatencyAvailable.get().indexof(lowLatencyValueChosen_Intel.get()) != null
  ? lowLatencyValueChosen_Intel.get() : LOW_LATENCY_OFF)

function isVsyncEnabledFromLowLatency(low_latency_mode_nv) {
  if (is_nvidia_gpu()) {
    
    return low_latency_mode_nv == LOW_LATENCY_OFF
  }
  if (is_amd_gpu()) {
    
    return true
  }
  if (is_intel_gpu()) {
    
    return true
  }
  return true
}

return freeze({
  LOW_LATENCY_BLK_PATH__NVIDIA
  LOW_LATENCY_BLK_PATH__AMD
  LOW_LATENCY_BLK_PATH__INTEL
  LOW_LATENCY_OFF
  LOW_LATENCY_ON
  LOW_LATENCY_NV_BOOST
  lowLatencyAvailable
  lowLatencyValue_NV
  lowLatencyValue_AMD
  lowLatencyValue_Intel
  lowLatencySetValue_NV
  lowLatencySetValue_AMD
  lowLatencySetValue_Intel
  lowLatencyToString
  lowLatencySupported
  isVsyncEnabledFromLowLatency
})
from "%sqGlob/dasenums.nut" import ExtractionStatusForHero

from "%ui/fonts_style.nut" import tiny_txt
import "%ui/hud/map/map_hover_hint.nut" as mapHoverableMarker
from "%ui/components/colors.nut" import MapIconEnable, RedWarningColor, MapIconInner, MapIconHover, MapIconDisable, MapIconInactive
from "%ui/helpers/timers.nut" import mkCountdownTimerPerSec
from "%ui/components/cursors.nut" import setTooltip
from "%ui/components/commonComponents.nut" import mkText
from "%ui/helpers/time.nut" import secondsToStringLoc

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { hudIsInteractive } = require("%ui/hud/state/interactive_state.nut")
let { isOnPlayerBase } = require("%ui/hud/state/gametype_state.nut")


let extractionSize = [hdpxi(14), hdpxi(18)]
let extractionPicture = {
  rendObj = ROBJ_IMAGE
  hplace = ALIGN_CENTER
  vplace = ALIGN_BOTTOM
  image = Picture($"ui/skin#extraction_man.svg:{extractionSize[0]}:{extractionSize[1]}:P")
  color = MapIconInner
  size = extractionSize
}

let extractionIcon = freeze({
  rendObj = ROBJ_BOX
  borderWidth = hdpxi(1)
  borderColor = MapIconInner
  size = static [hdpxi(16), hdpxi(21)]
  children = extractionPicture
  fillColor = MapIconEnable
})

let extractionPointsInfo = Watched({})
ecs.register_es("track_extraction_points",
  {
    [["onInit","onChange"]] = @(eid, comp) extractionPointsInfo.mutate(@(v) v[eid] <- {
        eid,
        transform = comp.transform,
        enableTime = comp.extraction_enable_time__at,
        disableTime = comp.extraction_disable_time__at,
        statusForHero = comp.extraction__statusForHero
        showAsInactive = comp.extraction__currentState == 0 && comp.extraction__forceMapVisible
        
    }),
    onDestroy = @(eid, _comp) extractionPointsInfo.mutate(@(v) v?.rawdelete(eid))
  },
  {
    comps_track = [
      ["extraction__statusForHero", ecs.TYPE_INT],
      ["extraction__currentState", ecs.TYPE_INT, 0],
      ["extraction__forceMapVisible", ecs.TYPE_BOOL, false],
      ["extraction_enable_time__at", ecs.TYPE_FLOAT, -10.0],
      ["extraction_disable_time__at", ecs.TYPE_FLOAT, -10.0],
    ]
    comps_ro = [
      ["transform", ecs.TYPE_MATRIX],
    ]
    comps_rq = ["extraction__hudPoint"]
  }
)

let extractionPoint = function(data, transform){
  let pos = data.transform.getcol(3)

  let disabled = (data.statusForHero != ExtractionStatusForHero.OK) || (data?.showAsInactive ?? false)
  let isLockedByContract = data?.statusForHero == ExtractionStatusForHero.PRIMARY_CONTRACT_NOT_COMPLETED
  let freeExtractionIcon = @(sf) @() extractionIcon.__merge({
    watch = sf
    fillColor = sf.get() & S_HOVER ? MapIconHover
      : isLockedByContract ? RedWarningColor
      : disabled ? MapIconInactive
      : MapIconEnable
  })

  let timerExtractionIcon = @(sf, isExtractionEnabled) @() {
    watch = [sf, isExtractionEnabled]
    children = extractionIcon.__merge({
    fillColor = sf.get() & S_HOVER ? MapIconHover
      : isLockedByContract ? RedWarningColor
      : disabled ? MapIconInactive
      : isExtractionEnabled.get() ? MapIconEnable
      : MapIconDisable})
  }

  function timerExtractionEnabledAtBlock(sf) {
    let { enableTime = 0, spawnGroups = [] } = data
    local timer = Watched(0)
    if (isEqual(spawnGroups, [1]) && isOnPlayerBase.get())
      timer = Watched(420)
    else
      timer = mkCountdownTimerPerSec(Watched(enableTime))
    let isExtractionEnabled = Computed(@() timer.get() <= 0)
    return @() {
      watch = isOnPlayerBase
      flow = FLOW_VERTICAL
      halign = ALIGN_CENTER
      children = [
        timerExtractionIcon(sf, isExtractionEnabled)
        function() {
          let watch = timer
          if (timer.get() <= 0)
            return { watch }
          return {
            watch = [hudIsInteractive, timer]
            rendObj = ROBJ_WORLD_BLUR_PANEL
            size = timer.get() > 60 && !isOnPlayerBase.get()
              ? [hdpx(65), SIZE_TO_CONTENT]
              : [hdpx(34), SIZE_TO_CONTENT]
            halign = ALIGN_CENTER
            onHover = @(on) setTooltip( on ? loc("hint/extractionTimer") : null)
            behavior = hudIsInteractive.get() ? Behaviors.Button : null
            children = mkText(secondsToStringLoc(timer.get().tointeger()), tiny_txt)
          }
        }
      ]
    }
  }

  function timerExtractionDisabledAtBlock(sf) {
    let { eid, disableTime = 0 } = data
    local timer = Watched(0)
    timer = mkCountdownTimerPerSec(Watched(disableTime), eid)
    let isExtractionEnabled = Computed(@() timer.get() > 0)
    return @() {
      watch = isOnPlayerBase
      flow = FLOW_VERTICAL
      halign = ALIGN_CENTER
      children = [
        timerExtractionIcon(sf, isExtractionEnabled)
        function() {
          let watch = timer
          if (timer.get() <= 0)
            return { watch }
          return {
            watch = [hudIsInteractive, timer]
            rendObj = ROBJ_WORLD_BLUR_PANEL
            size = timer.get() > 60 && !isOnPlayerBase.get()
              ? static [hdpx(65), SIZE_TO_CONTENT]
              : static [hdpx(34), SIZE_TO_CONTENT]
            halign = ALIGN_CENTER
            onHover = @(on) setTooltip( on ? loc("hint/extractionTimer") : null)
            behavior = hudIsInteractive.get() ? Behaviors.Button : null
            children = mkText(secondsToStringLoc(timer.get().tointeger()), tiny_txt)
          }
        }
      ]
    }
  }

  local hoverLoc = ""
  if (data?.statusForHero == ExtractionStatusForHero.OK)
    hoverLoc = "hint/extractionMinimapMarker"
  else if (data?.statusForHero == ExtractionStatusForHero.WRONG_TIME)
    hoverLoc = "hint/extractionMinimapMarkerInactive"
  else if (data?.statusForHero == ExtractionStatusForHero.PRIMARY_CONTRACT_NOT_COMPLETED)
    hoverLoc = "hint/extractionMinimapMarkerBlockedByContracts"

  return mapHoverableMarker(
    { worldPos = pos, clampToBorder = false },
    transform,
    loc(hoverLoc),
    data.enableTime > 0 ? timerExtractionEnabledAtBlock
      : ((data?.disableTime ?? 0) > 0 ? timerExtractionDisabledAtBlock : freeExtractionIcon),
    static {skipDirPadNav = false}
  )
}


let mkExtractionPoints = function(extractions, transform) {
  return extractions.map(@(data) extractionPoint(data, transform))
}

return {
  extractionIcon
  extractionPointsInfo
  mkExtractionPoints
  extractionPoints = {
    watch = extractionPointsInfo
    ctor = @(p) mkExtractionPoints(extractionPointsInfo.get().values(), p?.transform ?? {})
  }
}

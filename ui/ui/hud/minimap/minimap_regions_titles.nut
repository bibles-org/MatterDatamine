from "%ui/ui_library.nut" import *

let { sub_txt } = require("%ui/fonts_style.nut")
let { Point3 } = require("dagor.math")
let { currentMapVisibleRadius } = require("%ui/hud/minimap/minimap_state.nut")
let regionsState = require("%ui/hud/state/regions_state.nut")

enum RegionTitleAlignment {
  UP,
  RIGHT,
  BOTTOM,
  LEFT,
  CENTER
}

let regionTitleAlignmentConfig = {
  [RegionTitleAlignment.UP] = {
    x = -hdpx(8),
    y = 0,
    hplace = ALIGN_CENTER,
    vplace = ALIGN_CENTER,
    calculateWorldPos = @(worldPoints) Point3(worldPoints.midX, 0, worldPoints.maxZ)
  },
  [RegionTitleAlignment.RIGHT] = {
    x = 0,
    y = 0,
    hplace = ALIGN_LEFT,
    vplace = ALIGN_CENTER,
    calculateWorldPos = @(worldPoints) Point3(worldPoints.maxX, 0, worldPoints.midZ)
  },
  [RegionTitleAlignment.BOTTOM] = {
    x = -hdpx(8),
    y = 0,
    hplace = ALIGN_CENTER,
    vplace = ALIGN_CENTER,
    calculateWorldPos = @(worldPoints) Point3(worldPoints.midX, 0, worldPoints.minZ)
  },
  [RegionTitleAlignment.LEFT] = {
    x = 0,
    y = 0,
    hplace = ALIGN_RIGHT,
    vplace = ALIGN_CENTER,
    calculateWorldPos = @(worldPoints) Point3(worldPoints.minX, 0, worldPoints.midZ)
  },
  [RegionTitleAlignment.CENTER] = {
    x = 0,
    y = 0,
    hplace = ALIGN_CENTER,
    vplace = ALIGN_CENTER,
    calculateWorldPos = @(worldPoints) Point3(worldPoints.midX, 0, worldPoints.midZ)
  }
}

let makeRegionTitles = @(regions, transform)
  regions.map(@(region) function() {
    let range = region.visibleRange
    if (range.y > 0 && (currentMapVisibleRadius.get() < range.x || currentMapVisibleRadius.get() > range.y))
      return { watch = currentMapVisibleRadius }
    let alignmentConfig = regionTitleAlignmentConfig[region.titleAlignment ?? RegionTitleAlignment.UP]

    local worldPoints = {
      minX = 99999.0
      minZ = 99999.0
      midX = 0.0
      midZ = 0.0
      maxX = -99999.0
      maxZ = -99999.0
    }

    let points = region.points

    foreach (point in points) {
      worldPoints.midX += point.x
      worldPoints.midZ += point.y

      if (point.x > worldPoints.maxX)
        worldPoints.maxX = point.x
      else if (point.x < worldPoints.minX)
        worldPoints.minX = point.x

      if (point.y > worldPoints.maxZ)
        worldPoints.maxZ = point.y
      else if (point.y < worldPoints.minZ)
        worldPoints.minZ = point.y
    }

    if (points.len() > 0) {
      worldPoints.midX /= points.len()
      worldPoints.midZ /= points.len()
    }

    return {
      watch = currentMapVisibleRadius
      data = {
        worldPos = alignmentConfig.calculateWorldPos(worldPoints) + (region.titleWorldPosOffset ?? Point3()),
        clampToBorder = false
      }
      pos = [alignmentConfig.x, alignmentConfig.y]
      size = [0, 0]
      transform
      children = {
        rendObj = ROBJ_TEXT
        color = Color(240, 240, 240)
        hplace = alignmentConfig.hplace
        vplace = alignmentConfig.vplace
        text = loc($"region/{region.name}")
        fontFx = FFT_GLOW
        fontFxColor = Color(0, 0, 0, 255)
      }
    }.__update(sub_txt)
  })

return {
  watch = regionsState
  ctor = @(p) makeRegionTitles(regionsState.value, p?.transform ?? {})
}

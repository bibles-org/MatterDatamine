from "%ui/components/colors.nut" import colorblindPalette
import "%ui/hud/map/map_hover_hint.nut" as mapHoverableMarker
from "%ui/hud/objectives/objective_components.nut" import color_common

from "%ui/ui_library.nut" import *


let objectMarkers = function(marks, transform, objectivesValue) {
  return marks.map(function(mark, eid){
    let objective = objectivesValue.findvalue(@(objective) objective?.params?.staticTargetTag.indexof(mark.objectiveTag) != null)

    let isObjective = objective != null
    let { colorIdx=null, name = "unknown" } = objective

    let hoverColor = Color(mark.hoverColor.x, mark.hoverColor.y, mark.hoverColor.z)
    let activeColor = Color(mark.activeColor.x, mark.activeColor.y, mark.activeColor.z)
    let inactiveColor = Color(mark.inactiveColor.x, mark.inactiveColor.y, mark.inactiveColor.z)

    let iconColor = mark.active ? activeColor : inactiveColor
    let objectiveColor = colorblindPalette?[colorIdx] ?? color_common
    let isComplete = mark?.complete
    let iconName = (isComplete && (mark?.icon_complete ?? "") != "")
      ? mark.icon_complete
      : (!mark.active && (mark?.icon_inactive ?? "") != "")
        ? mark.icon_inactive
        : mark.icon
    let color = isObjective ? objectiveColor : iconColor

    let icon = @(sf) @(){
      rendObj = ROBJ_IMAGE
      watch = sf
      color = sf.get() & S_HOVER ? hoverColor : color
      size = hdpxi(16)
      image = Picture("{0}:{1}:{2}".subst(iconName, hdpxi(16), hdpxi(16)))
      behavior = DngBhv.OpacityByComponent
      opacityComponentEntity = eid
      opacityComponentName = "map_object_marker__opacity"
    }

    let contractIcon = @(sf) @(){
      rendObj = ROBJ_IMAGE
      watch = sf
      color = sf.get() & S_HOVER ? hoverColor : color
      size = hdpxi(24)
      image = Picture("{0}:{1}:{2}".subst(mark.icon, hdpxi(24), hdpxi(24)))
    }

    let marker = mapHoverableMarker(
      {worldPos = mark.pos, clampToBorder = mark.clampToBorder},
      transform,
      mark.text != "" || !isObjective
        ? (isComplete && (mark?.text_complete ?? "") != "" ? loc(mark.text_complete): loc(mark.text))
        : loc($"contract/{name}"),
      !isObjective ? icon : contractIcon
    )
    return marker
  }).values()
}

return @(markersWatched, objectivesWatched){
  watch = [markersWatched, objectivesWatched]
  ctor = @(p) objectMarkers(markersWatched.get(), p?.transform ?? {}, objectivesWatched.get())
}

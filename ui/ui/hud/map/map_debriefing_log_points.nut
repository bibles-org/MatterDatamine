from "%ui/mainMenu/baseDebriefingLog.nut" import chooseLogPointIcon, scrollToLogElement
from "dagor.math" import Point3
from "%ui/components/colors.nut" import BtnBdSelected

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { logEntries, chosenLogElement, hoveredLogElement, highlightedLogElement } = require("%ui/mainMenu/debriefing/debriefing_log_state.nut")
let { logIconParams } = require("%ui/mainMenu/baseDebriefingLog.nut")

let alwaysVisibleEvents = [
  "died"
  "transformed"
  "extracted"
  "respawned"
  "encounterVisit"
]

let isAlwaysVisibleKillEvent = @(point) point.eventType == "kill" && (point?.victimType ?? "") == "militant"


let mkMapLogPoint = @(point, transform) {
  eventPassThrough = true
  stopHover = true
  behavior = Behaviors.Button
  skipDirPadNav = true
  onHover = function(v) {
    if (v) {
      hoveredLogElement.set(point.index)
      scrollToLogElement(point.index)
    } else {
      hoveredLogElement.set(null)
    }
  }
  onClick = @() chosenLogElement.set(point.index)
  transform
  data = {worldPos = Point3(point.position.x, point.position.y, point.position.z), clampToBorder = false},
  valign = ALIGN_CENTER
  halign = ALIGN_CENTER
  children = [
    highlightedLogElement.get() == point.index ? {
      rendObj = ROBJ_BOX
      borderRadius = hdpx(10)
      borderColor = BtnBdSelected
      borderWidth = hdpx(2)
      padding = hdpx(5)
      size = SIZE_TO_CONTENT
      children = {
        size = logIconParams.size
      }
      hplace = ALIGN_CENTER
      vplace = ALIGN_CENTER
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
    } : null
    chooseLogPointIcon(point)
  ]
  sound = {
    click = "ui_sounds/button_action"
    hover = "ui_sounds/button_highlight"
  }
}

function mkLogPoints(transform) {
  let visiblePoints = (logEntries.get() ?? [])
    .filter(@(point, index) index == chosenLogElement.get()
                            || index == hoveredLogElement.get()
                            || alwaysVisibleEvents.contains(point.eventType)
                            || isAlwaysVisibleKillEvent(point))
  return visiblePoints.reduce(function(acc, elem) {
    if (elem.eventType == "kill" && elem?.victimPosition != null) {
      acc.append(elem.__merge({eventType = "killPosition"}), elem.__merge({position = elem.victimPosition}))
    } else {
      acc.append(elem)
    }
    return acc
  }, []).map(@(point) mkMapLogPoint(point, transform))
}

return {
  watch = [logEntries, chosenLogElement, hoveredLogElement, highlightedLogElement]
  ctor = @(p) mkLogPoints(p?.transform)
}

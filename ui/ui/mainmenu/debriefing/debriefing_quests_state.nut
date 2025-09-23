from "%sqstd/json.nut" import parse_json
from "dagor.math" import Point3
from "base64" import decodeString
from "%ui/hud/objectives/objectives.nut" import dispatchColorsAndSort
from "%ui/ui_library.nut" import *



let debriefingObjectives = Watched([])
let debriefingObjectiveZones = Watched({})
let debriefingObjectiveMarkers = Watched({})

let getDebriefingObjectives = function(visuals) {
  let objectives = []
  foreach(visualData in visuals) {
    if (visualData.objectiveId in objectives)
      continue

    objectives.append({
      name = visualData.objectiveName
      isSecretObjective = visualData.isSecretObjective
      id = visualData.objectiveId
      contractType = visualData?.contractType
      params = { 
        staticTargetTag = [ visualData.objectiveId ]
      }
    })
  }

  dispatchColorsAndSort(objectives)
  return objectives
}

let getDebriefingZones = function(visuals) {
  let zones = {}
  local index = 0
  foreach(visualData in visuals) {
    if ("radius" in visualData) {
      zones[index] <- {
        pos = Point3(visualData.position.x, visualData.position.y, visualData.position.z),
        objectiveTag = visualData.objectiveId,
        radius = visualData.radius,
        enabled = true,
        needIdxMark = false,
      }
      index += 1
    }
  }

  return zones
}

let getDebriefingMarkers = function(visuals) {
  let markers = {}
  local index = 0
  foreach(visualData in visuals) {
    if ("iconName" in visualData) {
      markers[index] <- {
        pos = Point3(visualData.position.x, visualData.position.y, visualData.position.z),
        icon = visualData.iconName,
        objectiveTag = visualData.objectiveId,
        enabled = true,
        active = true,
        text = visualData?.tooltip ?? "",
        activeColor = visualData?.activeColor ?? Point3(255, 255, 255),
        hoverColor = visualData?.hoverColor ?? Point3(200, 255, 200),
        inactiveColor = visualData?.inactiveColor ?? Point3(100, 100, 100),
        clampToBorder = visualData?.clampToBorder ?? true
      }
      index += 1
    }
  }

  return markers
}

let updateDebriefingContractsData = function(is_on_base, battle_result) {
  if (!is_on_base || battle_result == null)
    return

  let encodedVisuals = battle_result?.contractsVisuals
  let visuals = (encodedVisuals != null && encodedVisuals.len() > 0) ? parse_json(decodeString(encodedVisuals)) : []

  debriefingObjectives.set(getDebriefingObjectives(visuals))
  debriefingObjectiveZones.set(getDebriefingZones(visuals))
  debriefingObjectiveMarkers.set(getDebriefingMarkers(visuals))
}

return {
  debriefingObjectives
  debriefingObjectiveZones
  debriefingObjectiveMarkers
  updateDebriefingContractsData
}

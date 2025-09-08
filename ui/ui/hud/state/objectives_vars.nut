import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { sound_play } = require("%dngscripts/sound_system.nut")
let { eventbus_send } = require("eventbus")
let { localPlayerEid } = require("%ui/hud/state/local_player.nut")
let { colorblindPalette } = require("%ui/components/colors.nut")

let objectives = Watched([])
let quickUseObjective = Watched()
let objectiveAdditions = Watched({})

enum BusEventType {
  ADD    = 0
  UPDATE = 1
  DELETE = 2
}

console_register_command(@(soundName) sound_play(soundName, 1.0), "play.sound")

function sendStateBusEvent(ids, eventType){
  log($"objectives: send state bus event: type={eventType}, num ids={ids.len()}")
  let addedObjectives   = eventType == BusEventType.ADD ? ids : const []
  let updatedObjectives = eventType == BusEventType.UPDATE ? ids : const []
  let deletedObjectives = eventType == BusEventType.DELETE ? ids : const []


  eventbus_send("objectives.update_state",{
    deletedObjectives
    updatedObjectives
    addedObjectives
  })
}

let sortObjectives = @(a, b)
      (b?.completed && b?.requireExtraction) <=> (a?.completed && a?.requireExtraction)
      || a?.completed <=> b?.completed
      || a?.failed <=> b?.failed
      || a?.contractType <=> b?.contractType
      || a.id <=> b.id

function dispatchColorsAndSort(obj){
  
  obj.sort(@(a, b)
    (b?.params.staticTargetTag != null) <=> (a?.params.staticTargetTag != null)
    || a?.contractType <=> b?.contractType
    || a.id <=> b.id
  )
  obj.each(function(v, idx){
    if (v?.params.staticTargetTag != null)
      v.colorIdx <- idx % colorblindPalette.len()
    return v
  })
  obj.sort(sortObjectives)
  return obj
}

function addObjective(comp){
  objectives.mutate(function(v){
    v.append({
      name                  = comp.objective__name,
      handledByGameTemplate = comp.objective__templateName,
      currentValue          = comp.objective__currentValue,
      requireValue          = comp.objective__requireValue,
      contractType          = comp.objective__contractType,
      requireExtraction     = comp.objective__requireExtraction,
      blockExtraction       = comp.objective__blockExtractionWhenIncomplete
      params                = comp.objective__params.getAll()
        .reduce(function(res, param) {
          if (param.name in res)
            res[param.name].append(param.value)
          else
            res[param.name] <- [param.value]
          return res
        }, {}),
      id                    = comp.objective__id,
      failed                = comp.objective__isFailed,
      completed             = comp.objective__isCompleted,
      isSecretObjective     = comp.secretObjective != null
    })

    dispatchColorsAndSort(v)
  })
  sendStateBusEvent([comp.objective__id], BusEventType.ADD)
}

function deleteObjective(comp){
  local idx = objectives.get().findindex(@(obj) obj.id == comp.objective__id)
  if (idx == null)
    return
  objectives.mutate(function(v) {
    v.remove(idx)
  })
  sendStateBusEvent([comp.objective__id], BusEventType.DELETE)
}

function updateObjective(comp){
  objectives.mutate(function(values){
    foreach(v in values){
      if (v.id != comp.objective__id)
        continue
      v.currentValue = comp.objective__currentValue
      v.requireValue = comp.objective__requireValue
      v.failed = comp.objective__isFailed
      v.completed = comp.objective__isCompleted
      v.name = comp.objective__name
      break
    }
    values.sort(sortObjectives)
  })
  sendStateBusEvent([comp.objective__id], BusEventType.UPDATE)
}

ecs.register_es("objectives_state",
  {
    [["onInit","onChange"]] = function(_eid, comp){
      if (comp.objective__playerEid != localPlayerEid.get())
        return

      let doesObjectiveExist = objectives.get().findindex(@(obj) obj.id == comp.objective__id) != null
      if (doesObjectiveExist){
        if (!comp.objective__show){
          deleteObjective(comp)
          return
        }
        updateObjective(comp)
        return
      }

      if (comp.objective__show)
        addObjective(comp)
    }
    onDestroy = function(_eid, comp){
      deleteObjective(comp)
    }
  },
  {
    comps_track = [
      ["objective__currentValue", ecs.TYPE_INT],
      ["objective__requireValue", ecs.TYPE_INT],
      ["objective__isFailed", ecs.TYPE_BOOL],
      ["objective__isCompleted", ecs.TYPE_BOOL],
      ["objective__show", ecs.TYPE_BOOL],
      ["objective__params", ecs.TYPE_ARRAY],
      ["objective__name", ecs.TYPE_STRING],
    ],
    comps_ro = [
      ["objective__contractType", ecs.TYPE_INT],
      ["objective__playerEid", ecs.TYPE_EID],
      ["objective__id", ecs.TYPE_STRING],
      ["objective__templateName", ecs.TYPE_STRING],
      ["objective__requireExtraction", ecs.TYPE_BOOL],
      ["objective__isStoryContract", ecs.TYPE_BOOL],
      ["objective__requireFullCompleteInSession", ecs.TYPE_BOOL],
      ["objective__isReported", ecs.TYPE_BOOL],
      ["secretObjective", ecs.TYPE_TAG, null],
      ["objective__blockExtractionWhenIncomplete", ecs.TYPE_BOOL]
    ]
  }
)

let getPlayerObjectivesQuery = ecs.SqQuery("getPlayerObjectivesQuery", {
  comps_ro = [
    ["objective__currentValue", ecs.TYPE_INT],
    ["objective__isFailed", ecs.TYPE_BOOL],
    ["objective__isCompleted", ecs.TYPE_BOOL],
    ["objective__show", ecs.TYPE_BOOL],
    ["objective__requireValue", ecs.TYPE_INT],
    ["objective__contractType", ecs.TYPE_INT],
    ["objective__playerEid", ecs.TYPE_EID],
    ["objective__params", ecs.TYPE_ARRAY],
    ["objective__id", ecs.TYPE_STRING],
    ["objective__name", ecs.TYPE_STRING],
    ["objective__templateName", ecs.TYPE_STRING],
    ["objective__requireExtraction", ecs.TYPE_BOOL],
    ["objective__isStoryContract", ecs.TYPE_BOOL],
    ["objective__requireFullCompleteInSession", ecs.TYPE_BOOL],
    ["objective__isReported", ecs.TYPE_BOOL],
    ["secretObjective", ecs.TYPE_TAG, null],
    ["objective__blockExtractionWhenIncomplete", ecs.TYPE_BOOL]
  ]
})


let addAllPlayerObjectives = function(player_eid) {
  getPlayerObjectivesQuery.perform(function(_eid, comp){
    if (comp.objective__playerEid == player_eid && comp.objective__show)
      addObjective(comp)
  })
}


localPlayerEid.subscribe(function(eid){
  if (eid != ecs.INVALID_ENTITY_ID && objectives.get().len() == 0){
    addAllPlayerObjectives(eid)
    return
  }

  local idsForDelete = []
  objectives.get().map(@(objective) idsForDelete.append(objective.id))
  sendStateBusEvent(idsForDelete, BusEventType.DELETE)
  objectives.set([])
  if (eid != ecs.INVALID_ENTITY_ID)
    addAllPlayerObjectives(eid)
})


ecs.register_es("quick_use_objective_track_es",
  {
    [["onInit","onChange"]] = @(_eid, comp) quickUseObjective.set(comp.quick_use__objective)
  },
  {
    comps_track=[["quick_use__objective", ecs.TYPE_STRING]]
    comps_rq=["hero"]
  }
)


return {
  objectives
  quickUseObjective
  objectiveAdditions
  dispatchColorsAndSort
}

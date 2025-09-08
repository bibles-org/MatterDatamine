from "%darg/ui_imports.nut" import *

from "%sqstd/ecs.nut" import *

let {selectedEntities, markedScenes, showLoadedScenes, de4workMode} = require("state.nut")
let {colors} = require("components/style.nut")
let textButton = require("components/textButton.nut")
let closeButton = require("components/closeButton.nut")
let mkWindow = require("components/window.nut")
let nameFilter = require("components/nameFilter.nut")
let {makeVertScroll} = require("%daeditor/components/scrollbar.nut")
let {getEntityExtraName, getSceneLoadTypeText, getSceneId, getSceneIdOf} = require("%daeditor/daeditor_es.nut")
let { format } = require("string")
let entity_editor = require("entity_editor")
let mkSceneSortModeButton = require("components/mkSortSceneModeButton.nut")
let scrollHandler = ScrollHandler()
let scrollHandlerEntities = ScrollHandler()
let markedStateScenes = Watched({})
let filterString = mkWatched(persist, "filterString", "")
let filterScenesBySelectedEntities = mkWatched(persist, "filterScenesBySelectedEntities", true)
let allScenes = mkWatched(persist, "allScenes", [])
let allSceneCounts = mkWatched(persist, "allSceneCounts", [])
let selectionStateEntities = mkWatched(persist, "selectionStateEntities", {})
let allEntities = mkWatched(persist, "allEntities", [])
let filteredEntities = Watched([])

let sceneSortState = Watched({})

local sceneSortFuncCache = null

let statusAnimTrigger = { lastN = null }

let numMarkedScenes = Computed(function() {
  local nSel = 0
  foreach (_sceneId, marked in markedStateScenes.value) {
    if (marked)
      ++nSel
  }
  return nSel
})

let numSelectedEntities = Computed(function() {
  local nSel = 0
  foreach (v in selectionStateEntities.value) {
    if (v)
      ++nSel
  }
  return nSel
})

let selectedEntitiesSceneIds = Computed(function() {
  local res = [[],  [],  [],  []]
  foreach (eid, _v in selectedEntities.value) {
    local loadType = entity_editor.get_instance()?.getEntityRecordLoadType(eid)
    if (loadType != 0) {
      local index = entity_editor.get_instance()?.getEntityRecordIndex(eid)
      res[loadType].append(index)
    }
  }
  return res
})

function getSelectedIdsCount(selectedIds) {
  local selectedIdsCount = 0
  foreach (_i, ids in selectedIds)
    selectedIdsCount += ids.len()
  return selectedIdsCount
}

function matchSceneBySelectedEntities(scene, selectedIds) {
  return selectedIds[scene.loadType].indexof(scene.index) != null
}

function sceneToText(scene) {
  local loadType = getSceneLoadTypeText(scene)
  local index = scene.index
  local path = scene.path
  local entityCount = scene.entityCount
  local order = scene.order
  return $"{loadType}:{index}  {path} - Entities: {entityCount}  (#{order})"
}

function matchSceneByText(scene, text) {
  if (text==null || text=="")
    return true
  if (sceneToText(scene).tolower().indexof(text.tolower()) != null)
    return true
  return false
}

function matchSceneByFilters(scene, selectedIds, selectedIdsCount) {
  if (selectedIdsCount > 0)
    if (matchSceneBySelectedEntities(scene, selectedIds))
      return true
  if (matchSceneByText(scene, filterString.value))
    return true
  return false
}

let filteredScenes = Computed(function() {
  local scenes = allScenes.value
  if (filterScenesBySelectedEntities.value) {
    local selectedIds = selectedEntitiesSceneIds.value
    local selectedIdsCount = getSelectedIdsCount(selectedIds)
    if (selectedIdsCount > 0)
      scenes = scenes.filter(@(scene) matchSceneBySelectedEntities(scene, selectedIds))
  }
  if (filterString.value != "")
    scenes = scenes.filter(@(scene) matchSceneByText(scene, filterString.value))
  if (sceneSortFuncCache != null)
    scenes.sort(sceneSortFuncCache)
  return scenes
})

let filteredScenesCount = Computed(@() filteredScenes.value.len())

let filteredScenesEntityCount = Computed(function() {
  local eCount = 0
  foreach (scene in filteredScenes.value) {
    eCount += scene.entityCount
  }
  return eCount
})

let numMarkedScenesEntityCount = Computed(function() {
  local nSel = 0
  foreach (scene in filteredScenes.value) {
    if (markedStateScenes.value?[getSceneIdOf(scene)])
      nSel += scene.entityCount
  }
  return nSel
})

function matchEntityByScene(eid) {
  local eLoadType = entity_editor.get_instance()?.getEntityRecordLoadType(eid)
  local eIndex = entity_editor.get_instance()?.getEntityRecordIndex(eid)
  local sceneId = getSceneId(eLoadType, eIndex)
  return markedStateScenes.value?[sceneId]
}

markedStateScenes.subscribe(function(_v) {
  local entities = allEntities.value
  if (numMarkedScenes.value > 0)
    entities = entities.filter(@(eid) matchEntityByScene(eid))
  filteredEntities.set(entities)
})

let filteredEntitiesCount = Computed(@() filteredEntities.value.len())

function markScene(cb) {
  markedStateScenes.mutate(function(value) {
    foreach (k, v in value)
      value[k] = cb(k, v)
  })
}

function applyEntitySelection(cb) {
  selectionStateEntities.mutate(function(value) {
    foreach (k, v in value)
      value[k] = cb(k, v)
  })
}




let markAllFiltered = function() {
  local selectedIds = selectedEntitiesSceneIds.value
  local selectedIdsCount = getSelectedIdsCount(selectedIds)
  markScene(@(scene, _cur) matchSceneByFilters(scene, selectedIds, selectedIdsCount))
}

let markSceneNone = @() markScene(@(_scene, _cur) false)


let markScenesInvert = function() {
  local selectedIds = selectedEntitiesSceneIds.value
  local selectedIdsCount = getSelectedIdsCount(selectedIds)
  markScene(@(scene, cur) matchSceneByFilters(scene, selectedIds, selectedIdsCount) ? !cur : false)
}

function scrollScenesBySelection() {
  scrollHandler.scrollToChildren(function(desc) {
    return ("scene" in desc) && markedStateScenes.value?[getSceneIdOf(desc.scene)]
  }, 2, false, true)
}

function scrollEntitiesBySelection() {
  scrollHandlerEntities.scrollToChildren(function(desc) {
    return ("eid" in desc) && selectionStateEntities.value?[desc.eid]
  }, 2, false, true)
}

function doCancel() {
  showLoadedScenes(false)
}

function scnTxt(count) { return count==1 ? "scene" : "scenes" }
function entTxt(count) { return count==1 ?  "entity" : "entities" }
function statusText(count, textFunc) { return format("%d %s", count, textFunc(count)) }

function statusLineScenes() {
  let sMrk = numMarkedScenes.value
  let eMrk = numMarkedScenesEntityCount.value
  let eRec = filteredScenesEntityCount.value

  if (statusAnimTrigger.lastN != null && statusAnimTrigger.lastN != sMrk)
    anim_start(statusAnimTrigger)
  statusAnimTrigger.lastN = sMrk

  return {
    watch = [numMarkedScenes, numMarkedScenesEntityCount, filteredScenesCount, filteredScenesEntityCount, markedStateScenes, selectedEntities]
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    children = [
      {
        rendObj = ROBJ_TEXT
        size = [flex(), SIZE_TO_CONTENT]
        text = format(" %s, with %s, marked", statusText(sMrk, scnTxt), statusText(eMrk, entTxt))
        animations = [
          { prop=AnimProp.color, from=colors.HighlightSuccess, duration=0.5, trigger=statusAnimTrigger }
        ]
      }
      {
        rendObj = ROBJ_TEXT
        halign = ALIGN_RIGHT
        size = [flex(), SIZE_TO_CONTENT]
        text = format(" %s, with %s, listed", statusText(filteredScenesCount.value, scnTxt), statusText(eRec, entTxt))
        color = Color(170,170,170)
      }
    ]
  }
}

let filter = nameFilter(filterString, {
  placeholder = "Filter by load-type/path/entities"

  function onChange(text) {
    filterString(text)
  }

  function onEscape() {
    set_kb_focus(null)
  }

  function onReturn() {
    set_kb_focus(null)
  }

  function onClear() {
    filterString.update("")
    set_kb_focus(null)
  }
})


let removeSelectedByEditorTemplate = @(tname) tname.replace("+daeditor_selected+","+").replace("+daeditor_selected","").replace("daeditor_selected+","")

function listSceneRow(scene, idx) {
  return watchElemState(function(sf) {
    let sceneId = getSceneIdOf(scene)
    let isMarked = markedStateScenes.value?[sceneId]
    let textColor = isMarked ? colors.TextDefault : colors.TextDarker
    let color = isMarked ? colors.Active
    : sf & S_TOP_HOVER ? colors.GridRowHover
    : colors.GridBg[idx % colors.GridBg.len()]

    return {
      rendObj = ROBJ_SOLID
      size = [flex(), SIZE_TO_CONTENT]
      color
      scene
      behavior = Behaviors.Button

      function onClick(evt) {
        if (evt.shiftKey) {
          local selCount = 0
          foreach (_k, v in markedStateScenes.value) {
            if (v)
              ++selCount
          }
          if (selCount > 0) {
            local idx1 = -1
            local idx2 = -1
            foreach (i, filteredScene in filteredScenes.value) {
              if (scene == filteredScene) {
                idx1 = i
                idx2 = i
              }
            }
            foreach (i, filteredScene in filteredScenes.value) {
              if (markedStateScenes.value?[getSceneIdOf(filteredScene)]) {
                if (idx1 > i)
                  idx1 = i
                if (idx2 < i)
                  idx2 = i
              }
            }
            if (idx1 >= 0 && idx2 >= 0) {
              if (idx1 > idx2) {
                let tmp = idx1
                idx1 = idx2
                idx2 = tmp
              }
              markedStateScenes.mutate(function(value) {
                for (local i = idx1; i <= idx2; i++) {
                  let filteredScene = filteredScenes.value[i]
                  value[getSceneIdOf(filteredScene)] <- !evt.ctrlKey
                }
              })
            }
          }
        }
        else if (evt.ctrlKey) {
          markedStateScenes.mutate(function(value) {
            value[sceneId] <- !value?[sceneId]
          })
        }
        else {
          local wasMarked = markedStateScenes.value?[sceneId]
          markSceneNone()
          if (!wasMarked) {
            markedStateScenes.mutate(function(value) {
              value[sceneId] <- true
            })
          }
        }
      }

      children = {
        rendObj = ROBJ_TEXT
        text = sceneToText(scene)
        color = textColor
        margin = fsh(0.5)
      }
    }
  })
}

function listRowMoreLeft(num, idx) {
  return watchElemState(function(sf) {
    let color = (sf & S_TOP_HOVER) ? colors.GridRowHover : colors.GridBg[idx % colors.GridBg.len()]
    return {
      rendObj = ROBJ_SOLID
      size = [flex(), SIZE_TO_CONTENT]
      color
      children = {
        rendObj = ROBJ_TEXT
        text = $"{num} more ..."
        color = colors.TextReadOnly
        margin = fsh(0.5)
      }
    }
  })
}


function initScenesList() {
  local scenes = entity_editor.get_instance()?.getSceneImports() ?? []
  local sceneCounts = [null,  0,  0,  0]
  foreach (scene in scenes) {
    sceneCounts[scene.loadType] += 1
    local scenedId = getSceneId(scene.loadType, scene.index)
    local isMarked = markedScenes.value?[scenedId] ?? false
    markedStateScenes.value[scenedId] <- isMarked
  }
  allScenes(scenes)
  allSceneCounts(sceneCounts)
  markedStateScenes.trigger()
}

sceneSortState.subscribe(function(v) {
  sceneSortFuncCache = v?.func
  selectedEntities.trigger()
  markedStateScenes.trigger()
  initScenesList()
})

de4workMode.subscribe(@(_) gui_scene.resetTimeout(0.1, initScenesList))

function statusLineEntities() {
  let nMrk = numSelectedEntities.value
  let nSel = selectedEntities.value.len()

  return {
    watch = [numSelectedEntities, filteredEntitiesCount, selectedEntities]
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    children = [
      {
        rendObj = ROBJ_TEXT
        size = [flex(), SIZE_TO_CONTENT]
        text = format(" %d %s marked, %d selected", nMrk, nMrk==1 ? "entity" : "entities", nSel)
      }
      {
        rendObj = ROBJ_TEXT
        halign = ALIGN_RIGHT
        size = [flex(), SIZE_TO_CONTENT]
        text = format("%d listed", filteredEntitiesCount.value)
        color = Color(170,170,170)
      }
    ]
  }
}

function listEntityRow(eid, idx) {
  return watchElemState(function(sf) {
    let isSelected = selectionStateEntities.value?[eid]
    let textColor = isSelected ? colors.TextDefault : colors.TextDarker
    let color = isSelected ? colors.Active
      : sf & S_TOP_HOVER ? colors.GridRowHover
      : colors.GridBg[idx % colors.GridBg.len()]

    let extraName = getEntityExtraName(eid)
    let extra = (extraName != null) ? $"/ {extraName}" : ""

    local tplName = g_entity_mgr.getEntityTemplateName(eid) ?? ""
    let name = removeSelectedByEditorTemplate(tplName)
    let div = (tplName != name) ? "•" : "|"

    local loadTypeVal = entity_editor.get_instance()?.getEntityRecordLoadType(eid)
    let loadType = getSceneLoadTypeText(loadTypeVal)
    let index = entity_editor.get_instance()?.getEntityRecordIndex(eid)

    return {
      rendObj = ROBJ_SOLID
      size = [flex(), SIZE_TO_CONTENT]
      color
      eid
      behavior = Behaviors.Button

      function onClick(_evt) {
        applyEntitySelection(@(eid_, _cur) eid_==eid)
      }

      children = {
        rendObj = ROBJ_TEXT
        text = $"{eid}  {div}  {name} {extra}  {loadType}:{index}"
        color = textColor
        margin = fsh(0.5)
      }
    }
  })
}

function initEntitiesList() {
  let entities = entity_editor.get_instance()?.getSceneEntities() ?? []
  foreach (eid in entities) {
    let isSelected = selectedEntities.value?[eid] ?? false
    selectionStateEntities.value[eid] <- isSelected
  }
  allEntities(entities)
  selectionStateEntities.trigger()
}

function initLists() {
  initScenesList();
  initEntitiesList();
}

function sceneFilterCheckbox() {
  let group = ElemGroup()
  let stateFlags = Watched(0)
  let hoverFlag = Computed(@() stateFlags.value & S_HOVER)

  function onClick() {
    filterScenesBySelectedEntities.update(!filterScenesBySelectedEntities.value)
    return
  }

  return function () {
    local mark = null
    if (filterScenesBySelectedEntities.value) {
      mark = {
        rendObj = ROBJ_SOLID
        color = (hoverFlag.value != 0) ? colors.Hover : colors.Interactive
        group
        size = [pw(50), ph(50)]
        hplace = ALIGN_CENTER
        vplace = ALIGN_CENTER
      }
    }

    return {
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_HORIZONTAL
      halign = ALIGN_LEFT
      valign = ALIGN_CENTER

      watch = [filterScenesBySelectedEntities]

      children = [
        {
          size = [fontH(80), fontH(80)]
          rendObj = ROBJ_SOLID
          color = colors.ControlBg

          behavior = Behaviors.Button
          group

          children = mark

          onElemState = @(sf) stateFlags.update(sf)

          onClick
        }
        {
          rendObj = ROBJ_TEXT
          size = [flex(), SIZE_TO_CONTENT]
          text = "Pre-filter based on selected entities"
          color = colors.TextDefault
          margin = fsh(0.5)
        }
      ]
    }
  }
}

function scenesMarkerRoot() {

  function listSceneContent() {
    const maxVisibleItems = 250
    local sRows = filteredScenes.value.slice(0, maxVisibleItems).map(@(scene, idx) listSceneRow(scene, idx))
    if (sRows.len() < filteredScenes.value.len())
      sRows.append(listRowMoreLeft(filteredScenes.value.len() - sRows.len(), sRows.len()))

    return {
      watch = [selectedEntities, markedStateScenes, filteredScenes]
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      children = sRows
      behavior = Behaviors.Button
    }
  }

  let scrollListScenes = makeVertScroll(listSceneContent, {
    scrollHandler
    rootBase = class {
      size = flex()
      function onAttach() {
        scrollScenesBySelection()
      }
    }
  })

  function listEntitiesContent() {
    const maxVisibleItems = 250
    let eRows = filteredEntities.value.slice(0, maxVisibleItems).map(@(eid, idx) listEntityRow(eid, idx))
    if (eRows.len() < filteredEntities.value.len())
      eRows.append(listRowMoreLeft(filteredEntities.value.len() - eRows.len(), eRows.len()))

    return {
      watch = [selectedEntities, selectionStateEntities, filteredEntities]
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      children = eRows
      behavior = Behaviors.Button
    }
  }

  let scrollListEntities = makeVertScroll(listEntitiesContent, {
    scrollHandlerEntities
    rootBase = class {
      size = flex()
      function onAttach() {
        scrollEntitiesBySelection()
      }
    }
  })

  let content = @() {
    flow = FLOW_VERTICAL
    gap = fsh(0.5)
    watch = [allScenes, filteredScenes, markedStateScenes, filteredEntities, selectionStateEntities]
    size = flex()
    children = [
      {
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_HORIZONTAL
        children = [
          mkSceneSortModeButton(sceneSortState)
          { size = [sw(0.2), SIZE_TO_CONTENT] }
          filter
          closeButton(doCancel)
        ]
      }
      {
        flow = FLOW_HORIZONTAL
        size = [flex(), SIZE_TO_CONTENT]
        children = sceneFilterCheckbox()
      }
      {
        size = flex()
        children = scrollListScenes
      }
      statusLineScenes
      {
        flow = FLOW_HORIZONTAL
        size = [flex(), SIZE_TO_CONTENT]
        halign = ALIGN_CENTER
        children = [
          textButton("All filtered", markAllFiltered)
          textButton("None", markSceneNone)
          textButton("Invert", markScenesInvert)
        ]
      }
      {
        size = flex()
        children = scrollListEntities
      }
      statusLineEntities
    ]
  }
  return mkWindow({
    onAttach = initLists
    id = "loaded_scenes"
    content
    saveState = true
  })()
}


return scenesMarkerRoot

from "json" import parse_json, object_to_json_string

from "modules" import on_module_unload
from "%ui/ui_library.nut" import *
from "dagor.debug" import logerr
from "%ui/state/appState.nut" import levelIsLoading


let navScenesList = persist("navScenesList", @() [])
let navScenesListGen = Watched(0)
let nextListGeneration = @() navScenesListGen.modify(@(v) v + 1)
let sceneCtorsById = {} 

on_module_unload(function(){
  navScenesList.replace(navScenesList.filter(function(v){
    let t = type(v)
    if (t!="string" && t == "array")
      return false
    return isEqual(parse_json(object_to_json_string(v)), v)
  }))
})

function getNavSceneIdIdx(componentOrSceneOrId){
  local idx
  local id = componentOrSceneOrId
  if (type(componentOrSceneOrId) == "array") {
    id = componentOrSceneOrId[0]
    idx = navScenesList.indexof(id)
  }
  else if (type(componentOrSceneOrId) == "string" && navScenesList.findindex(@(v) v?.id==id)!=null) {
    idx = navScenesList.findindex(@(v) v.id==id)
  }
  else
    idx = navScenesList.indexof(componentOrSceneOrId)
  return {idx, id}
}

let doesNavSceneExist = @(...) navScenesList.len()>0

function getTopNavScene(...){
  if (navScenesList.len()==0)
    return null
  let top = navScenesList.top()
  let t = type(top)
  if (t == "table" && "scene" in top) {
    return top.scene
  }
  else if (t == "string" || t == "array") {
    let args = t == "string" ? [null] : [null].extend(top.slice(1))
    let id = t == "string" ? top : top[0]
    if (id in sceneCtorsById)
      return sceneCtorsById[id].acall(args)
    else
      logerr($"unregistered sceneCtor {id}")
    return null
  }
  return top
}
let getNavScenesList = @() freeze(navScenesList)

function addNavScene(componentOrSceneOrId) {
  let {id, idx} = getNavSceneIdIdx(componentOrSceneOrId)
  if (idx != null)
    navScenesList.remove(idx)
  if (type(componentOrSceneOrId)=="table" && "scene" in componentOrSceneOrId) {
    navScenesList.append(componentOrSceneOrId)
  }
  else if (type(id)=="string" && id not in sceneCtorsById) {
    logerr($"unregistered sceneCtor {id}")
    return
  }
  else
    navScenesList.append(componentOrSceneOrId)
  nextListGeneration()
}

function removeNavScene(componentOrId) {
  let {idx} = getNavSceneIdIdx(componentOrId)
  if (idx == null)
    return
  navScenesList.remove(idx)
  nextListGeneration()
}

function setNavToIdx(i) {
  let idx = i+1
  if (idx > navScenesList.len() || idx < 0)
    return
  navScenesList.replace(navScenesList.slice(0, idx))
  nextListGeneration()
}

function clearAllNavScenes(...){
  navScenesList.clear()
  nextListGeneration()
}

function registerNavSceneCtorById(id, sceneCtor) {
  sceneCtorsById[id] <- sceneCtor
  return null
}

function replaceTopScene(v){
  let len = navScenesList.len()
  if ( len > 0)
    navScenesList.replace(navScenesList.slice(0, len))
  addNavScene(v)
  nextListGeneration()
}

function backNavScene(){
  setNavToIdx(navScenesList.len()-2)
}

console_register_command(
  @(menuName) addNavScene(menuName),
  "navScene.showMenuById"
)

function getTopNavSceneId(){
  let len = navScenesList.len()
  if (len == 0)
    return null
  let sceneOrId = navScenesList[len-1]
  let t = type(sceneOrId)
  if (t == "array")
    return sceneOrId[0]


  return sceneOrId
}

levelIsLoading.subscribe_with_nasty_disregard_of_frp_update(@(v) v ? clearAllNavScenes() : null)

return {
  navScenesListGen,
  doesNavSceneExist,
  getTopNavScene,
  addNavScene,
  replaceTopScene,
  removeNavScene,
  clearAllNavScenes,
  setNavToIdx,
  getNavScenesList,
  getTopNavSceneId,
  backNavScene,
  registerNavSceneCtorById,
  getNavSceneIdIdx
}

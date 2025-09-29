from "%dngscripts/sound_system.nut" import sound_play
from "eventbus" import eventbus_send
from "%ui/components/colors.nut" import colorblindPalette
import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *
from "%dngscripts/globalState.nut" import nestWatched
from "%ui/components/colors.nut" import TextDisabled, TextNormal, InfoTextValueColor, GreenSuccessColor,
  RedWarningColor, OrangeHighlightColor, colorblindPalette, HudTipFillColor, ItemIconBlocked,
  ConsoleHeaderFillColor
from "eventbus" import eventbus_subscribe
from "dasevents" import EventSpawnSequenceEnd, EventRewardDailyContract, EventAmStorageHacked
from "math" import rand
from "%ui/popup/player_event_log.nut" import addPlayerLog, mkPlayerLog, marketIconSize
from "%ui/fonts_style.nut" import fontawesome, sub_txt, tiny_txt
from "%ui/components/commonComponents.nut" import mkDescTextarea, descriptionStyle, descriptionStyle
from "%ui/hud/objectives/objective_components.nut" import mkObjectiveIdxMark, idxMarkDefaultSize, idxMarkHeight, getContractProgressionText, color_common
from "%ui/components/scrollbar.nut" import makeVertScrollExt, thinStyle
from "%ui/components/cursors.nut" import setTooltip
import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *
import "%ui/components/faComp.nut" as faComp
import "%ui/components/fontawesome.map.nut" as fa
from "%ui/helpers/remap_nick.nut" import remap_nick
from "%ui/components/itemIconComponent.nut" import itemIconNoBorder

let { localPlayerEid } = require("%ui/hud/state/local_player.nut")
let { watchedHeroPlayerEid } = require("%ui/hud/state/watched_hero.nut")
let { isSpectator } = require("%ui/hud/state/spectator_state.nut")
let { hudIsInteractive } = require("%ui/hud/state/interactive_state.nut")
let { monolithTokensTextIcon } = require("%ui/mainMenu/currencyIcons.nut")

let objectives = Watched([])
let quickUseObjective = Watched()
let objectiveAdditions = Watched({})
let objectiveStates = Watched({})
let showDailyRewardObjectives = Watched(false)

console_register_command(@(soundName) sound_play(soundName, 1.0), "play.sound")

function setShowAllObjectives(value) {
  showDailyRewardObjectives.set(value)
  log($"show all objectives.set({value}): have {objectiveStates.get().len()} objective states")
  objectiveStates.mutate(@(states) states.each(@(state) state.show = value))
}


function closeWnd() {
  setShowAllObjectives(false)
}

let fadeoutTime = 2
let closeObjectiveTime = fadeoutTime - 0.1

function startFadeout() {
  objectiveStates.get().each(@(_, id) anim_start(objectiveStates.get()[id].fadeout))
  gui_scene.setTimeout(closeObjectiveTime, closeWnd)
}

function showObjectives(timeTillHide = 5) {
  gui_scene.clearTimer(closeWnd)
  gui_scene.clearTimer(startFadeout)
  objectiveStates.get().each(function(_, id) {
    gui_scene.clearTimer(objectiveStates.get()[id].hide)
    anim_request_stop(objectiveStates.get()[id].fadeout)
  })
  setShowAllObjectives(true)
  if(timeTillHide < 0)
    return
  gui_scene.setTimeout(timeTillHide, startFadeout)
}

function closeObjective(id) {
  objectiveStates.mutate(function(states) {
    let state = states?[id]
    if (!state)
      return
    state.show = false
  })
}

function startObjectiveFadeout(id) {
  let objectiveState = objectiveStates.get()?[id]
  if (!objectiveState)
    return
  anim_start(objectiveState.fadeout)
  gui_scene.setTimeout(closeObjectiveTime, @() closeObjective(id), objectiveStates.get()[id].hide)
}

function playObjectiveSound(){
  if (watchedHeroPlayerEid.get() != ecs.INVALID_ENTITY_ID)
    sound_play("ui_sounds/interface_back", 1.0)
}
function showObjective(id, timeTillHide = 5) {
  gui_scene.clearTimer(objectiveStates.get()[id].hide)
  gui_scene.clearTimer(objectiveStates.get()[id].fadeout)
  objectiveStates.mutate(@(states) states[id].show = true)
  if (timeTillHide < 0)
    return
  gui_scene.setTimeout(timeTillHide, @() startObjectiveFadeout(id), objectiveStates.get()[id].fadeout)
}

function deleteObjectives(deletedObjectives){
  if (deletedObjectives.len()>0)
    objectiveStates.mutate(function(states) {
      foreach(id in deletedObjectives)
        states.$rawdelete(id)
   })
}

function hiliteObjective(id) {
  showObjective(id, 10)
  playObjectiveSound()
}

function addnObjective(id) {
  objectiveStates.mutate(function(states) {
    states[id] <- {
      show = false
      fadeout = $"fadeoutObjective_{id}"
      hide = $"hideObjective_{id}"
    }
  })
  hiliteObjective(id)
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
    || (b?.params.dynamicTargetTag != null) <=> (a?.params.dynamicTargetTag != null)
    || a?.contractType <=> b?.contractType
    || a.id <=> b.id
  )
  obj.each(function(v, idx){
    if (v?.params.staticTargetTag != null || v?.params.dynamicTargetTag != null)
      v.colorIdx <- idx % colorblindPalette.len()
    return v
  })
  obj.sort(sortObjectives)
  return obj
}

function addObjective(eid, comp){
  objectives.mutate(function(v){
    v.append({
      eid                   = eid
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
      itemTags              = "+".join(comp.objective__itemTags?.getAll() ?? [])
    })

    dispatchColorsAndSort(v)
  })
  addnObjective(comp.objective__id)
}

function deleteObjective(comp){
  local idx = objectives.get().findindex(@(obj) obj.id == comp.objective__id)
  if (idx == null)
    return
  objectives.mutate(function(v) {
    v.remove(idx)
  })
  deleteObjectives([comp.objective__id])
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
  hiliteObjective(comp.objective__id)
}

ecs.register_es("objectives_state",
  {
    [["onInit","onChange"]] = function(eid, comp){
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
        addObjective(eid, comp)
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
      ["objective__requireFullCompleteInSession", ecs.TYPE_BOOL],
      ["objective__isReported", ecs.TYPE_BOOL],
      ["secretObjective", ecs.TYPE_TAG, null],
      ["objective__blockExtractionWhenIncomplete", ecs.TYPE_BOOL],
      ["objective__itemTags", ecs.TYPE_STRING_LIST, null]
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
    ["objective__requireFullCompleteInSession", ecs.TYPE_BOOL],
    ["objective__isReported", ecs.TYPE_BOOL],
    ["secretObjective", ecs.TYPE_TAG, null],
    ["objective__blockExtractionWhenIncomplete", ecs.TYPE_BOOL],
    ["objective__itemTags", ecs.TYPE_STRING_LIST, null]
  ]
})


let addAllPlayerObjectives = function(player_eid) {
  getPlayerObjectivesQuery.perform(function(eid, comp){
    if (comp.objective__playerEid == player_eid && comp.objective__show)
      addObjective(eid, comp)
  })
}


localPlayerEid.subscribe_with_nasty_disregard_of_frp_update(function(eid){
  if (eid != ecs.INVALID_ENTITY_ID && objectives.get().len() == 0){
    addAllPlayerObjectives(eid)
    return
  }

  local idsForDelete = []
  objectives.get().map(@(objective) idsForDelete.append(objective.id))
  deleteObjectives(idsForDelete)
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

let color_complete = Color(90,160,100)
let color_complete_bright = mul_color(GreenSuccessColor, 0.8, 2)
let color_failed = Color(130,80,80)
let color_addition = OrangeHighlightColor
let color_progressedButNotComplete = TextDisabled

let monolithContractText = {contract_monolith_danger = loc("contract_monolith_danger")}

let titleGap = hdpx(10)
let titleIconFontSize = hdpxi(20)
let titleIconFontTinySize = hdpxi(14)
let mkExtractionIcon = function(fontSize) {
  let extractionPicture = {
    rendObj = ROBJ_IMAGE
    hplace = ALIGN_CENTER
    vplace = ALIGN_BOTTOM
    image = Picture($"ui/skin#extraction_man.svg:{fontSize-hdpxi(2)}:{fontSize-hdpxi(2)}:P:K")
    color = Color(0,0,0)
    size = titleIconFontSize-hdpxi(2)
    animations = static [{ prop=AnimProp.color, from=Color(0,0,0), to=color_complete, easing=CosineFull, duration=0.8, loop=true, play=true }]
    keepAspect = KEEP_ASPECT_FIT
  }

  return {
    size = fontSize
    children = [
      {
        size = fontSize
        animations = static [{ prop=AnimProp.opacity, from=1, to=0.3, easing=CosineFull, duration=0.8, loop=true, play=true }]
        fillColor = color_addition
        rendObj = ROBJ_BOX
      }
      extractionPicture
    ]
  }
}

let extractionIcon = mkExtractionIcon(titleIconFontSize)
let extractionTinyIcon = mkExtractionIcon(titleIconFontTinySize)

let starSub = faComp("star", { color = InfoTextValueColor, fontSize = sub_txt.fontSize, margin = [hdpx(2),0,0,0]})
let starTiny = faComp("star", { color = InfoTextValueColor, fontSize = tiny_txt.fontSize, margin = [hdpx(2),0,0,0]})
let extractionBlockedSub = faComp("extraction_point.svg", { color = RedWarningColor, margin = [hdpx(2),0,0,0] }.__merge(sub_txt))
let extractionBlockedTiny = faComp("extraction_point.svg", { color = RedWarningColor, margin = [hdpx(2),0,0,0] }.__merge(tiny_txt))


let idxMarkTinySize = idxMarkDefaultSize.map(@(v) v*0.85)
let mkObjectiveStatus = function(idx, objectiveColor, requireExtraction, progress, isPrimary, obj, minimize) {
  let { failed = false, blockExtraction = false, completed = false } = obj
  let isComplete = !requireExtraction && completed
  local mark
  let failedNormal = static faComp("close", {color = RedWarningColor, fontSize = titleIconFontSize})
  let failedTiny = static faComp("close", {color = RedWarningColor, fontSize = titleIconFontTinySize})
  if (failed)
    mark = minimize ? failedTiny : failedNormal
  else if (requireExtraction && completed)
    mark = minimize ? extractionTinyIcon : extractionIcon
  else if (isComplete)
    mark = minimize
      ? static faComp("check-square-o", {color = color_complete_bright, fontSize = titleIconFontTinySize})
      : static faComp("check-square-o", {color = color_complete_bright, fontSize = titleIconFontSize})
  else
    mark = minimize
    ? mkObjectiveIdxMark($"{idx+1}", idxMarkTinySize, objectiveColor, progress, tiny_txt)
    : mkObjectiveIdxMark($"{idx+1}", idxMarkDefaultSize, objectiveColor, progress)
  let hasExtraMarks = isPrimary || (blockExtraction && !completed)
  return {
    size = FLEX_V
    children = [
      hasExtraMarks ? {
        flow = FLOW_HORIZONTAL
        valign = ALIGN_TOP
        vplace = ALIGN_TOP
        size = FLEX_H
        children = [
          isPrimary ? (minimize ? starTiny : starSub) : null,
          (blockExtraction && !completed) ? (minimize ? extractionBlockedTiny : extractionBlockedSub) : null,
        ]
      } : null
      { children = mark vplace = ALIGN_CENTER pos = hasExtraMarks ? static [0, hdpx(10)] : null }
    ]
  }
}

let isPrimaryObjective = @(obj) (obj?.contractType ?? 1) == 0
let isObjCompleted = @(obj) !obj?.requireExtraction && obj?.completed

let mkObjectiveTitle = function(obj, minimize=false) {
  let { name, failed = false,
    
  } = obj
  
  let title = loc($"contract/{name}")
  let isCompleted = isObjCompleted(obj)

  let descStyle = { color = failed ? color_failed : (isCompleted ? color_complete : InfoTextValueColor) }.__update(minimize ? tiny_txt : sub_txt)
  return {
    flow = FLOW_HORIZONTAL
    size = FLEX_H
    gap = hdpx(5)
    valign = ALIGN_CENTER
    children = [


      mkDescTextarea(title, descStyle)
    ]
  }
}


function mkObjectiveProgression(text, handled_template, is_requirement_complete, is_failed, params) {
  local color = color_common

  if (is_failed)
    color = color_failed
  else if (is_requirement_complete)
    color = color_complete

  return {
    rendObj = ROBJ_TEXTAREA
    behavior = Behaviors.TextArea
    size = FLEX_H
    color
    text = getContractProgressionText({name = text, handledByGameTemplate = handled_template}.__update(params), false)
  }.__update(tiny_txt, descriptionStyle)
}

let progressBackColor = mul_color(TextNormal, 0.5, 2)
function mkProgressBar(currentValue, requiredValue, completed=false, failed=false) {
  let breakProgress = requiredValue <=20
  let progressText = {
    rendObj = ROBJ_TEXT text = $"{currentValue}/{requiredValue}"
    color = currentValue>=requiredValue ? color_complete : TextNormal margin=static [0,0,0,hdpx(10)]
  }.__update(tiny_txt)
  let fullfiledcolor = failed || !completed ? TextNormal : color_complete_bright
  let backColor = failed ? mul_color(TextNormal, 0.3, 3) : progressBackColor
  return {
    size = FLEX_H
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    gap  = breakProgress ? hdpx(2) : null
    children = (breakProgress
    ? array(requiredValue).map(@(_, i) {
        rendObj = ROBJ_SOLID
        size = static [flex(), hdpx(4)]
        color = i<currentValue ? fullfiledcolor : backColor
      }).append(progressText)
    : [
      {
        rendObj = ROBJ_SOLID
        size = [flex(currentValue), hdpx(4)]
        color = currentValue >= requiredValue ? fullfiledcolor : backColor
      }
      {
        rendObj = ROBJ_SOLID
        size = [flex(requiredValue-currentValue), hdpx(4)]
        color = TextDisabled
      }
      progressText
    ])
  }
}

let mkObjectiveAddition = @(text){
  rendObj = ROBJ_TEXTAREA
  behavior = Behaviors.TextArea
    size = FLEX_H
  margin = [0, 0, 0, idxMarkHeight + titleGap]
  color = color_addition
  text =loc(text)
}.__update(sub_txt, descriptionStyle)


function mkRequiresExtraction(is_requirement_complete) {
  let color = is_requirement_complete ? color_addition : color_progressedButNotComplete
  return {
    rendObj = ROBJ_TEXT
    text = loc("contract/require_extraction_short")
    animations = is_requirement_complete ? static [{ prop=AnimProp.opacity, from=1, to=0.3, easing=CosineFull, duration=0.8, loop=true, play=true }] : null
    color
    margin = static [0, 0, 0, idxMarkHeight + titleGap]
  }.__update(tiny_txt)
}

let resize = calc_str_box(mkRequiresExtraction(false))
let requiresExtractionPlaceholder = static {
  size = resize
  margin = [0, 0, 0, idxMarkHeight + titleGap]
}

let objectiveDescription = @(text){
  rendObj = ROBJ_TEXTAREA
  size = FLEX_H
  behavior = Behaviors.TextArea
  margin = static [0, 0, 0, idxMarkHeight + titleGap]
  text
}.__update(sub_txt, descriptionStyle)






let debugContractList = [
  {
    isSecretObjective = false
    contractType = 1
    name = "contract_daily_interact_containers"
    completed = true
    requireValue = 3
    failed = false
    currentValue = 3
    handledByGameTemplate = "objective_interact_containers"
    params = {}
    id = "3504789"
    requireExtraction = true
    blockExtraction = true
  }
  {
    isSecretObjective = false
    contractType = 0
    name = "contract_primary_extract_enriched_item"
    completed = false
    requireValue = 1
    failed = false
    currentValue = 0
    handledByGameTemplate = "objective_collect_item_with_tag"
    params = {
      itemTag = ["item_cassette+item_enriched"]
    }
    id = "3504707"
    requireExtraction = true
    blockExtraction = true
  }
  {
    isSecretObjective = false
    contractType = 0
    name = "contract_primary_extract_enriched_item"
    completed = false
    requireValue = 1
    failed = true
    currentValue = 0
    handledByGameTemplate = "objective_collect_item_with_tag"
    params = {
      itemTag = ["item_cassette+item_enriched"]
    }
    id = "3504707"
    requireExtraction = true
    blockExtraction = true
  }
  {
    isSecretObjective = false
    contractType = 1
    name = "contract_daily_collect_junk_items"
    completed = false
    requireValue = 15
    failed = false
    currentValue = 1
    handledByGameTemplate = "objective_collect_item_with_tag"
    params = {
      itemTag = ["item_civil"]
    }
    id = "3504788"
    requireExtraction = true
    blockExtraction = true
  }
  {
    isSecretObjective = false
    contractType = 1
    name = "contract_daily_collect_junk_items"
    completed = false
    requireValue = 15
    failed = false
    currentValue = 1
    handledByGameTemplate = "objective_collect_item_with_tag"
    params = {
      itemTag = ["item_civil"]
    }
    id = "3504788"
    requireExtraction = true
    blockExtraction = true
  }
  {
    isSecretObjective = false
    contractType = 1
    name = "contract_daily_collect_junk_items"
    completed = false
    requireValue = 15
    failed = false
    currentValue = 1
    handledByGameTemplate = "objective_collect_item_with_tag"
    params = {
      itemTag = ["item_civil"]
    }
    id = "3504788"
    requireExtraction = true
    blockExtraction = true
  }
  {
    isSecretObjective = false
    contractType = 1
    name = "contract_daily_collect_junk_items"
    completed = false
    requireValue = 15
    failed = false
    currentValue = 1
    handledByGameTemplate = "objective_collect_item_with_tag"
    params = {
      itemTag = ["item_civil"]
    }
    id = "3504788"
    requireExtraction = true
    blockExtraction = true
  }
  {
    isSecretObjective = false
    contractType = 1
    name = "contract_daily_collect_junk_items"
    completed = false
    requireValue = 15
    failed = false
    currentValue = 1
    handledByGameTemplate = "objective_collect_item_with_tag"
    params = {
      itemTag = ["item_civil"]
    }
    id = "3504788"
    requireExtraction = true
    blockExtraction = true
  }
  {
    isSecretObjective = false
    contractType = 1
    name = "contract_daily_collect_junk_items"
    completed = false
    requireValue = 15
    failed = false
    currentValue = 1
    handledByGameTemplate = "objective_collect_item_with_tag"
    params = {
      itemTag = ["item_civil"]
    }
    id = "3504788"
    requireExtraction = true
    blockExtraction = true
  }
  {
    isSecretObjective = false
    contractType = 1
    name = "contract_daily_interact_containers"
    completed = true
    requireValue = 4
    failed = false
    currentValue = 4
    handledByGameTemplate = "objective_interact_containers"
    params = {}
    id = "3504789"
    requireExtraction = false
    blockExtraction = true
  }
  {
    isSecretObjective = false
    contractType = 1
    name = "contract_daily_interact_containers"
    completed = true
    requireValue = 4
    failed = true
    currentValue = 2
    handledByGameTemplate = "objective_interact_containers"
    params = {}
    id = "3504789"
    requireExtraction = false
    blockExtraction = true
  }
  {
    isSecretObjective = false
    contractType = 1
    name = "contract_daily_interact_containers"
    completed = true
    requireValue = 4
    failed = true
    currentValue = 2
    handledByGameTemplate = "objective_interact_containers"
    params = {}
    id = "3504789"
    requireExtraction = false
    blockExtraction = true
  }
  {
    isSecretObjective = false
    contractType = 1
    name = "contract_daily_interact_containers"
    completed = true
    requireValue = 4
    failed = true
    currentValue = 2
    handledByGameTemplate = "objective_interact_containers"
    params = {}
    id = "3504789"
    requireExtraction = false
    blockExtraction = true
  }
  {
    isSecretObjective = false
    contractType = 1
    name = "contract_daily_interact_containers"
    completed = true
    requireValue = 4
    failed = true
    currentValue = 2
    handledByGameTemplate = "objective_interact_containers"
    params = {}
    id = "3504789"
    requireExtraction = false
    blockExtraction = true
  }
  {
    isSecretObjective = false
    contractType = 1
    name = "contract_daily_interact_containers"
    completed = true
    requireValue = 4
    failed = true
    currentValue = 2
    handledByGameTemplate = "objective_interact_containers"
    params = {}
    id = "3504789"
    requireExtraction = false
    blockExtraction = true
  }
  {
    isSecretObjective = false
    contractType = 1
    name = "contract_daily_interact_containers"
    completed = true
    requireValue = 4
    failed = true
    currentValue = 2
    handledByGameTemplate = "objective_interact_containers"
    params = {}
    id = "3504789"
    requireExtraction = false
    blockExtraction = true
  }
  {
    isSecretObjective = false
    contractType = 2
    name = "contract_factory_place_device_power_station"
    completed = false
    requireValue = 1
    failed = false
    currentValue = 0
    handledByGameTemplate = "objective_put_device"
    params = {
      questItemTemplate = ["quest_sensor_device_item"]
      staticTargetTag = ["place_device_power_station_quest"]
    }
    id = "3021811"
    requireExtraction = false
    blockExtraction = true
  }
  {
    isSecretObjective = false
    contractType = 2
    name = "contract_factory_raid_explorer"
    completed = true
    requireValue = 2
    failed = false
    currentValue = 2
    handledByGameTemplate = "objective_enter_to_raid"
    params = {}
    id = "3021819"
    requireExtraction = false
    blockExtraction = true
  }
]

let showDebugContracts = nestWatched("showDebugContracts", false)
console_register_command(
  function() {
    showDebugContracts.set(!showDebugContracts.get())
    console_print(showDebugContracts.get() ? "Enabled debug contracts" : "Disabled debug contracts")
  },
  "contracts.debugContractList"
)

ecs.register_es("player_daily_objectives_es",
  {
    [EventRewardDailyContract] = function(evt, eid, _comp) {
      if (watchedHeroPlayerEid.get() != eid)
        return
      let { reward = 0, statName = null } = evt
      if (reward <= 0 || statName == null)
        return
      let rewardLoc = $"stats/{statName}"
      let bodyText = $"{loc(rewardLoc)}: {monolithTokensTextIcon}{reward}"
      addPlayerLog({
        id = $"{statName}_{reward}"
        content = mkPlayerLog({
          titleText = loc("contract/dailyKillReward")
          titleFaIcon = "trophy"
          bodyText = bodyText
        })
        maxCount = 2
      })
    }
  }, { comps_rq = ["player"] })

let ragdollAttachedToQuery = ecs.SqQuery("ragdollAttachedToQuery", { comps_ro = [["ragdoll_phys_obj__attachedTo", ecs.TYPE_EID]] })
let possessedByPlayerQuery = ecs.SqQuery("possessedByPlayerQuery", { comps_ro = [
  ["possessedByPlr", ecs.TYPE_EID],
  ["human_equipment__slots", ecs.TYPE_OBJECT],
  ["cortical_vault_human_controller__dogtagItemDefaultTemplate", ecs.TYPE_STRING]
]})
let dogtagOwnerQuery = ecs.SqQuery("dogtagOwnerQuery", { comps_ro = [["name", ecs.TYPE_STRING]] })
let dogtagChronogeneQuery = ecs.SqQuery("dogtagChronogeneQuery",
  { comps_ro = [["dogtag_chronogene__dogtagItemTemplate ", ecs.TYPE_STRING]] })

ecs.register_es("player_hack_cortical_vault_es",
{
  [EventAmStorageHacked] = function(evt, eid, _comp) {
    if (evt.hackerActorEid != eid)
      return
    ragdollAttachedToQuery.perform(evt.ragdollPhysObjEid, function(_eid, ragdollComp) {
      if (ragdollComp?["ragdoll_phys_obj__attachedTo"] == null || ragdollComp["ragdoll_phys_obj__attachedTo"] == ecs.INVALID_ENTITY_ID)
        return
      possessedByPlayerQuery.perform(ragdollComp["ragdoll_phys_obj__attachedTo"], function(_eid1, actorComp) {
        if (actorComp?["possessedByPlr"] == null || actorComp["possessedByPlr"] == ecs.INVALID_ENTITY_ID)
          return
        local dogtagTemplate = null
        local dogtagIcon = null
        let chronogeneEid = actorComp?["human_equipment__slots"]?["chronogene_dogtag_1"]
        if (chronogeneEid != null) {
          if (chronogeneEid == ecs.INVALID_ENTITY_ID)
            dogtagTemplate = actorComp?["cortical_vault_human_controller__dogtagItemDefaultTemplate"]
          else
            dogtagChronogeneQuery.perform(chronogeneEid, function(_eid3, dogtagChronogeneComp ) {
              dogtagTemplate = dogtagChronogeneComp ?["dogtag_chronogene__dogtagItemTemplate"]
            })
          if (dogtagTemplate != null) {
            dogtagIcon = itemIconNoBorder(dogtagTemplate, {
              width = marketIconSize[1]
              height = marketIconSize[1]
              silhouette = ItemIconBlocked
              shading = "full"
              vplace = ALIGN_CENTER
              halign = ALIGN_CENTER
              hplace = ALIGN_CENTER
              margin = static [hdpx(4), 0, hdpx(4), hdpx(8)]
            })
          }
        }
        dogtagOwnerQuery.perform(actorComp["possessedByPlr"], function(_eid2, playerComp) {
          let name = playerComp?["name"] ?? ""
          addPlayerLog({
            id = $"dogtag_{evt.ragdollPhysObjEid}"
            content = mkPlayerLog({
              titleText = loc("item/received")
              titleFaIcon = "trophy"
              bodyText = name != "" ? loc("items/dogtag", { nickname = remap_nick(name) }) : loc("items/dogtag_nameless")
              bodyIcon = dogtagIcon
              bodyTextParams = {
                rendObj = ROBJ_TEXTAREA
                behavior = Behaviors.TextArea
              }.__merge(descriptionStyle)
            })
          })
        })
      })
    })
  }
}, { comps_rq = [ "watchedByPlr" ] })

function mkAnimations(trigger) {
  return [
    { prop=AnimProp.opacity, from=1, to=0, easing=OutCubic, duration=fadeoutTime+1, trigger}, 
  ]
}


let areTooManyContacts = @(contracts) contracts.len() > 10

let contractTypeHint = @(tag, locId) freeze({
  size = FLEX_H
  flow = FLOW_HORIZONTAL
  children = [
    tag,
    {
      rendObj = ROBJ_TEXT
      text = " - "
      color = InfoTextValueColor
    }.__update(sub_txt),
    {
      rendObj = ROBJ_TEXTAREA
      behavior = Behaviors.TextArea
      size = FLEX_H
      color = InfoTextValueColor
      text = loc(locId)
    }.__update(sub_txt)
  ]
})

let objectiveItem = function(obj, idx, allObjectives) {
  let totalNum = allObjectives.len()

  let { id, params, name, handledByGameTemplate, completed, currentValue, requireValue,
    failed = false requireExtraction = false, colorIdx = null, blockExtraction = false, itemTags = null } = obj
  let objectiveColor = colorblindPalette?[colorIdx] ?? color_common
  let isComplete = !requireExtraction && completed
  let isFailed = failed
  let tryToMinimize = totalNum > 8
  let tooMany = areTooManyContacts(allObjectives)
  let showCompact = tryToMinimize && (isFailed || isComplete)
  let sf = Watched(0)
  let addition = objectiveAdditions.get()?[name]
  let progress = currentValue != null && requireValue != null ? currentValue.tofloat()/requireValue : 1.00
  let isPrimary = isPrimaryObjective(obj)
  let descr = freeze({
    padding=1
    borderWidth=1
    color = InfoTextValueColor
    rendObj = ROBJ_FRAME
    size = static [sw(20), SIZE_TO_CONTENT]
    children = {
      flow = FLOW_VERTICAL
      size = FLEX_H
      gap = hdpx(5)
      padding = static [hdpx(10), hdpx(20)]
      children = [
        isPrimary ? contractTypeHint(starSub, "contract/primary") : null
        blockExtraction && !completed ? contractTypeHint(extractionBlockedSub, "contract/required") : null
        mkObjectiveProgression(name, handledByGameTemplate, completed, isFailed, { currentValue, requireValue, params, itemTags })
        mkProgressBar(currentValue, requireValue, isComplete, isFailed)
        requireExtraction ? { size = FLEX_H halign = ALIGN_CENTER children = mkRequiresExtraction(completed).__update(static {margin=null})} : null
        addition != null ? mkObjectiveAddition(addition) : null
        objectiveDescription(loc($"contract/{name}/desc", monolithContractText))
      ]
      rendObj = ROBJ_WORLD_BLUR_PANEL fillColor=ConsoleHeaderFillColor
    }
  })
  let contract = @() {
    watch = [hudIsInteractive, sf]
    behavior = hudIsInteractive.get() ? Behaviors.Button : null
    onElemState = @(s) sf.set(s)
    rendObj = ROBJ_WORLD_BLUR_PANEL
    fillColor = isPrimary ? Color(1, 5, 20, 100) : HudTipFillColor

    onHover = @(on) setTooltip(!on ? null : descr)

    padding = static [hdpx(5), hdpx(10)]
    size = FLEX_H
    flow = FLOW_HORIZONTAL
    gap = hdpx(10)
    valign = ALIGN_CENTER
    children = [
      mkObjectiveStatus(idx, objectiveColor, requireExtraction, progress, isPrimary, obj, tryToMinimize)
      {
        flow = FLOW_VERTICAL
        size = FLEX_H
        children = !showCompact ? [
          tryToMinimize ? null : mkObjectiveTitle(obj, tooMany),
          mkObjectiveProgression(name, handledByGameTemplate, completed, isFailed, { currentValue, requireValue, params, itemTags }),
          addition != null ? mkObjectiveAddition(addition) : null,
          !tryToMinimize || !completed ? {
            flow = FLOW_HORIZONTAL
            valign = ALIGN_CENTER
            size = FLEX_H
            children = [
              mkProgressBar(currentValue, requireValue, isComplete, isFailed)
              requireExtraction ? mkRequiresExtraction(completed) : requiresExtractionPlaceholder
            ]
          } : null
        ] : [mkObjectiveTitle(obj, tooMany)]
      }
    ]
  }
  return function() {
    if ((!objectiveStates.get()?[id].show && !showDebugContracts.get()))
      return static { watch = [objectiveStates, showDebugContracts] }
    return {
      flow = FLOW_HORIZONTAL
      watch = [objectiveStates, showDebugContracts]
      gap = hdpx(5)
      animations = mkAnimations(objectiveStates.get()?[id].fadeout)
      opacity = 1.0
      size = FLEX_H
      children = contract
    }
  }
}

function objectivesHud() {
  if ( isSpectator.get())
    return static { watch = isSpectator }
  let contracts = (showDebugContracts.get()
      ? dispatchColorsAndSort(debugContractList)
      : objectives.get()
    ).filter(@(v) v!= null)

  let content = @() {
    flow = FLOW_VERTICAL
    size = FLEX_H
    gap = hdpx(1)
    children = [
      @() {
        watch = static [objectiveStates, objectives, showDebugContracts, hudIsInteractive]
        size = FLEX_H
        children = (objectiveStates.get().findindex(@(v) v.show) != null || hudIsInteractive.get())
            && (showDebugContracts.get() ? dispatchColorsAndSort(debugContractList) : objectives.get())
                .findvalue(@(v) v?.blockExtraction && !v?.isSecretObjective && !v?.completed)!=null ? {
          padding = hdpx(5)
          rendObj = ROBJ_WORLD_BLUR_PANEL
          opacity = 1.0
          animations = mkAnimations(objectiveStates.get().findvalue(@(o) o?.show)?.fadeout)
          fillColor = Color(1, 5, 20, 100)
          size = FLEX_H
          children = { 
            flow = FLOW_HORIZONTAL
            size = FLEX_H
            gap = hdpx(5)
            children = [
              extractionBlockedSub,
              {
                rendObj = ROBJ_TEXTAREA
                behavior = Behaviors.TextArea
                size = FLEX_H
                text = loc("contract/completeAllExtractionTip")
              }.__update(sub_txt)
            ]
          }
        } : null
      }
    ].extend(contracts.map(objectiveItem))
  }
  return {
    watch = static [isSpectator, objectives, showDebugContracts]
    size = flex()
    key = "objectivesUI"
    flow = FLOW_VERTICAL
    children = [
      @() {
        watch = static [objectives, showDebugContracts, hudIsInteractive]
        size = flex()
        clipChildren = true
        valign = ALIGN_BOTTOM
        children = makeVertScrollExt(content, {size = flex(), styling = thinStyle, isInteractive = hudIsInteractive.get()})
      }
    ]
  }
}

console_register_command(function(){
  let idx = rand() % objectives.get().len()
  showObjective(objectives.get()[idx].id)
}, "ui.show_random_objective")

ecs.register_es("show_objectives_on_spawn_es",
  {[EventSpawnSequenceEnd] = @(...) showObjectives(15)},
  {comps_rq = ["watchedByPlr"]}
)

function stopAllObjectiveHudTimers() {
  gui_scene.clearTimer(closeWnd)
  gui_scene.clearTimer(startFadeout)
  objectiveStates.get().each(@(_, id) gui_scene.clearTimer(objectiveStates.get()[id].hide))
  objectiveStates.get().each(@(_, id) gui_scene.clearTimer(objectiveStates.get()[id].fadeout))
}

return {
  objectives
  quickUseObjective
  dispatchColorsAndSort

  objectivesHud
  setShowAllObjectives
  stopAllObjectiveHudTimers
}

from "%dngscripts/globalState.nut" import nestWatched
from "%ui/components/colors.nut" import TextDisabled, TextNormal, InfoTextValueColor, GreenSuccessColor,
  RedWarningColor, OrangeHighlightColor, colorblindPalette, HudTipFillColor,
  ConsoleHeaderFillColor
from "eventbus" import eventbus_subscribe
from "dasevents" import EventSpawnSequenceEnd, EventRewardDailyContract
from "%ui/hud/state/objectives_vars.nut" import dispatchColorsAndSort
from "math" import rand
from "%ui/popup/player_event_log.nut" import addPlayerLog, mkPlayerLog
from "%ui/fonts_style.nut" import fontawesome, sub_txt, tiny_txt
from "%ui/components/commonComponents.nut" import mkDescTextarea, descriptionStyle
from "%ui/hud/objectives/objective_components.nut" import mkObjectiveIdxMark, idxMarkDefaultSize, idxMarkHeight, getContractProgressionText, color_common
from "%ui/components/scrollbar.nut" import makeVertScrollExt, thinStyle
from "%ui/components/cursors.nut" import setTooltip
import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *
import "%ui/components/faComp.nut" as faComp
import "%ui/components/fontawesome.map.nut" as fa

let { objectives, objectiveAdditions } = require("%ui/hud/state/objectives_vars.nut")
let { isSpectator } = require("%ui/hud/state/spectator_state.nut")
let { hudIsInteractive } = require("%ui/hud/state/interactive_state.nut")
let { monolithTokensTextIcon } = require("%ui/mainMenu/currencyIcons.nut")
let { watchedHeroPlayerEid } = require("%ui/hud/state/watched_hero.nut")

let color_complete = Color(90,160,100)
let color_complete_bright = mul_color(GreenSuccessColor, 0.8, 2)
let color_failed = Color(130,80,80)
let color_addition = OrangeHighlightColor
let color_progressedButNotComplete = TextDisabled

let monolithContractText = {contract_monolith_danger = loc("contract_monolith_danger")}

let titleGap = hdpx(10)
let titleIconFontSize = hdpxi(20)
let extractionPicture = {
  rendObj = ROBJ_IMAGE
  hplace = ALIGN_CENTER
  vplace = ALIGN_BOTTOM
  image = Picture($"ui/skin#extraction_man.svg:{titleIconFontSize-hdpxi(2)}:{titleIconFontSize-hdpxi(2)}:P:K")
  color = Color(0,0,0)
  size = titleIconFontSize-hdpxi(2)
  animations = static [{ prop=AnimProp.color, from=Color(0,0,0), to=color_complete, easing=CosineFull, duration=0.8, loop=true, play=true }]
  keepAspect = KEEP_ASPECT_FIT
}

let extractionIcon = static {
  size = titleIconFontSize
  children = [
    {
      size = titleIconFontSize
      animations = static [{ prop=AnimProp.opacity, from=1, to=0.3, easing=CosineFull, duration=0.8, loop=true, play=true }]
      fillColor = color_addition
      rendObj = ROBJ_BOX
    }
    extractionPicture
  ]
}

let mkObjectiveStatus = function(idx, is_complete, is_failed, objectiveColor, requireExtraction, isRequirementComplete, progress) {
  if (is_failed)
    return static faComp("close", {color = RedWarningColor, fontSize = titleIconFontSize})
  if (requireExtraction && isRequirementComplete)
    return extractionIcon
  if (is_complete)
    return static faComp("check-square-o", {color = color_complete_bright, fontSize = titleIconFontSize})
  return mkObjectiveIdxMark($"{idx+1}", idxMarkDefaultSize, objectiveColor, progress)
}

let starSub = static faComp("star", { color = InfoTextValueColor, fontSize = sub_txt.fontSize, margin = [hdpx(2),0,0,0]})
let starTiny = static faComp("star", { color = InfoTextValueColor, fontSize = tiny_txt.fontSize, margin = [hdpx(2),0,0,0]})

let extractionBlockedSub = static faComp("extraction_point.svg", { color = RedWarningColor, margin = [hdpx(2),0,0,0] }.__merge(sub_txt))
let extractionBlockedTiny = static faComp("extraction_point.svg", { color = RedWarningColor, margin = [hdpx(2),0,0,0] }.__merge(tiny_txt))

let isPrimaryObjective = @(obj) (obj?.contractType ?? 1) == 0
let isObjCompleted = @(obj) !obj?.requireExtraction && obj?.completed

let mkObjectiveTitle = function(obj, minimize=false) {
  let { name, failed = false, blockExtraction = false, completed = false } = obj
  let isPrimary = isPrimaryObjective(obj)
  let title = loc($"contract/{name}")
  let isCompleted = isObjCompleted(obj)

  let descStyle = { color = failed ? color_failed : (isCompleted ? color_complete : InfoTextValueColor) }.__update(minimize ? tiny_txt : sub_txt)
  return {
    flow = FLOW_HORIZONTAL
    size = FLEX_H
    gap = hdpx(5)
    valign = ALIGN_CENTER
    children = [
      isPrimary ? (minimize ? starTiny : starSub) : null,
      (blockExtraction && !completed) ? (minimize ? extractionBlockedTiny : extractionBlockedSub) : null,
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
      }   1
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


let objectiveStates = Watched({})
let showDailyRewardObjectives = Watched(false)

let fadeoutTime = 2
let closeObjectiveTime = fadeoutTime - 0.1






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

function mkAnimations(trigger) {
  return [
    { prop=AnimProp.opacity, from=1, to=0, easing=OutCubic, duration=fadeoutTime+1, trigger}, 
  ]
}

function setShowAllObjectives(value) {
  showDailyRewardObjectives.set(value)
  log($"show all objectives.set({value}): have {objectiveStates.get().len()} objective states")
  objectiveStates.mutate(@(states) states.each(@(state) state.show = value))
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
      mkObjectiveStatus(idx, isComplete, isFailed, objectiveColor, requireExtraction, completed, progress)
      {
        flow = FLOW_VERTICAL
        size = FLEX_H
        children = !showCompact ? [
          mkObjectiveTitle(obj, tooMany),
          tryToMinimize ? null :
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

function closeWnd() {
  setShowAllObjectives(false)
}

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

function showObjective(id, timeTillHide = 5) {
  gui_scene.clearTimer(objectiveStates.get()[id].hide)
  gui_scene.clearTimer(objectiveStates.get()[id].fadeout)
  objectiveStates.mutate(@(states) states[id].show = true)
  if (timeTillHide < 0)
    return
  gui_scene.setTimeout(timeTillHide, @() startObjectiveFadeout(id), objectiveStates.get()[id].fadeout)
}

console_register_command(function(){
  let idx = rand() % objectives.get().len()
  showObjective(objectives.get()[idx].id)
}, "ui.show_random_objective")

ecs.register_es("show_objectives_on_spawn_es",
  {[EventSpawnSequenceEnd] = @(...) showObjectives(15)},
  {comps_rq = ["watchedByPlr"]}
)

eventbus_subscribe("objectives.update_state", function(changes) {
  changes.deletedObjectives.each(@(id) objectiveStates.mutate(@(states) states.$rawdelete(id)))
  objectiveStates.modify(@(states) states.__merge(changes.addedObjectives.map(@(id) [id, {
    show = false
    fadeout = $"fadeoutObjective_{id}"
    hide = $"hideObjective_{id}"
  }]).totable()))
  changes.updatedObjectives.extend(changes.addedObjectives).each(@(id) showObjective(id, 10))
})

function stopAllObjectiveHudTimers() {
  gui_scene.clearTimer(closeWnd)
  gui_scene.clearTimer(startFadeout)
  objectiveStates.get().each(@(_, id) gui_scene.clearTimer(objectiveStates.get()[id].hide))
  objectiveStates.get().each(@(_, id) gui_scene.clearTimer(objectiveStates.get()[id].fadeout))
}

return {
  objectivesHud
  setShowAllObjectives
  stopAllObjectiveHudTimers
}

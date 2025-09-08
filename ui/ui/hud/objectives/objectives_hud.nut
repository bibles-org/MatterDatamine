import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *
import "%ui/components/faComp.nut" as faComp

let { eventbus_subscribe } = require("eventbus")
let { EventSpawnSequenceEnd, EventRewardDailyContract } = require("dasevents")
let { dispatchColorsAndSort, objectives, objectiveAdditions } = require("%ui/hud/state/objectives_vars.nut")
let { isSpectator } = require("%ui/hud/state/spectator_state.nut")
let { hudIsInteractive } = require("%ui/hud/state/interactive_state.nut")
let { TextDisabled, TextNormal, InfoTextValueColor,
  GreenSuccessColor, RedWarningColor, OrangeHighlightColor
  colorblindPalette, HudTipFillColor, ConsoleHeaderFillColor } = require("%ui/components/colors.nut")
let { rand } = require("math")
let { monolithTokensTextIcon } = require("%ui/mainMenu/currencyIcons.nut")
let { addPlayerLog, mkPlayerLog } = require("%ui/popup/player_event_log.nut")
let { nestWatched } = require("%dngscripts/globalState.nut")
let { fontawesome, sub_txt, tiny_txt } = require("%ui/fonts_style.nut")
let { mkDescTextarea, descriptionStyle } = require("%ui/components/commonComponents.nut")
let { mkObjectiveIdxMark, idxMarkDefaultSize, idxMarkHeight, getContractProgressionText, color_common } = require("%ui/hud/objectives/objective_components.nut")
let { watchedHeroPlayerEid } = require("%ui/hud/state/watched_hero.nut")
let { makeVertScrollExt, thinStyle } = require("%ui/components/scrollbar.nut")
let fa = require("%ui/components/fontawesome.map.nut")
let { setTooltip } = require("%ui/components/cursors.nut")

let color_complete = Color(90,160,100)
let color_complete_bright = mul_color(GreenSuccessColor, 0.8, 2)
let color_failed = Color(130,80,80)
let color_addition = OrangeHighlightColor
let color_progressedButNotComplete = TextDisabled

let monolithContractText = {contract_monolith_danger = loc("contract_monolith_danger")}

let titleGap = hdpx(10)
let titleIconFontSize = hdpxi(20)
let extractionPicture = const {
  rendObj = ROBJ_IMAGE
  hplace = ALIGN_CENTER
  vplace = ALIGN_BOTTOM
  image = Picture($"ui/skin#extraction_man.svg:{titleIconFontSize-hdpxi(2)}:{titleIconFontSize-hdpxi(2)}:P:K")
  color = Color(0,0,0)
  size = titleIconFontSize-hdpxi(2)
  animations = const [{ prop=AnimProp.color, from=Color(0,0,0), to=color_complete, easing=CosineFull, duration=0.8, loop=true, play=true }]
  keepAspect = KEEP_ASPECT_FIT
}

let extractionIcon = const {
  size = titleIconFontSize
  children = [
    {
      size = titleIconFontSize
      animations = const [{ prop=AnimProp.opacity, from=1, to=0.3, easing=CosineFull, duration=0.8, loop=true, play=true }]
      fillColor = color_addition
      rendObj = ROBJ_BOX
    }
    extractionPicture
  ]
}

let mkObjectiveStatus = function(idx, is_complete, is_failed, objectiveColor, requireExtraction, isRequirementComplete, progress) {
  if (is_failed)
    return const faComp("close", {color = RedWarningColor, fontSize = titleIconFontSize})
  if (requireExtraction && isRequirementComplete)
    return extractionIcon
  if (is_complete)
    return const faComp("check-square-o", {color = color_complete_bright, fontSize = titleIconFontSize})
  return mkObjectiveIdxMark($"{idx+1}", idxMarkDefaultSize, objectiveColor, progress)
}

let star = const $"<star>{fa["star"]}</star>"
let starTagSub  = const { font = fontawesome.font fontSize = sub_txt.fontSize}
let starTagTiny  = const { font = fontawesome.font fontSize = tiny_txt.fontSize}

let warning = const $"<warning>{fa["warning"]}</warning>"
let warningTagSub  = const { font = fontawesome.font fontSize = sub_txt.fontSize, color = RedWarningColor }
let warningTagTiny  = const { font = fontawesome.font fontSize = tiny_txt.fontSize, color = RedWarningColor }

let isPrimaryObjective = @(obj) (obj?.contractType ?? 1) == 0
let isObjCompleted = @(obj) !obj?.requireExtraction && obj?.completed

let mkObjectiveTitle = function(obj, minimize=false) {
  let { name, failed = false, blockExtraction = false, completed = false } = obj
  let isPrimary = isPrimaryObjective(obj)
  let title = loc($"contract/{name}")
  let isCompleted = isObjCompleted(obj)
  let texts = (blockExtraction && !completed && !failed ? [warning] : [])
  if (isPrimary)
    texts.append(star)
  texts.append(title)
  let ftext = " ".join(texts)

  return mkDescTextarea(ftext, { color = failed ? color_failed : (isCompleted ? color_complete : InfoTextValueColor) }.__update(minimize
    ? const {tagsTable={star=starTagTiny, warning = warningTagTiny}}.__update(tiny_txt)
    : const {tagsTable={star=starTagSub, warning = warningTagSub}}.__update(sub_txt))
  )
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
    size = const [flex(), SIZE_TO_CONTENT]
    color
    text = getContractProgressionText({name = text, handledByGameTemplate = handled_template}.__update(params), false)
  }.__update(tiny_txt, descriptionStyle)
}
let failedText = loc($"contract/failed")

let progressBackColor = mul_color(TextNormal, 0.5, 2)
function mkProgressBar(currentValue, requiredValue, completed=false, failed=false) {
  let breakProgress = requiredValue <=20
  let progressText = {
    rendObj = ROBJ_TEXT text = $"{currentValue}/{requiredValue}"
    color = currentValue>=requiredValue ? color_complete : TextNormal margin=[0,0,0,hdpx(10)]
  }.__update(tiny_txt)
  let fullfiledcolor = failed || !completed ? TextNormal : color_complete_bright
  let backColor = failed ? mul_color(TextNormal, 0.3, 3) : progressBackColor
  return {
    size = const [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    gap  = breakProgress ? hdpx(2) : null
    children = (breakProgress
    ? array(requiredValue).map(@(_, i) {
        rendObj = ROBJ_SOLID
        size = const [flex(), hdpx(4)]
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
    size = [flex(), SIZE_TO_CONTENT]
  margin = [0, 0, 0, idxMarkHeight + titleGap]
  color = color_addition
  text =loc(text)
}.__update(sub_txt, descriptionStyle)


function mkRequiresExtraction(is_requirement_complete) {
  let color = is_requirement_complete ? color_addition : color_progressedButNotComplete
  return {
    rendObj = ROBJ_TEXT
    text = loc("contract/require_extraction_short")
    animations = is_requirement_complete ? const [{ prop=AnimProp.opacity, from=1, to=0.3, easing=CosineFull, duration=0.8, loop=true, play=true }] : null
    color
    margin = const [0, 0, 0, idxMarkHeight + titleGap]
  }.__update(tiny_txt)
}

let requiresExtractionPlaceholder = const {
  size = calc_str_box(mkRequiresExtraction(false))
  margin = [0, 0, 0, idxMarkHeight + titleGap]
}

let objectiveDescription = @(text){
  rendObj = ROBJ_TEXTAREA
  size = const [flex(), SIZE_TO_CONTENT]
  behavior = Behaviors.TextArea
  margin = const [0, 0, 0, idxMarkHeight + titleGap]
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
  log($"show all objectives({value}): have {objectiveStates.get().len()} objective states")
  objectiveStates.mutate(@(states) states.each(@(state) state.show = value))
}


let areTooManyContacts = @(contracts) contracts.len() > 10

let contractTypeHint = @(tag, locId) {
  rendObj = ROBJ_TEXTAREA
  behavior = Behaviors.TextArea
  size = const [flex(), SIZE_TO_CONTENT]
  color = InfoTextValueColor
  text = " - ".concat(tag, loc(locId))
  tagsTable = {star = starTagSub, warning = warningTagSub}
}.__update(sub_txt)

let objectiveItem = function(obj, idx, allObjectives) {
  let totalNum = allObjectives.len()

  let { id, params, name, handledByGameTemplate, completed, currentValue, requireValue,
    failed = false requireExtraction = false, colorIdx = null, blockExtraction = false } = obj
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
    size = const [sw(20), SIZE_TO_CONTENT]
    children = {
      flow = FLOW_VERTICAL
      size = const [flex(), SIZE_TO_CONTENT]
      gap = hdpx(5)
      padding = const [hdpx(10), hdpx(20)]
      children = [
        isPrimary ? const contractTypeHint(star, "contract/primary") : null
        blockExtraction && !completed ? contractTypeHint(warning, "contract/required") : null
        mkObjectiveProgression(name, handledByGameTemplate, completed, isFailed, { currentValue, requireValue, params })
        mkProgressBar(currentValue, requireValue, isComplete, isFailed)
        requireExtraction ? { size = const [flex(),SIZE_TO_CONTENT] halign = ALIGN_CENTER children = mkRequiresExtraction(completed).__update(const {margin=null})} : null
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

     padding = const [hdpx(5), hdpx(10)]
     size = const [flex(), SIZE_TO_CONTENT]
     flow = FLOW_HORIZONTAL
     gap = hdpx(10)
     valign = ALIGN_CENTER
     children = [
       mkObjectiveStatus(idx, isComplete, isFailed, objectiveColor, requireExtraction, completed, progress)
       {
         flow = FLOW_VERTICAL
         size = const [flex(), SIZE_TO_CONTENT]
         children = !showCompact ? [
           mkObjectiveTitle(obj, tooMany),
           tryToMinimize ? null :
             mkObjectiveProgression(isFailed ? failedText : name, handledByGameTemplate, completed, isFailed, { currentValue, requireValue, params }),
           addition != null ? mkObjectiveAddition(addition) : null,
           !tryToMinimize || !completed ? {
             flow = FLOW_HORIZONTAL
             valign = ALIGN_CENTER
             size = const [flex(), SIZE_TO_CONTENT]
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
      return const { watch = [objectiveStates, showDebugContracts] }
    return {
      flow = FLOW_HORIZONTAL
      watch = [objectiveStates, showDebugContracts]
      gap = hdpx(5)
      animations = mkAnimations(objectiveStates.get()?[id].fadeout)
      opacity = 1.0
      size = const [flex(), SIZE_TO_CONTENT]
      children = contract
    }
  }
}

function objectivesHud() {
  if ( isSpectator.get())
    return const { watch = isSpectator }
  let contracts = (showDebugContracts.get()
      ? dispatchColorsAndSort(debugContractList)
      : objectives.get()
    ).filter(@(v) v!= null)

  let content = @() {
    flow = FLOW_VERTICAL
    size = const [flex(), SIZE_TO_CONTENT]
    gap = hdpx(1)
    children = [
      @() {
        watch = const [objectiveStates, objectives, showDebugContracts, hudIsInteractive]
        size = const [ flex(), SIZE_TO_CONTENT ]
        children = (objectiveStates.get().findindex(@(v) v.show) != null || hudIsInteractive.get())
            && (showDebugContracts.get() ? dispatchColorsAndSort(debugContractList) : objectives.get())
                .findvalue(@(v) v?.blockExtraction && !v?.isSecretObjective && !v?.completed)!=null ? {
          padding = hdpx(5)
          rendObj = ROBJ_WORLD_BLUR_PANEL
          opacity = 1.0
          animations = mkAnimations(objectiveStates.get().findvalue(@(o) o?.show)?.fadeout)
          fillColor = Color(1, 5, 20, 100)
          size = const [ flex(), SIZE_TO_CONTENT ]
          children = const {
            size = [ flex(), SIZE_TO_CONTENT ]
            rendObj = ROBJ_TEXTAREA
            behavior = Behaviors.TextArea
            text = loc("contract/completeAllExtractionTip", {warning})
            tagsTable = {warning=warningTagSub.__merge({color = RedWarningColor})}
          }.__update(sub_txt)
        }: null
      }
    ].extend(contracts.map(objectiveItem))
  }
  return {
    watch = const [isSpectator, objectives, showDebugContracts]
    size = const [flex(), SIZE_TO_CONTENT]
    key = "objectivesUI"
    valign = ALIGN_CENTER
    flow = FLOW_VERTICAL
    children = [
      @() {
        watch = const [objectives, showDebugContracts, hudIsInteractive]
        size = const [flex(), hudIsInteractive.get() ? sh(80) : SIZE_TO_CONTENT]
        maxHeight = sh(62)
        clipChildren = true
        children = areTooManyContacts(showDebugContracts.get() ? dispatchColorsAndSort(debugContractList) : objectives.get()) && hudIsInteractive.get()
          ? makeVertScrollExt(content, const {size = [flex(), sh(62)], styling = thinStyle})
          : content
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

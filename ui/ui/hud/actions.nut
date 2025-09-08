import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *
from "dagor.debug" import logerr

let { actionItemName, selectedObjectEid, useActionType, useAltActionType, useActionKey, useAltActionKey, useActionAvailable,
      useActionHintType, customUsePrompt, customUsePromptParams,
      customUseAltPrompt, customUseAltPromptParams } = require("%ui/hud/state/actions_state.nut")
let { localPlayerEid, localPlayerTeam } = require("%ui/hud/state/local_player.nut")
let { isInMonsterState } = require("%ui/hud/state/hero_monster_state.nut")
let {inVehicle, inPlane, isVehicleAlive} = require("%ui/hud/state/vehicle_state.nut")
let {TextNormal} = require("%ui/components/colors.nut")
let {tipCmp} = require("%ui/hud/tips/tipComponent.nut")
let {isDowned} = require("%ui/hud/state/health_state.nut")
let { remap_nick } = require("%ui/helpers/remap_nick.nut")
let {sound_play} = require("%dngscripts/sound_system.nut")
let {ACTION_NONE, ACTION_USE, ACTION_EXTINGUISH, ACTION_REPAIR, ACTION_PICK_UP, ACTION_DENIED_TOO_MUCH_WEIGHT} = require("%ui/hud/human_actions.nut")
let { HumanUseObjectHintType } = require("%sqGlob/dasenums.nut")
let { currentMenuId } = require("%ui/hud/hud_menus_state.nut")
let { Market_id } = require("%ui/mainMenu/marketMenu.nut")

let showTeamQuickHint = Watched(true)
let teamHintsQuery = ecs.SqQuery("teamHintsQuery", {comps_ro =[["team__id", ecs.TYPE_INT],["team__showQuickHint", ecs.TYPE_BOOL, true]]})

localPlayerEid.subscribe(function(v) {
  if ( v != ecs.INVALID_ENTITY_ID ) {
    teamHintsQuery.perform(function (_eid, comp) {
        showTeamQuickHint(comp["team__showQuickHint"])
      },
      $"eq(team__id, {localPlayerTeam.value})"
    )
  }
})

function getPlayerItemOwnerName(entity_eid) {
    let playerItemOwner = ecs.obsolete_dbg_get_comp_val(entity_eid, "playerItemOwner")
    return playerItemOwner ? remap_nick(ecs.obsolete_dbg_get_comp_val(playerItemOwner, "name")) : loc("teammate")
}


const extinguishkeyId = "Human.VehicleMaintenance"

let actionsMap = {
  [ACTION_USE] = {
                    textf = function (item) {
                              if (item.usePrompt && item.usePrompt.len() > 0)
                                return loc(item.usePrompt, item.usePromptParams)

                              return loc("hud/use", "Use")
                            }
                    textColorf = @(_item) useActionAvailable.value ? TextNormal : Color(120, 120, 120, 120) 
  },
  [ACTION_EXTINGUISH] = {text = loc("hud/extinguish", "Hold to extinguish") key = extinguishkeyId},
  [ACTION_REPAIR] = {text = loc("hud/repair", "Hold to repair") key = extinguishkeyId},
  [ACTION_PICK_UP] = {
                        textf = function (item) {
                          let count = ecs.obsolete_dbg_get_comp_val(item.eid, "item__count")
                          let altText = loc($"{item.itemName}/pickup", {count = count, nickname = getPlayerItemOwnerName(item.eid)}, "")
                          if (altText && altText.len() > 0)
                            return altText
                          return loc("hud/pickup", "Pickup {item}", item)
                        }
                      },
  [ACTION_DENIED_TOO_MUCH_WEIGHT] = {
    textf = function(params) {
      params.item = params.item.subst({ nickname = getPlayerItemOwnerName(params.eid) })
      let isAM = ecs.obsolete_dbg_get_comp_val(params.eid, "item__am")
      let count = ecs.obsolete_dbg_get_comp_val(params.eid, "item__count") ?? 1
      params.count <- count
      if (!isAM)
        return loc("hud/too_much_weight_pickip", params)
      else
        return loc("hud/am_storage_full", params)
    }
    textColor = Color(186,68,98,255)
  },
}

let triggerBlinkAnimations = {}
let blinkAnimations = [
  { prop=AnimProp.translate, from=[0,0], to=[hdpx(20),0], duration=0.7, trigger = triggerBlinkAnimations, easing=Shake4, onEnter = @() sound_play("ui_sounds/login_fail")}
]

let showExitAction = Computed(@() (!inPlane.value) && isVehicleAlive.value)

function mkAction(
  use_action_type,
  use_action_key,
  act_scheme_cb,
  custom_use_prompt,
  custom_use_prompt_params) {

  return function() {
    let res = {
      size = SIZE_TO_CONTENT
      watch = [
        isDowned, selectedObjectEid, actionItemName, use_action_type, useActionAvailable,
        inVehicle, showExitAction, custom_use_prompt, custom_use_prompt_params, isInMonsterState,
        currentMenuId
      ]
    }
    if (isDowned.value && !inVehicle.value)
      return res

    let curAction = use_action_type.get()
    if (curAction == ACTION_NONE)
      return res

    let actScheme = act_scheme_cb()

    local children = []
    local text = actScheme?.text
    local isVisible = true
    if (text == null && "textf" in actScheme) {
      text = actScheme.textf({ eid=selectedObjectEid.value,
                               item=loc(actionItemName.value),
                               itemName=actionItemName.value,
                               usePrompt = custom_use_prompt.value,
                               usePromptParams = custom_use_prompt_params.value })
    }
    local key = actScheme?.key
    if (key == null && "keyf" in actScheme) {
      key = actScheme.keyf({ eid=selectedObjectEid.value })
    }
    if (key == null && useActionAvailable.value && selectedObjectEid.value != ecs.INVALID_ENTITY_ID)
      key = use_action_key.get()

    if (curAction == ACTION_USE && inVehicle.value) {
      text = loc("hud/leaveVehicle")
      isVisible = showExitAction.value
    }

    let textColor = ("textColorf" in actScheme) ? actScheme.textColorf({ eid=selectedObjectEid.value }) : actScheme?.textColor ?? TextNormal
    isVisible = isVisible && (currentMenuId.get() != Market_id)
    children = !isVisible ? [] : [tipCmp({
      text = text
      inputId = key
      textColor = textColor
      extraAnimations = blinkAnimations
    })]

    return res.__update({ children })
  }
}

function mkMainAction() {
  return mkAction(
    useActionType,
    useActionKey,
    function() {
      let curAction = useActionType.get()
      return actionsMap?[curAction]
    },
    customUsePrompt,
    customUsePromptParams)
}

function mkAltAction() {
  return mkAction(
    useAltActionType,
    useAltActionKey,
    @() actionsMap[ACTION_USE],
    customUseAltPrompt,
    customUseAltPromptParams)
}

let mainAction = mkMainAction()
let altAction = mkAltAction()

function mainActionDefault() {
  let res = {
    size = SIZE_TO_CONTENT
    watch = [useActionHintType]
  }

  if (useActionHintType.value != HumanUseObjectHintType.DEFAULT)
    return res

  return mainAction()
}

let mkActionsRoot = @(actions) {
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  hplace = ALIGN_CENTER
  vplace = ALIGN_BOTTOM

  children = {
    size=SIZE_TO_CONTENT
    flow = FLOW_VERTICAL
    halign = ALIGN_CENTER
    children = actions
  }
}

return {
  mainAction
  altAction
  allDefaultActions = mkActionsRoot([mainActionDefault])
}

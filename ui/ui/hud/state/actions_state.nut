import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let {ACTION_NONE} = require("%ui/hud/human_actions.nut")

let { HumanUseObjectHintType } = require("%sqGlob/dasenums.nut")
let useActionType = Watched(ACTION_NONE)
let useAltActionType = Watched(false)
let useActionAvailable = Watched(false)
let useActionHintType = Watched(HumanUseObjectHintType.DEFAULT)
let useActionKey = Watched("Human.Use")
let useAltActionKey = Watched("Human.UseAlt")
let selectedObjectEid = Watched(ecs.INVALID_ENTITY_ID)
let actionItemName = Watched(null)
let customUsePrompt = Watched(null)
let customUsePromptParams = Watched({})
let customUseAltPrompt = Watched(null)
let customUseAltPromptParams = Watched({})

ecs.register_es("hero_state_hud_state_ui_es", {
  [["onInit", "onChange"]] = function(_eid,comp) {
    useActionType.set(comp.useActionAvailable)
    useAltActionType.set(comp.useAltActionAvailable)
    useActionAvailable.set(comp.human_use_object__useActionAvailable)
    useActionHintType.set(comp.human_use_object__useActionHintType)
    selectedObjectEid.set(comp.human_use_object__selectedObject)
    actionItemName.set(comp.actionItemName)
    customUsePrompt.set(comp.customUsePrompt)
    customUsePromptParams.set(comp.customUsePromptParams?.getAll() ?? {})
    customUseAltPrompt.set(comp.customUseAltPrompt)
    customUseAltPromptParams.set(comp.customUseAltPromptParams?.getAll() ?? {})
  }
  function onDestroy(_eid,_comp) {
    useActionType.set(ACTION_NONE)
    selectedObjectEid.set(ecs.INVALID_ENTITY_ID)
    actionItemName.set(null)
    customUsePrompt.set(null)
    customUsePromptParams.set({})
    customUseAltPrompt.set(null)
    customUseAltPromptParams.set({})
  }
}, {
  comps_rq = ["watchedByPlr"]
  comps_track = [
    ["useActionAvailable", ecs.TYPE_INT],
    ["useAltActionAvailable", ecs.TYPE_INT],
    ["human_use_object__useActionAvailable", ecs.TYPE_BOOL],
    ["human_use_object__useActionHintType", ecs.TYPE_INT],
    ["human_use_object__selectedObject", ecs.TYPE_EID, ecs.INVALID_ENTITY_ID],
    ["actionItemName", ecs.TYPE_STRING, null],
    ["customUsePrompt", ecs.TYPE_STRING, null],
    ["customUsePromptParams", ecs.TYPE_OBJECT, null],
    ["customUseAltPrompt", ecs.TYPE_STRING, null],
    ["customUseAltPromptParams", ecs.TYPE_OBJECT, null],
  ]
})

return {
  useActionAvailable,
  useActionHintType,
  selectedObjectEid,
  actionItemName,

  useActionType,
  useActionKey,
  customUsePrompt,
  customUsePromptParams,

  useAltActionType,
  useAltActionKey,
  customUseAltPrompt,
  customUseAltPromptParams,
}

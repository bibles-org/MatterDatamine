import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

import "%ui/components/msgbox.nut" as msgbox
from "%dngscripts/sound_system.nut" import sound_play

let { onlineSettingUpdated, settings } = require("%ui/options/onlineSettings.nut")
let { toIntegerSafe, isStringInteger } = require("%sqstd/string.nut")
let { dangers } = require("%ui/hud/menus/notes/articles/dangers.nut")
let { newspaper } = require("%ui/hud/menus/notes/articles/newspaper.nut")
let { onboarding } = require("%ui/hud/menus/notes/articles/onboarding.nut")
let { shelter } = require("%ui/hud/menus/notes/articles/shelter.nut")
let { world_records } = require("%ui/hud/menus/notes/articles/world_records.nut")
let { isOnboardingMemory } = require("%ui/hud/state/onboarding_state.nut")
let { startswith } = require("string")
let { find_local_player } = require("%dngscripts/common_queries.nut")
let { EventUnlockAppear,
      CmdStartAssistantSpeak,
      sendNetEvent,
      CmdConnectToHost } = require("dasevents")

const MAX_VISIBLE_TITLE_CHARS = 40
const MAX_MESSAGE_CHARS = 1000
const MAX_NOTE_COUNT = 1000

const AGENCY_ID = "agency"
const DANGER_ID = "dangers"
const NEWSPAPER_ID = "newspaper"
const SHELTER_ID = "shelter"
const WORLD_ID = "world"


let predefinedNotes = Watched([].extend(dangers, newspaper, onboarding, shelter, world_records))

let debugShowAllNotes = Watched(false)
let curNote = Watched(null)
let selectedNoteBlockId = Watched(null)
let editMode = Watched(false)
let shownTextNote = Watched(null)

let cachedNoteSelection = Watched({})

function clearTextOnlyNote() {
  shownTextNote.set(null)
}

function showTextOnlyNote(note, seconds) {
  shownTextNote.set(note)
  gui_scene.resetTimeout(seconds, clearTextOnlyNote)
}

console_register_command(@() debugShowAllNotes.modify(@(v) !v), "notes.show_all")

function saveUnreadNotes() {
  if (!onlineSettingUpdated.get() || isOnboardingMemory.get())
    return
  settings.mutate(@(v) v["unread_notes"] <- predefinedNotes.get()
    .filter(@(note) note?.markUnread ?? false).map(@(note) note.id))
}

function loadUnreadNotes() {
  if (!onlineSettingUpdated.get())
    return
  let unreadNotes = settings.get()?["unread_notes"] ?? []
  predefinedNotes.mutate(function(notes) {
    foreach (note in notes) {
      if (unreadNotes.contains(note.id))
        note.markUnread <- true
      else
        note.markUnread <- false
    }
  })
}

onlineSettingUpdated.subscribe(@(_) loadUnreadNotes())
isOnboardingMemory.subscribe(@(v) v ? null : loadUnreadNotes())

let emptyNote = {
  noteText = "",
  userNote = true,
  isUnlocked = true,
  markUnread = false
}

ecs.register_es("track_player_notes",
  {
    [["onInit","onChange"]] = function(_eid, comp) {
      if (!comp.is_local){
        return
      }
      let unlockedNotes = comp.active_matter_player__unlockedNotes.getAll()
      predefinedNotes.mutate(function(notes) {
        foreach (note in notes) {
          note.__update({isUnlocked = unlockedNotes.contains(note.id)})
        }
      })
    }
  },
  {
    comps_track = [
      ["active_matter_player__unlockedNotes", ecs.TYPE_STRING_LIST],
      ["is_local", ecs.TYPE_BOOL]
    ]
  }
)
ecs.register_es("add_first_user_note_es",
  {
    [["onInit"]] = function(_eid, _comp) {
      
      if (settings.get()?.userNotes == null)
        settings.mutate(@(v) v["userNotes"] <- [])
      if (settings.get()?.userNotes.len() == 0) {
        settings.mutate(@(v) v["userNotes"].append(
          {}.__merge(emptyNote, { noteText = loc("notes/first_user_note") })
        ))
      }
    }
  },
  {
    comps_rq=[["onboarding_phase_monolith", ecs.TYPE_TAG]]
  }
)

let checkScriptExistanceQuery = ecs.SqQuery("checkScriptExistanceQuery", {
  comps_ro=[
    ["assistant__script", ecs.TYPE_SHARED_OBJECT]
  ]
})

function doesAssistantScriptExist(player, script_name) {
  local result = false
  checkScriptExistanceQuery.perform(player, function(_eid, comp) {
    result = comp.assistant__script?[script_name] != null
  })
  return result
}

ecs.register_es("track_new_notes",
  { [EventUnlockAppear] = function(evt, _eid, _comp) {
      if (!startswith(evt.unlockName, "note_"))
        return
      let player = find_local_player()
      if (doesAssistantScriptExist(player, evt.unlockName))
        ecs.g_entity_mgr.sendEvent(player, CmdStartAssistantSpeak({ scriptName = evt.unlockName, skipBeepSound = false }))
      else
        showTextOnlyNote(evt.unlockName, 8.0)

      curNote.set(evt.unlockName)
      let blockId = predefinedNotes.get().findvalue(@(note) note.id == evt.unlockName)?.type
      if (blockId != null){
        selectedNoteBlockId.set(blockId)
        cachedNoteSelection.mutate(@(v) v[blockId] <- evt.unlockName)
      }
      predefinedNotes.mutate(function(notes) {
        foreach (note in notes) {
          if (note.id == evt.unlockName) {
            note.markUnread <- true
            break
          }
        }
      })
      saveUnreadNotes()
      sound_play("ui_sounds/button_ok_reward")
    }
  }
  { comps_rq = ["player"] }
  { tags = "gameClient" }
)

console_register_command(@(unlockName) sendNetEvent(find_local_player(), EventUnlockAppear({ unlockName })), "notes.open_note")
console_register_command(@() settings.mutate(@(v) v.$rawdelete("userNotes")), "notes.clear_user_notes")

function notesLimitReached() {
  msgbox.showMsgbox({
    text = loc("notes/notes_limit_reached"),
    buttons = [
      { text = loc("Ok") }
    ]
  })
}

function addUserNote() {
  if (settings.get()?.userNotes == null) {
    settings.mutate(function(v) {
      v["userNotes"] <- []
    })
  }
  if (settings.get().userNotes.len() >= MAX_NOTE_COUNT) {
    notesLimitReached()
    return null
  }
  local newNoteId = null
  settings.mutate(function(v) {
    v["userNotes"].append(clone emptyNote)
  })
  newNoteId = (settings.get().userNotes.len() - 1).tostring()
  return newNoteId
}

function updateUserNote(noteId, noteText) {
  if (noteId==null || !isStringInteger(noteId))
    return
  noteId = toIntegerSafe(noteId)
  if (noteId==null || settings.get()?["userNotes"] == null || noteId >= settings.get()["userNotes"].len())
    return
  settings.mutate(@(v) v["userNotes"][toIntegerSafe(noteId)].__update({ noteText }))
}

function removeUserNote(noteId) {
  if (noteId==null || !isStringInteger(noteId))
    return
  noteId = toIntegerSafe(noteId)
  settings.mutate(function(v) {
    if (v?["userNotes"] == null || noteId >= v["userNotes"].len())
      return
    v["userNotes"].remove(noteId)
  })
}

let assistantSpeakingScript = Watched(null)

ecs.register_es("track_assistant_speak",
  {
    [["onInit", "onChange"]] = function(_evt, _eid, comp) {
      if (comp.is_local) {
        local scrName = comp["assistant__currentScriptName"]
        if (scrName == "")
          scrName = null
        assistantSpeakingScript.set(scrName)
        if (scrName != null){
          curNote.set(scrName)
          let blockId = predefinedNotes.get().findvalue(@(note) note.id == scrName)?.type
          if (blockId != null){
            selectedNoteBlockId.set(blockId)
            cachedNoteSelection.mutate(@(v) v[blockId] <- scrName)
          }
        }
      }
    },
    onDestroy = function(_eid, comp){
      if (comp.is_local) {
        assistantSpeakingScript.set(null)
      }
    }
  },
  { comps_ro = [["is_local", ecs.TYPE_BOOL]],
    comps_track = [["assistant__currentScriptName", ecs.TYPE_STRING]]
  },
  { tags = "gameClient" }
)

ecs.register_es("notes_clear_on_host_connection", {
  [CmdConnectToHost] = function(...) {
    curNote.set(null)
    assistantSpeakingScript.set(null)
  }
}, {comps_rq=["eid"]})

return {
  MAX_VISIBLE_TITLE_CHARS,
  MAX_MESSAGE_CHARS,
  predefinedNotes,
  saveUnreadNotes,
  addUserNote,
  updateUserNote,
  removeUserNote,
  editMode,
  curNote,
  debugShowAllNotes,
  shownTextNote,
  doesAssistantScriptExist,
  assistantSpeakingScript,
  selectedNoteBlockId,
  cachedNoteSelection,
  AGENCY_ID,
  DANGER_ID,
  NEWSPAPER_ID,
  SHELTER_ID,
  WORLD_ID,
}

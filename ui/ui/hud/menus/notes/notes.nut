from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
import "%ui/components/faComp.nut" as faComp
import "utf8" as utf8
import "%ui/components/msgbox.nut" as msgbox

from "%dngscripts/common_queries.nut" import find_local_player
from "%ui/components/button.nut" import button
from "%ui/components/colors.nut" import ControlBg, TextInputBdNormal, TextInputBdActive,
  TextInputBgNormal, TextInputBgActive, TextNormal, TextHighlight, TextDisabled
from "%ui/components/commonComponents.nut" import mkSelectPanelItem, mkSelectPanelTextCtor, mkText, VertSelectPanelGap, BD_LEFT
from "%ui/components/formatText.nut" import formatText
from "%ui/components/scrollbar.nut" import makeVertScrollExt, thinAndReservedPaddingStyle
from "%ui/fonts_style.nut" import sub_txt, body_txt, h1_txt
from "%ui/hud/state/notes.nut" import predefinedNotes, saveUnreadNotes, addUserNote, updateUserNote,
  removeUserNote, editMode, curNote, debugShowAllNotes, MAX_VISIBLE_TITLE_CHARS, MAX_MESSAGE_CHARS,
  doesAssistantScriptExist, assistantSpeakingScript, selectedNoteBlockId, cachedNoteSelection, AGENCY_ID, DANGER_ID,
  NEWSPAPER_ID, SHELTER_ID, WORLD_ID
from "%ui/mainMenu/notificationMark.nut" import mkNotificationCircle, notificationCircleSize
from "dasevents" import CmdStartAssistantSpeak, CmdStopAssistantSpeak, CmdStartOnboardingMemory, CmdInterruptOnboardingMemory
let { isInQueue, leaveQueue } = require("%ui/quickMatchQueue.nut")
let { isInSquad, isSquadLeader, myExtSquadData } = require("%ui/squad/squadManager.nut")
let { isOnboarding, isOnboardingMemory } = require("%ui/hud/state/onboarding_state.nut")
let { isOnPlayerBase } = require("%ui/hud/state/gametype_state.nut")
let { settings } = require("%ui/options/onlineSettings.nut")
let { deep_clone } = require("%sqstd/underscore.nut")
let { localPlayerEid } = require("%ui/hud/state/local_player.nut")

const USER_NOTE_BLOCK_ID = "userNote"


let userNoteText = Watched("")
local initialMessage = ""
let iconHeight = hdpxi(20)

let mkNotesIcon = @(icon) {
  rendObj = ROBJ_IMAGE
  size = [iconHeight, iconHeight]
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  color = TextDisabled
  image = Picture($"!ui/skin#notes/{icon}.svg:{iconHeight}:{iconHeight}:P")
}

let userNoteIcon = mkNotesIcon("user_note")
let folderIcon = mkNotesIcon("agency_note")
let closedFolderIcon = mkNotesIcon("agency_note_unselect")
let raidNoteIcon = mkNotesIcon("raid_note")

let blockIcons = {
  [AGENCY_ID] = folderIcon,
  [DANGER_ID] = folderIcon,
  [NEWSPAPER_ID] = folderIcon,
  [SHELTER_ID] = folderIcon,
  [WORLD_ID] = folderIcon,
  [USER_NOTE_BLOCK_ID] = userNoteIcon,
}

function cancelEdit() {
  editMode.set(false)
  userNoteText.set("")
}

function markNoteAsRead(noteId) {
  let idx = predefinedNotes.get().findindex(@(note) note.id == noteId)
  let selectedTitle = selectedNoteBlockId.get() == predefinedNotes.get()?[idx].type
  if (idx == null || !selectedTitle)
    return
  predefinedNotes.mutate(@(notes) notes[idx].markUnread <- false)
  saveUnreadNotes()
}

function cancelEditWithConfirm() {
  if (initialMessage == userNoteText.get()) {
    cancelEdit()
    removeUserNote(curNote.get())
    return
  }
  msgbox.showMsgbox({
    text = loc("notes/cancel_edit_confirm")
    buttons = [
      {
        text = loc("Yes")
        action = cancelEdit
        isCurrent = true
      },
      {
        text = loc("No")
        isCancel = true
      }
    ]
  })
}

function cancelEditWithSave() {
  if (!editMode.get())
    return
  msgbox.showMsgbox({
    text = loc("notes/save_edit_confirm")
    buttons = [
      {
        text = loc("Yes")
        action = function() {
          updateUserNote(curNote.get(), userNoteText.get())
          cancelEdit()
        }
        isCurrent = true
      },
      {
        text = loc("No")
        action = cancelEdit
        isCancel = true
      }
    ]
  })
}

function confirmDelete(userNotes) {
  msgbox.showMsgbox({
    text = loc("notes/delete_confirm")
    buttons = [
      {
        text = loc("Yes")
        action = function() {
          removeUserNote(curNote.get())
          if (userNotes.get().len() <= 0)
            selectedNoteBlockId.set(AGENCY_ID)
        }
        isCurrent = true
      },
      {
        text = loc("No")
        isCancel = true
      }
    ]
  })
}


let addNoteButton = button({
    rendObj = ROBJ_TEXT
    text = loc("notes/add")
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    padding = hdpx(10)
  }.__update(body_txt),
  function() {
    let id = addUserNote()
    if (id != null){
      selectedNoteBlockId.set(USER_NOTE_BLOCK_ID)
      curNote.set(id)
      cachedNoteSelection.mutate(@(v) v[USER_NOTE_BLOCK_ID] <- id)
      editMode.set(true)
    }
  },
  {
    size = [flex(), SIZE_TO_CONTENT]
  }
)

let addNoteButtonDisabled = button({
    rendObj = ROBJ_TEXT
    text = loc("notes/add")
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    padding = hdpx(10)
  }.__update(body_txt),
  @() null,
  {
    size = [flex(), SIZE_TO_CONTENT]
    isEnabled = false
  }
)

let circleButton = function(fa, txt, func) {
  let stateFlags = Watched(0)
  let children = {
    flow = FLOW_HORIZONTAL
    gap = hdpx(10)
    halign = ALIGN_LEFT
    valign = ALIGN_CENTER
    children = [
      {
        rendObj = ROBJ_VECTOR_CANVAS
        size = [ hdpx(20), hdpx(20) ]
        commands = [
          [VECTOR_WIDTH, 1],
          [VECTOR_FILL_COLOR, (stateFlags.get() & S_HOVER) ? Color(100, 100, 100, 100) : Color(0, 0, 0, 0)],
          [VECTOR_ELLIPSE, 50, 50, 50, 50]
        ]
        children = faComp(fa, {
          pos = [ hdpx(1), 0 ]
          hplace = ALIGN_CENTER
          vplace = ALIGN_CENTER
          fontSize = hdpx(8)
        })
      }
      mkText(txt)
    ]
  }
  return button(children, func, {
    padding = hdpx(10)
  })
}

let playScriptButton = @(script) circleButton("play", loc("tip/assistant_voicing_note"), function(){
  ecs.g_entity_mgr.sendEvent(find_local_player(), CmdStartAssistantSpeak({ scriptName = script }))
})

let playerStopButton = circleButton("stop", loc("tip/assistant_mute"), function() {
  ecs.g_entity_mgr.sendEvent(find_local_player(), CmdStopAssistantSpeak())
})

function mkPlayStopButtons(note) {
  let hasAssistant = Computed(@() doesAssistantScriptExist(localPlayerEid.get(), note))
  return function() {
    if (!hasAssistant.get())
      return { watch = hasAssistant }
    return {
      watch = [assistantSpeakingScript, hasAssistant]
      children = assistantSpeakingScript.get() == note ?
        playerStopButton :
        playScriptButton(note)
    }
  }
}

let memoryButtonFromTextAndCb = @(text, cb) button({
    rendObj = ROBJ_TEXT
    text
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    padding = hdpx(10)
}, cb)

function mkDeleteButton(userNotes) {
  return button({
    rendObj = ROBJ_TEXT
    text = loc("notes/delete")
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    padding = hdpx(10)
  }, @() confirmDelete(userNotes))
}


function splitTitleAndContent(note, limit = null) {
  if (!note?.noteText)
    return const { title = "", content = "" }
  let paragraphs = note.noteText.split("\n")
  local title
  if (limit && paragraphs[0].len() > limit)
    title = $"{paragraphs[0].slice(0, limit - 3)}..."
  else
    title = paragraphs[0]

  let content = "\n".join(paragraphs.slice(1))
  return { title, content }
}

let notificationIcon = freeze({
  valign = ALIGN_CENTER
  halign = ALIGN_CENTER
  size = [ iconHeight, iconHeight ]
  padding = hdpx(2)
  children = mkNotificationCircle([44, 52])
  hplace = ALIGN_LEFT
})

function mkEditButton(){
  return button({
    rendObj = ROBJ_TEXT
    text = loc("notes/edit")
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    padding = hdpx(10)
  }, function() {
    editMode.set(true)
    initialMessage = userNoteText.get()
  })
}

function mkApplyButton() {
  return button({
    rendObj = ROBJ_TEXT
    text = loc("notes/apply")
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    padding = hdpx(10)
  }, function() {
    updateUserNote(curNote.get(), userNoteText.get())
    editMode.set(false)
  })
}

function mkCancelButton(){
  return button({
    rendObj = ROBJ_TEXT
    text = loc("notes/cancel")
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    padding = hdpx(10)
  }, cancelEditWithConfirm)
}

function mkTextAreaEdit(state, size, fontsStyle, limit) {
  let editableTextHandle = EditableText(state.get())
  let sf = Watched(0)
  let group = ElemGroup()
  let textAreaEdit = @(){
    watch = sf
    group
    size
    rendObj = ROBJ_TEXTAREA
    behavior = [Behaviors.TextAreaEdit, Behaviors.WheelScroll, DngBhv.ActivateActionSet]
    actionSet = "StopInput"
    editableText = editableTextHandle
    font = fontsStyle.font
    color = sf.get() & S_KB_FOCUS ? TextHighlight : TextNormal
    fontSize = fontsStyle.fontSize
    onAttach = @(elem) set_kb_focus(elem)
    onElemState = @(v) sf.set(v)
    minHeight = hdpx(100)
    function onChange(etext) {
      let s = utf8(etext.text)
      if (s.charCount() > limit) {
        editableTextHandle.text = "".concat(utf8(editableTextHandle.text).slice(0, limit))
        return
      }
      state.set(editableTextHandle.text)
    }
  }
  return @() {
    watch = sf
    group
    size = size
    rendObj = ROBJ_BOX
    borderWidth = 1
    padding = hdpx(10)
    borderColor = sf.get() & S_KB_FOCUS ? TextInputBdActive : TextInputBdNormal
    fillColor = sf.get() & S_KB_FOCUS ? TextInputBgActive : TextInputBgNormal
    children = textAreaEdit
  }
}

function mkEditNote(note){
  userNoteText.set(note.noteText)
  let content = mkTextAreaEdit(userNoteText, [flex(), SIZE_TO_CONTENT], body_txt, MAX_MESSAGE_CHARS)
  return {
    size = [flex(3), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    margin = [hdpx(20), 0, 0, 0]
    children = [
      content
    ]
  }
}

function userContent(note) {
  let { title, content } = splitTitleAndContent(note)
  return [
    {t="h1" v=title}
    {t="paragraph" v=content}
  ]
}

function setDefaultNote(list, blockId = null) {
  
  if (blockId == null) {
    let res = list.filter(@(note) (note?.isUnlocked ?? false) && note?.markUnread)?[0]
      ?? list.filter(@(note) debugShowAllNotes.get() || (note?.isUnlocked ?? false))?[0]
    if (res != null) {
      curNote.set(res.id)
      selectedNoteBlockId.set(res.type)
      cachedNoteSelection.mutate(@(v) v[res.type] <- res.id)
      return
    }
  }

  
  let res = cachedNoteSelection.get()?[blockId]
    ?? list.filter(@(note) note?.type == blockId && (debugShowAllNotes.get() || (note?.isUnlocked ?? false)))?[0]

  if (res != null) {
    curNote.set(res?.id ?? res)
    cachedNoteSelection.mutate(@(v) v[blockId] <- res?.id ?? res)
  }
}

function mkNoteTab(){
  let userNotes = Computed(function() {
    if (settings.get()?.userNotes != null) {
      let res = []
      settings.get().userNotes.each(@(v) res.append(v.__merge({ type = USER_NOTE_BLOCK_ID })))
      return res
    }
    return []
  })

  let notesList = Computed(function() {
    let notesV = deep_clone(predefinedNotes.get())
    let userNotesV = userNotes.get().map(@(note, idx) note.__merge({ id = idx.tostring() }))
    return [].extend(notesV, userNotesV)
  })

  setDefaultNote(notesList.get(), selectedNoteBlockId.get())

  let mkNotesListBlock = @(list) {
    size = [sw(19), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    gap = VertSelectPanelGap
    hplace = ALIGN_RIGHT
    onAttach = @() markNoteAsRead(curNote.get())
    children = list.map(function(note) {
      local title
      if (note?.userNote)
        title = splitTitleAndContent(note, MAX_VISIBLE_TITLE_CHARS).title
      else
        title = note.title

      let icon = raidNoteIcon
      let textCtor = mkSelectPanelTextCtor(title, { size = [flex(), SIZE_TO_CONTENT]  }.__update(body_txt))
      return mkSelectPanelItem({
        state = curNote
        idx = note.id
        border_align = BD_LEFT
        onSelect = function(idx){
          if (editMode.get()){
            cancelEditWithConfirm()
            return
          }
          curNote.set(idx)
          cachedNoteSelection.mutate(@(v) v[note.type] <- idx)
          markNoteAsRead(idx)
        }
        visual_params = {
          size = [flex(), hdpx(50)]
        }
        children = @(params) {
          size = [flex(), SIZE_TO_CONTENT]
          flow = FLOW_HORIZONTAL
          gap = hdpx(5)
          valign = ALIGN_CENTER
          vplace = ALIGN_CENTER
          clipChildren = true
          children = [
            note?.markUnread ? notificationIcon : icon
            textCtor(params)
          ]
        }
      })
    })
  }

  function mkNotesBlockTitle(data, hasAnyUnseen, isSelected) {
    let { id, locId } = data
    let icon = id == USER_NOTE_BLOCK_ID || isSelected ? blockIcons[id] : closedFolderIcon
    let textCtor = mkSelectPanelTextCtor(loc(locId), body_txt)
    return mkSelectPanelItem({
      state = selectedNoteBlockId
      idx = id
      border_align = BD_LEFT
      onSelect = function(_) {
        if (editMode.get()) {
          cancelEditWithConfirm()
          return
        }
        if (selectedNoteBlockId.get() != id){
          selectedNoteBlockId.set(id)
          setDefaultNote(notesList.get(), id)
        }
        else
          selectedNoteBlockId.set(null)
      }
      visual_params = {
        size = [flex(), hdpx(50)]
      }
      children = @(params) {
        size = flex()
        flow = FLOW_HORIZONTAL
        valign = ALIGN_CENTER
        gap = hdpx(5)
        children = [
          hasAnyUnseen ? notificationIcon : icon
          textCtor(params)
        ]
      }
    })
  }

  function mkNotesBlock(data) {
    let { id } = data
    let isSelected = Computed(@() selectedNoteBlockId.get() == id)
    return function() {
      let noteListToShow = notesList.get()
        .filter(@(note) note?.type == id && (debugShowAllNotes.get() || (note?.isUnlocked ?? false)))
      if (noteListToShow.len() == 0)
        return { watch = notesList }
      let hasAnyUnseen = noteListToShow.findvalue(@(v) v?.markUnread) != null
      return {
        watch = [isSelected, debugShowAllNotes, notesList]
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_VERTICAL
        gap = VertSelectPanelGap
        children = [
          mkNotesBlockTitle(data, hasAnyUnseen, isSelected.get())
          isSelected.get() ? mkNotesListBlock(noteListToShow) : null
        ]
      }
    }
  }

  let blocks = notesList.get().reduce(function(acc, note) {
    if (acc.findindex(@(v) v.id == note.type) == null)
      acc.append({ id = note.type, locId = $"notes/{note.type}"})
    return acc
  }, [])

  let leftColumn = @() {
    watch = editMode
    size = [sw(20), flex()]
    color = ControlBg
    flow = FLOW_VERTICAL
    gap = hdpx(40)
    children = [
      makeVertScrollExt({
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_VERTICAL
        gap = hdpx(5)
        children = blocks.map(mkNotesBlock)
      }, {
        size = flex()
        styling = thinAndReservedPaddingStyle
      })
      editMode.get() ? addNoteButtonDisabled : addNoteButton
    ]
  }

  function mkRememberButton(note) {
    let rememberOnboarding = notesList.get().findvalue(@(other_note) other_note.id == note)?.rememberOnboardingButton ?? false
    if (!rememberOnboarding)
      return null

    if (isOnboarding.get()) {
      if (!isOnboardingMemory.get())
        return null

      return memoryButtonFromTextAndCb(
        loc("notes/interrupt_memories"),
        @() ecs.g_entity_mgr.broadcastEvent(CmdInterruptOnboardingMemory())
      )
    }

    if (!isOnPlayerBase.get()) {
      return memoryButtonFromTextAndCb(
        loc("notes/remember"),
        @() msgbox.showMessageWithContent({
          content = {
            rendObj = ROBJ_TEXT
            text = loc("notes/memories_only_on_base")
          }
        })
      )
    }

    if (isInQueue.get()) {
      return memoryButtonFromTextAndCb(
        loc("notes/remember"),
        @() msgbox.showMsgbox({
          text = loc("notes/leave_queue")
          buttons = [
            {
              text = loc("Yes")
              action = function() {
                leaveQueue()
                if (isInSquad.get() && !isSquadLeader.get())
                  myExtSquadData.ready(false)
                ecs.g_entity_mgr.broadcastEvent(CmdStartOnboardingMemory())
              }
              isCurrent = true
            },
            {
              text = loc("No")
              isCancel = true
            }
          ]
        })
      )
    }

    if (myExtSquadData.ready.get()) {
      return memoryButtonFromTextAndCb(
        loc("notes/remember"),
        @() msgbox.showMsgbox({
          text = loc("notes/squad_unready")
          buttons = [
            {
              text = loc("Yes")
              action = function() {
                myExtSquadData.ready(false)
                ecs.g_entity_mgr.broadcastEvent(CmdStartOnboardingMemory())
              }
              isCurrent = true
            },
            {
              text = loc("No")
              isCancel = true
            }
          ]
        })
      )
    }

    return memoryButtonFromTextAndCb(
      loc("notes/remember"),
      @() ecs.g_entity_mgr.broadcastEvent(CmdStartOnboardingMemory())
    )
  }

  function buttonsRow() {
    if (!curNote.get())
      return { watch = curNote }
    let children = []
    let note = notesList.get().findvalue(@(note) note.id == curNote.get())
    if (note?.userNote){
      if (editMode.get()){
        children.append(mkApplyButton())
        children.append(mkCancelButton())
      }
      else {
        children.append(mkEditButton())
        children.append(mkDeleteButton(userNotes))
      }
    }
    else {
      children.append(mkPlayStopButtons(curNote.get()))
      children.append(mkRememberButton(curNote.get()))
    }
    return {
      watch = [curNote, editMode]
      flow = FLOW_HORIZONTAL
      gap = hdpx(10)
      children
    }
  }
  let watch = [curNote, notesList, editMode, selectedNoteBlockId, userNotes]
  let _getFirstNote = @() notesList.get().filter(@(note) note?.isUnlocked)
  let getFirstNote = @() _getFirstNote()?[0].id
  let getFirstNoteType = @() _getFirstNote()?[0].type
  let getCurNoteInList = @() notesList.get().findvalue(@(note) note.id == curNote.get())
  function setCurNoteIfNeeded() {
    if (getCurNoteInList() == null) {
      curNote.set(getFirstNote())
      selectedNoteBlockId.set(getFirstNoteType())
      cachedNoteSelection.mutate(@(v) v[getFirstNoteType()] <- getFirstNote())
    }
  }

  function noteContent() {
    if (!notesList.get().len()==0)
      return { watch }
    local note = getCurNoteInList()
    if (note==null)
      note = getFirstNote()
    if (note == null)
      return { watch }
    local content = null
    if (note?.userNote && editMode.get()){
      content = mkEditNote(note)
    }
    else if (note?.userNote){
      content = formatText(userContent(note))
    }
    else if (note?.content){
      content = formatText(note?.content)
    }
    return {
      watch
      onAttach = setCurNoteIfNeeded
      rendObj = ROBJ_SOLID
      size = [flex(3), flex()]
      flow = FLOW_VERTICAL
      color = ControlBg
      padding = [0, hdpx(10)]
      children = [
        buttonsRow,
        makeVertScrollExt(content, { size = flex() })
      ]
    }
  }

  return @(){
    size = flex()
    flow = FLOW_HORIZONTAL
    onDetach = cancelEditWithSave
    gap = hdpx(10)
    children = [
      leftColumn,
      noteContent,
    ]
  }
}

let unreadCount = Computed(@() predefinedNotes.get()
  .filter(@(note) (note?.markUnread ?? false) && ((note?.isUnlocked ?? false) || debugShowAllNotes.get()))
  .len())

return {
  mkNoteTab
  unreadCount
}
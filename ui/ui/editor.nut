from "%ui/ui_library.nut" import *

local editor = null
local editorState = null
local showUIinEditor = Watched(false)
local editorIsActive = Watched(false)
local initRISelect   = @(_a,_b) null

if (require_optional("daEditorEmbedded") != null) {
  editor = require_optional("%daeditor/editor.nut")
  editorState = require_optional("%daeditor/state.nut")
  showUIinEditor = editorState?.showUIinEditor ?? showUIinEditor
  editorIsActive = editorState?.editorIsActive ?? editorIsActive
  initRISelect   = require_optional("%daeditor/riSelect.nut")?.initRISelect ?? @(_a,_b) null
}

return {
  editor, showUIinEditor, editorIsActive, initRISelect
}
import "utf8" as utf8
from "%ui/components/colors.nut" import InfoTextValueColor
from "%ui/components/commonComponents.nut" import mkTextArea, bluredPanel
from "%ui/hud/subtitles/subtitles_common.nut" import clearTextTags
from "%ui/fonts_style.nut" import sub_txt, tiny_txt, body_txt
import "%ui/components/colorize.nut" as colorize
from "%ui/ui_library.nut" import *

let { safeAreaHorPadding, safeAreaVerPadding } = require("%ui/options/safeArea.nut")
let { currentAssistantSpeak } = require("%ui/hud/subtitles/asistant_speak_state.nut")
let { subtitlesNeeded, subtitlesBackgroundNeeded, subtitlesFontSize, SubtitlesFontSizes } = require("%ui/mainMenu/menus/options/sound_options.nut")
let { assistantSpeakingScript, predefinedNotes } = require("%ui/hud/state/notes.nut")

let debugSubtitles = Watched(false)
console_register_command(@() debugSubtitles.modify(@(v) !v), "subtitles.debug_mode")
let testSubtitles = Watched("")
console_register_command(@(v) testSubtitles.set(v), "subtitles.add_text")

let subtitlesFontSizeMap = {
  [SubtitlesFontSizes.tiny]  = tiny_txt,
  [SubtitlesFontSizes.normal] = sub_txt,
  [SubtitlesFontSizes.big] = body_txt
}

let subtitlesLang = Computed(function() {
  let speakSoundName = currentAssistantSpeak.get()?.currentScriptName
  if (speakSoundName == "") {
    if ((testSubtitles.get() ?? "") == "")
      return null
    else
      return testSubtitles.get()
  }

  let soundLoc = loc(speakSoundName, "")

  if (soundLoc == "") {
    let note = predefinedNotes.get().findvalue(@(v) v.id == assistantSpeakingScript.get())

    let paragraphs = []
    const maxParagraphs = 30 
    for (local idx = 1; idx < maxParagraphs; idx++) {
      let noteLoc = loc($"notes/{note?.id}/paragraph/{idx}", "")
      if (noteLoc == "")
        break;

      paragraphs.append(noteLoc)
    }

    if (paragraphs.len() > 0)
      return " ".join(paragraphs)
  }

  return soundLoc
})


function splitLang(lang, allTime) {
  local i = 0
  let ret = []
  local unspecifiedWordsCount = 0
  while (i < lang.charCount()) {
    let startStr = "[[[SubtitlesDivider"
    let startIdx = lang.indexof(startStr, i)
    if (startIdx == null)
      break

    let startTagEnds = lang.indexof("]]]", startIdx)
    if (startTagEnds == null)
      break

    local delay = null
    let endOfStartStr = startIdx + startStr.len()
    if (lang.slice(endOfStartStr, endOfStartStr + 1) == "=")
      delay = lang.slice(endOfStartStr + 1, startTagEnds).tofloat()

    let langBlock = lang.slice(i, startIdx)
    let wordsCountInBlock = langBlock.split().len()
    if (!delay) {
      delay = -1
      unspecifiedWordsCount += wordsCountInBlock
    }

    ret.append([delay, langBlock, wordsCountInBlock])

    let nextBlockStarts = startTagEnds + "]]]".len()
    i = nextBlockStarts
  }
  let lastSlice = lang.slice(i, lang.charCount())
  let lastSliceWordsCount = lastSlice.split().len()
  unspecifiedWordsCount += lastSliceWordsCount
  ret.append([-1, lastSlice, lastSliceWordsCount])

  local allTimeMinusSet = ret.reduce(function(acc, v) {
    if (v[0] > 0)
      acc -= v[0]
    return acc
  }, allTime)

  for (local idx = 0; idx < ret.len(); idx++) {
    if (ret[idx][0] != -1)
      continue
    let time = (ret[idx][2].tofloat() / unspecifiedWordsCount.tofloat()) * allTimeMinusSet
    ret[idx][0] = time
  }
  return ret
}

let watch = [ currentAssistantSpeak, subtitlesLang, testSubtitles, safeAreaHorPadding, safeAreaVerPadding ]
function subtitlesBlock() {
  let locToShow = subtitlesLang.get()
  if (!locToShow?.len())
    return { watch }
  let utfText = utf8(
    clearTextTags(locToShow)
      .replace("\n", "")
  )
  let speachTime = currentAssistantSpeak.get()?.currentScriptSoundLenght
  let spilted = splitLang(utfText, speachTime)

  let subIndex = Watched(0)

  let timerId = "nextSubtitlesPage"
  function nextPage() {
    if (subIndex.get() >= spilted.len() - 1)
      return

    subIndex.set(subIndex.get() + 1)
    let wait = (spilted?[subIndex.get()][0] ?? 0.0)
    gui_scene.resetTimeout(wait, nextPage, timerId)
  }

  let firstWait = (spilted?[0][0] ?? 0.0)
  gui_scene.resetTimeout(firstWait, nextPage, timerId)

  function getSubtitlePage() {
    let page = spilted[subIndex.get()]
    if (debugSubtitles.get()) {
      return $"[Sound time: {speachTime}, page time: {page[0]}] {page[1]}"
    }
    return page[1]
  }
  let mSecond = colorize(InfoTextValueColor, $"{loc("options/miss_second")}: ")
  return {
    watch
    vplace = ALIGN_BOTTOM
    hplace = ALIGN_CENTER
    margin = [safeAreaVerPadding.get()+sh(10), safeAreaHorPadding.get()+sw(5)]
    children = function() {
      return {
        watch = [ subIndex, subtitlesNeeded, subtitlesBackgroundNeeded, subtitlesFontSize ]
        padding = hdpx(6)
        children = subtitlesNeeded.get() ?
          mkTextArea("{0}{1}".subst(mSecond, getSubtitlePage()), {
            maxWidth = min(hdpx(1000), sw(60)),
            size = SIZE_TO_CONTENT,
            halign = ALIGN_CENTER
          }.__update(subtitlesFontSizeMap?[subtitlesFontSize.get()] ?? sub_txt))
          : null
      }.__update(subtitlesBackgroundNeeded.get() ? bluredPanel : {})
    }
  }
}

return {
  subtitlesBlock
}
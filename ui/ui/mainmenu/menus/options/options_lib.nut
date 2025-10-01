from "%ui/fonts_style.nut" import h2_txt, body_txt
from "settings" import get_setting_by_blk_path
from "math" import fabs
from "%ui/options/mkOnlineSaveData.nut" import mkOnlineSaveData
from "%ui/components/button.nut" import textButton
from "%ui/components/selectWindow.nut" import mkSelectWindow, mkOpenSelectWindowBtn
import "%ui/components/slider.nut" as slider
import "%ui/components/spinnerList.nut" as spinnerList
import "%ui/mainMenu/menus/options/optionTextSlider.nut" as mkSliderWithText

from "%ui/ui_library.nut" import *



let getOnlineSaveData = memoize(@(saveId, defValueFunc, validateFunc = @(v) v) mkOnlineSaveData(saveId, defValueFunc, validateFunc), 1)

function optionCombo(opt, _group, xmbNode){
  let {var, valToString, setValue=null} = opt
  let ItemWrapper = class{
    item = null
    constructor(item_)   { this.item = item_ }
    function _tostring() { return valToString(this.item) }
    function isCurrent() { return opt.isEqual(this.item, opt.var.get())}
    function value()     { return this.item }
  }
  let { available } = opt
  let items = available instanceof Watched
    ? Computed(@() available.get().map(@(v) ItemWrapper(v)))
    : available.map(@(v) ItemWrapper(v))

  let openScenesMenu = mkSelectWindow({
    uid = "combobox",
    optionsState = items,
    state = var,
    setValue,
    title = loc("Choose option"),
    filterState = null
    mkTxt = @(item) item
    titleStyle = h2_txt
  })
  return @() {
    size = flex()
    watch = var
    children = mkOpenSelectWindowBtn(var, openScenesMenu, valToString, null, opt?.hint, xmbNode)
  }
}

let locOn = loc($"option/on")
let locOff = loc($"option/off")

function optionCheckBox(opt, group, xmbNode, params = {}) {
  let available = Watched([false, true])
  return @(){
    size = flex()
    watch = available
    children = spinnerList({
      isEqual = opt?.isEqual
      setValue = opt?.setValue
      curValue = opt.var
      valToString = opt?.valToString ?? @(val) val ? locOn : locOff
      allValues = available.get()
      xmbNode
      group
    }.__merge(params))
  }
}

function optionSlider(opt, group, xmbNode) {
  let sliderElem = {
    size = flex()

    children = slider.Horiz(opt.var, {
      min = opt?.min ?? 0
      max = opt?.max ?? 1
      unit = opt?.unit ?? 0.1
      scaling = opt?.scaling
      ignoreWheel = opt?.ignoreWheel ?? false
      pageScroll = opt?.pageScroll ?? 0.1
      group
      xmbNode
      setValue = opt?.setValue
    })
  }

  return sliderElem
}

function optionSpinner(opt, group, xmbNode) {
  let available = opt?.available instanceof Watched
    ? opt.available
    : Watched(opt?.available)
  let spinnerElem = @(){
    size = flex()
    watch = available
    children = spinnerList({
      isEqual = opt?.isEqual
      setValue = opt?.setValue
      curValue = opt.var
      valToString = opt?.valToString ?? @(val) val ? locOn : locOff
      allValues = available.get()
      xmbNode
      group
      hint = opt?.hint
    })
  }
  return spinnerElem
}


let optionButton = @(opt, _group, xmbNode){
  size = FLEX_H
  children = @() {
    watch = opt.var
    stopHover = true
    children = textButton(opt.var.get()?.text, @() opt.var.get()?.handler(), {
      xmbNode
      stopHover = true
      tooltipText = opt?.hint
    })
  }
}
function defCmp(a, b) {
  if (typeof a != "float")
    return a == b
  let absSum = fabs(a) + fabs(b)
  return absSum < 0.00001 ? true : fabs(a - b) < 0.0001 * absSum
}

let loc_opt = @(s) loc($"option/{s}")

function optionPercentTextSliderCtor(opt, group, xmbNode) {
  return mkSliderWithText(opt, group, xmbNode, opt?.valToString ?? @(v) "{0}%".subst(v * (opt?.mult ?? 1)))
}

let optionDisabledText = @(text) {
  size = FLEX_H
  clipChildren = true
  rendObj = ROBJ_TEXT 
  text
  color = Color(90,90,90)
}.__update(body_txt)

let mkDisableableCtor = @(disableWatch, enabledCtor, disabledCtor = optionDisabledText)
  function(opt, group, xmbNode) {
    let enabledWidget = enabledCtor(opt, group, xmbNode)
    return @() {
      watch = disableWatch
      size = flex()
      valign = ALIGN_CENTER
      children = disableWatch.get() == null ? enabledWidget
        : disabledCtor(disableWatch.get())
    }
  }

function optionCtor(opt){
  #forbid-auto-freeze
  if (opt?.originalVal == null)
    opt.originalVal <- (type(opt?.blkPath)==type("")
      ? get_setting_by_blk_path(opt.blkPath)
      : opt?.var
        ? opt.var.get()
        : null
    ) ?? opt?.defVal
  if ("convertFromBlk" in opt)
    opt.originalVal = opt.convertFromBlk(opt.originalVal)

  if ("var" not in opt)
    opt.var <- Watched(opt.originalVal)
  if ("isEqual" not in opt)
    opt.isEqual <- defCmp
  if ("typ" not in opt && "defVal" in opt)
    opt.typ <- type(opt.defVal)
  return freeze(opt)
}

function isOption(opt){
  if ("isSeparator" in opt)
    return true
  if ("name" not in opt || "var" not in opt || "widgetCtor" not in opt)
    return false
  return true
}

return {
  defCmp
  optionCtor
  isOption
  loc_opt
  getOnlineSaveData
  mkSliderWithText
  optionPercentTextSliderCtor
  optionSlider
  optionCombo
  optionCheckBox
  optionButton
  optionDisabledText
  mkDisableableCtor
  optionSpinner
}

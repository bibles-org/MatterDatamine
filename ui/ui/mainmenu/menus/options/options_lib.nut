from "%ui/ui_library.nut" import *

let {h2_txt, body_txt} = require("%ui/fonts_style.nut")
let { get_setting_by_blk_path } = require("settings")
let { fabs } = require("math")
let { mkOnlineSaveData } = require("%ui/options/mkOnlineSaveData.nut")
let { textButton } = require("%ui/components/button.nut")
let {mkSelectWindow, mkOpenSelectWindowBtn} = require("%ui/components/selectWindow.nut")
let slider = require("%ui/components/slider.nut")
let spinnerList = require("%ui/components/spinnerList.nut")

let mkSliderWithText = require("optionTextSlider.nut")

let getOnlineSaveData = memoize(@(saveId, defValueFunc, validateFunc = @(v) v) mkOnlineSaveData(saveId, defValueFunc, validateFunc), 1)

function optionCombo(opt, _group, _xmbNode){
  let {var, valToString, setValue=null} = opt
  let ItemWrapper = class{
    item = null
    constructor(item_)   { this.item = item_ }
    function _tostring() { return valToString(this.item) }
    function isCurrent() { return opt.isEqual(this.item, opt.var.value)}
    function value()     { return this.item }
  }
  let { available } = opt
  let items = available instanceof Watched
    ? Computed(@() available.value.map(@(v) ItemWrapper(v)))
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
    children = mkOpenSelectWindowBtn(var, openScenesMenu, valToString, null, opt?.hint)
  }
}

let locOn = loc($"option/on")
let locOff = loc($"option/off")

function optionCheckBox(opt, group, xmbNode) {
  let available = Watched([false, true])
  return @(){
    size = flex()
    watch = available
    children = spinnerList({
      isEqual = opt?.isEqual
      setValue = opt?.setValue
      curValue = opt.var
      valToString = opt?.valToString ?? @(val) val ? locOn : locOff
      allValues = available.value
      xmbNode
      group
    })
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
      allValues = available.value
      xmbNode
      group
      hint = opt?.hint
    })
  }
  return spinnerElem
}


let optionButton = @(opt, _group, xmbNode){
  size = [flex(), SIZE_TO_CONTENT]
  children = @() {
    watch = opt.var
    stopHover = true
    children = textButton(opt.var.value?.text, @() opt.var.value?.handler(), {
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
  size = const [flex(), SIZE_TO_CONTENT]
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
      children = disableWatch.value == null ? enabledWidget
        : disabledCtor(disableWatch.value)
    }
  }

function optionCtor(opt){
  if (opt?.originalVal == null)
    opt.originalVal <- (type(opt?.blkPath)==type("")
      ? get_setting_by_blk_path(opt.blkPath)
      : opt?.var
        ? opt.var.value
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

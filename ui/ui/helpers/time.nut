import "%sqstd/time.nut" as timeBase
from "string" import format
from "%ui/ui_library.nut" import *

let locTable = static {
  seconds =loc("measureUnits/seconds"),
  days =loc("measureUnits/days"),
  minutes =loc("measureUnits/minutes")
  hours =loc("measureUnits/hours")
}

let locFullTable = static {
  seconds =loc("measureUnits/seconds"),
  days =loc("measureUnits/full/days"),
  minutes =loc("measureUnits/full/minutes")
  hours =loc("measureUnits/full/hours")
}

let secondsToStringLoc = @(time) timeBase.secondsToTimeFormatString(time).subst(locTable)

let secondsToHoursLoc = @(time) timeBase.secondsToTimeFormatString(timeBase.roundTime(time)).subst(locTable)

function secondsToTimeFormatStringWithSec(time) {
  let {days=0, hours=0, minutes=0, seconds=0} = timeBase.secondsToTime(time)
  let res = []
  if (days>0)
    res.append("{0}{days}".subst(days))
  if (hours>0)
    res.append("{0}{hours}".subst(hours))
  if (minutes>0 || days > 0 )
    res.append("{0}{minutes}".subst(minutes))
  res.append("{0}{seconds}".subst(minutes+hours > 0 ? format("%02d", seconds) : seconds.tostring()))
  return " ".join(res)
}

let secondsToHoursLocFull = @(time) timeBase.secondsToTimeFormatString(timeBase.roundTime(time)).subst(locFullTable)
let secondsToString = timeBase.secondsToTimeSimpleString

return freeze(timeBase.__merge({
  secondsToString
  secondsToTimeFormatStringWithSec
  secondsToStringLoc
  secondsToHoursLoc
  secondsToHoursLocFull
  locTable
  locFullTable
}))
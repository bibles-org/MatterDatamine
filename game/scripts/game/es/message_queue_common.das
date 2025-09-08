module message_queue_common shared
require ecs
require app
require net
require strings
require DagorFiles
require jsonwriter
require DagorSystem
require DagorRandom
require MessageQueue
require DagorDataBlock


let shared
  argTubePrefix = "-profile_tube:"


struct ActionIdData
  id : string
  transactId : uint64


def logMQ(text)
  print("[messageQueue] {text}")


def getTubeName(argTubePrefix)
  var res = ""
  for arg in get_command_line_arguments()
    if starts_with(arg, argTubePrefix)
      res = slice(arg, length(argTubePrefix))
      break

  if res == ""
    let msgBlock = dgs_get_settings() |> datablock_get_block_by_name("message_queue")
    res = msgBlock |> datablock_getStr("tube", "")

  return res


def genTransactionId()
  return ((uint64(get_session_id()) & 0xFFFFFFFF00000000l) //first 32 bits of sessionId is session creation timestamp
    + uint64(grnd())) //range = 0x0 - 0x7FFF. Also it can be incremented by transaction operations.
      //so 0xFFFF0000 is reserved for actionIdx


def incTransactionActionIdx(var transactionId : uint64&)
  transactionId += 0x10000l
  let idx = (transactionId & 0xFFFF0000l) >> 0x10l
  return int(idx)


def mkActionIdData()
  var idx = -1
  var transactId : uint64
  find_query() <| $ [es] (var transaction_id : uint64&)
    idx = incTransactionActionIdx(transaction_id)
    transactId = transaction_id
    return true
  if idx < 0
    logMQ("Not found transaction_id!!!")
    idx = 0
    transactId = genTransactionId()

  return ActionIdData(id = string(idx), transactId = transactId)


def logPSC(text)
  print("[profileServerClient] {text}")


def sendToProfileServer(action : string; userId : uint64; data)
  let profileTubeName = getTubeName(argTubePrefix)
  if (profileTubeName == "")
    logPSC("Send action without profile_tube does not supported")
    return

  let idData <- mkActionIdData()
  let actionEx = "das.{action}"
  logPSC("Sending request id: {idData.id}, trId: {format("0x%llx", idData.transactId)} method: {actionEx} via message_queue (tube = {profileTubeName})")

  message_queue_put_raw(profileTubeName) <| $(var jw : JsonWriter)
    jw_start_obj(jw)
    jw_key_value(jw, "action", actionEx)

    jw_key(jw, "headers")
    jw_start_obj(jw)
    jw_key_value(jw, "appid", get_app_id())
    jw_key_value(jw, "userId", userId)
    jw_key_value(jw, "transactid", idData.transactId)
    jw_end_obj(jw)

    jw_key(jw, "body")
    jw_start_obj(jw)
    jw_key_value(jw, "method", actionEx)
    jw_key_value(jw, "id", idData.id)
    jw_key_value(jw, "jsonrpc", "2.0")
    static_if !typeinfo is_struct(data)
      concept_assert(false, "sendToPserver support only structs as value")
    else
      jw_key_value(jw, "params", data)
    jw_end_obj(jw)

    jw_end_obj(jw)


def sendJsonToFile(file_name : string; data)
  jw_writer() <| $(var jw : JsonWriter)
    jw_value(jw, data)
    df_open(file_name, DF_WRITE | DF_CREATE) <| $(outputFile)
      outputFile |> df_puts(jw.result)

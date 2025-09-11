let { get_setting_by_blk_path } = require("settings")
let { file_exists } = require("dagor.fs")
let { WatchedRo, Computed } = require("%sqstd/frp.nut")
let { get_circuit_conf, get_circuit, get_exe_version, get_build_number } = require("app")
let { DBGLEVEL } = require("dagor.system")

let circuit = WatchedRo(get_circuit())
let exe_version = WatchedRo(get_exe_version())
let build_number = WatchedRo(get_build_number())



let project_yup_name = get_setting_by_blk_path("yupfile") ?? "active_matter.yup"
let yup_version = WatchedRo(file_exists(project_yup_name)
  ? require("yupfile_parse").getStr(project_yup_name, "yup/version")
  : null)

let circuitEnv = WatchedRo(get_circuit_conf()?.environment ?? "")
let version = WatchedRo(yup_version.get() ?? exe_version.get())

let isProductionCircuit = Computed(@() !(circuitEnv.get()!="production"))
let isInternalCircuit = Computed(@() circuitEnv.get()=="test")
let isDebugBuild = DBGLEVEL > 0

return {
  version
  isProductionCircuit
  isInternalCircuit
  isDebugBuild
  project_yup_name = WatchedRo(project_yup_name)
  yup_version
  exe_version
  build_number
  circuit
  circuit_environment = circuitEnv
}

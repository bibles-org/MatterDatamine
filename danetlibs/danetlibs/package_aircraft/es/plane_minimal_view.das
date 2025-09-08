require ecs
require ecs.common
require ecs.safe
require math.base
require Plane
require DngPlane
require DagorMath
require GamePhys

[es(tag=gameClient, after=plane_phys_es, on_event=ParallelUpdateFrameDelayed)]
def plane_minimal_view(evt : Event;
                       net_phys__interpK : float;
                       is_autopilot_in_hover_mode : bool;
                       var plane_net_phys : PlaneActor&;
                       var plane_view__altitude : float&;
                       var plane_view__altitudeInt : int&;
                       var plane_view__radar_alt : float&;
                       var plane_view__vertical_speed : float&;
                       var plane_view__ias : float&;
                       var plane_view__tas : float&;
                       var plane_view__tasKMHInt : int&;
                       var plane_view__heading_deg : int&;

                       var plane_view__throttle : float&;
                       var plane_view__throttlePercent : int&;
                       var plane_view__is_throttle_control_active : bool&;
                       var plane_view__climb : float&;
                       var plane_view__is_climb_control_active : bool&;
                       var plane_view__has_gear_control : bool&;
                       var plane_view__gear_position : bool&;
                       var plane_view__is_gear_locked : bool&;
                       var plane_view__is_gear_down : bool&;
                       var plane_view__has_flaps_control : bool&;

                       var plane_view__fuel_leak : bool&;
                       var plane_view__fuel_tanks_sealing : bool&;
                       var plane_view__fuel_mass_ratio : float&;
                       var plane_view__fuel_pct : float&;
                       var plane_view__fuel_mass : float&;
                       var plane_view__fuel_max_mass : float&;
                       var plane_view__fuel_time : float&;

                       var plane_view__engine_manual_control : bool&;
                       var plane_view__is_engine_started : bool&;
                       var plane_view__engine_speed : float&;
                       var plane_view__engine_has_pitch_control : bool&;
                       var plane_view__engine_pitch_control_auto : bool&;
                       var plane_view__engine_pitch_control : float&;
                       var plane_view__engine_has_radiator_control : bool&;
                       var plane_view__engine_radiator_control_auto : bool&;
                       var plane_view__engine_radiator : float&;
                       var plane_view__engine_oil_radiator_control_auto : bool&;
                       var plane_view__engine_has_oil_radiator_control : bool&;
                       var plane_view__engine_oil_radiator : float&;
                       var plane_view__engine_water_cooled : bool&;
                       var plane_view__engine_air_cooled : bool&;
                       var plane_view__engine_water_temperature : float&;
                       var plane_view__engine_head_temperature : float&;
                       var plane_view__engine_oil_temperature : float&;

                       var plane_view__operable : bool&;

                       var plane_view__op_engine : bool&;
                       var plane_view__op_gear : bool&;
                       var plane_view__op_aileron : bool&;
                       var plane_view__op_elevator : bool&;
                       var plane_view__op_rudder : bool&;
                       var plane_view__op_flaps : bool&;
                       var plane_view__op_can_taxi : bool&;
                       var plane_view__op_can_takeoff : bool&;
                       var plane_view__op_can_fly : bool&)
  assume phys = plane_net_phys.phys
  assume propulsion = *(phys.EI)
  let mainEngineIndex = 0

  plane_view__radar_alt = phys.currentAlt
  plane_view__altitude = lerp(float(phys.previousState.location.P.y), float(phys.currentState.location.P.y), net_phys__interpK)
  plane_view__altitudeInt = int(plane_view__altitude)

  plane_view__vertical_speed = lerp(float(phys.previousState.velocity.y), float(phys.currentState.velocity.y), net_phys__interpK)
  plane_view__ias = phys.indSpeed

  plane_view__tas = length(lerp(phys.previousState.velocity, phys.currentState.velocity, net_phys__interpK))
  plane_view__tasKMHInt = int(plane_view__tas * 3.6)

  plane_view__heading_deg = int(360.f + 91.f + phys.currentState.location.O.azimuth) % 360

  plane_view__is_throttle_control_active = !is_autopilot_in_hover_mode
  plane_view__climb = phys.climbControl
  plane_view__is_climb_control_active = is_autopilot_in_hover_mode
  plane_view__has_gear_control = phys.bHasGearControl
  plane_view__gear_position = phys.GearControl > 0.5f
  plane_view__is_gear_locked = !phys.bHasGearControl || (abs(phys.appliedCT.gear - 0.5f) > 0.49f)
  plane_view__is_gear_down = !phys.bHasGearControl || phys.appliedCT.gear > 0.99f
  plane_view__has_flaps_control = phys.bHasFlapsControl

  plane_view__fuel_leak = phys.leakingFuelTanksNum > 0
  plane_view__fuel_tanks_sealing = phys.sealingFuelTanksNum > 0
  plane_view__fuel_mass = getFuelMassCurrent(phys.M)
  plane_view__fuel_max_mass = getFuelMassMax(phys.M)
  plane_view__fuel_mass_ratio = safediv(plane_view__fuel_mass, plane_view__fuel_max_mass)
  plane_view__fuel_pct = plane_view__fuel_mass_ratio * 100.f


  var fuelConsumptionMaxTotal = 0.f
  for engineIndex in range(0, propulsion.numEngines)
    propulsion_getEngine(propulsion, engineIndex) <| $(engine)
      if engine.isBooster
        fuelConsumptionMaxTotal += engine.fuelConsumptionMax

  var fuelTime = 0.f
  if fuelConsumptionMaxTotal > VERY_SMALL_NUMBER
    fuelTime = plane_view__fuel_mass / fuelConsumptionMaxTotal * 3600.0f
  plane_view__fuel_time = fuelTime

  let forceAutoEngine = !get_difficulty().ComplexEManagement || !phys.playerPhysics
  plane_view__engine_manual_control = !forceAutoEngine

  propulsion_getEngine(propulsion, mainEngineIndex) <| $(mainEngine)
    plane_view__throttle = mainEngine.controlThrottle
    plane_view__throttlePercent = int(plane_view__throttle * 100.f)

    let engineStage = mainEngine.stage
    plane_view__is_engine_started = (engineStage == EStage.E_STAGE_WAKE_UP ||
                                      engineStage == EStage.E_STAGE_STARTER_ROLL ||
                                      engineStage == EStage.E_STAGE_CATCH_UP ||
                                      engineStage == EStage.E_STAGE_CATCH_ROLL ||
                                      engineStage == EStage.E_STAGE_CATCH_FIRE ||
                                      engineStage == EStage.E_STAGE_ACCELERATING ||
                                      engineStage == EStage.E_STAGE_NOMINAL)

    plane_view__engine_speed = mainEngine.omega
    plane_view__engine_has_radiator_control = mainEngine.props.bHasRadiatorControl || mainEngine.props.bAutoRad
    plane_view__engine_radiator_control_auto = forceAutoEngine || (mainEngine.isRadiatorInAuto
      && (engine_allowsAutoRadiator(mainEngine, phys.playerPhysics) || phys.hasFlightProgram))
    plane_view__engine_radiator = flight_model_getRadiatorControl(phys, mainEngineIndex)
    plane_view__engine_has_oil_radiator_control = mainEngine.props.bHasCommonRadiator && (mainEngine.props.bHasOilRadiatorControl || mainEngine.props.bAutoOilRad)
    plane_view__engine_oil_radiator_control_auto = forceAutoEngine || (mainEngine.isOilRadiatorInAuto
      && (engine_allowsAutoOilRadiator(mainEngine, phys.playerPhysics) || phys.hasFlightProgram))
    plane_view__engine_oil_radiator = flight_model_getOilRadiatorControl(phys, mainEngineIndex)
    plane_view__engine_water_cooled = mainEngine.isWaterCooled
    plane_view__engine_air_cooled = !mainEngine.isWaterCooled
    plane_view__engine_water_temperature = mainEngine.waterTemp + ZERO_KELVIN_IN_CELSIUM
    plane_view__engine_head_temperature = mainEngine.headTemp + ZERO_KELVIN_IN_CELSIUM
    plane_view__engine_oil_temperature = mainEngine.oilTemp + ZERO_KELVIN_IN_CELSIUM


  var propellerIndex = 0
  if propulsion_findPropellerByEngine(propulsion, mainEngineIndex, propellerIndex)
    propulsion_getPropeller(propulsion, propellerIndex) <| $(propeller)
      let forceAutoPropPitch = forceAutoEngine
      plane_view__engine_pitch_control_auto = forceAutoPropPitch || (flight_model_getStepControlAuto(phys, mainEngineIndex)
        && (propulsion_hasPitchAutoControl(propulsion, mainEngineIndex) || phys.hasFlightProgram))
      plane_view__engine_has_pitch_control = propeller.props.hasPitchManualControl || propeller.props.hasPitchAutoControl
      plane_view__engine_pitch_control = flight_model_getStepControl(phys, mainEngineIndex)
  else
    plane_view__engine_has_pitch_control = false
    plane_view__engine_pitch_control_auto = false
    plane_view__engine_pitch_control = 0.f


  plane_view__op_engine = flight_model_getOp(phys, int(FmPartId.ACPART_ENGINE_FIRST))
  plane_view__op_gear = (flight_model_getOp(phys, int(FmPartId.ACPART_GEAR_L))
    && flight_model_getOp(phys, int(FmPartId.ACPART_GEAR_C))
    && flight_model_getOp(phys, int(FmPartId.ACPART_GEAR_R)))
  plane_view__op_aileron = (flight_model_getOp(phys, int(FmPartId.ACPART_AILERON_CONTROL_L))
    && flight_model_getOp(phys, int(FmPartId.ACPART_AILERON_CONTROL_R)))
  plane_view__op_elevator = (flight_model_getOp(phys, int(FmPartId.ACPART_ELEVATOR_CONTROL_L))
    && flight_model_getOp(phys, int(FmPartId.ACPART_ELEVATOR_CONTROL_R)))
  plane_view__op_rudder = flight_model_getOp(phys, int(FmPartId.ACPART_RUDDER_CONTROL))
  plane_view__op_flaps = (flight_model_getOp(phys, int(FmPartId.ACPART_FLAP_L))
    && flight_model_getOp(phys, int(FmPartId.ACPART_FLAP_R)))


  plane_view__op_can_takeoff = phys.isCapableOfTakeOff
  plane_view__op_can_fly = phys.isCapableOfNormalFly
  plane_view__op_can_taxi = phys.isCapableOfTaxi


  let pitch = phys.currentState.location.O.pitch
  let absRoll = abs(phys.currentState.location.O.roll)
  let broken = (phys.isAnyInoperable || phys.currentAlt < -3.f
    || (plane_view__tas < 2.0f && phys.currentAlt < 10.f
    && (pitch > 20.0f || pitch < -30.0 || absRoll > 20.0f)))

  plane_view__operable = !broken && plane_view__op_gear

[es(tag=gameClient, track=attached_lights_enabled)]
def plane_minimal_view_lights(evt : Event;
                              attached_lights_enabled : BoolList;
                              var plane_view__lights_strobe : bool&;
                              var plane_view__lights_navigation : bool&;
                              var plane_view__lights_taxi : bool&;
                              var plane_view__lights_landing : bool&;
                              var plane_view__lights_cockpit : bool&)
{
  plane_view__lights_strobe = attached_lights_enabled[int(AircraftLight.LIGHT_STROBE)];
  plane_view__lights_navigation = attached_lights_enabled[int(AircraftLight.LIGHT_NAVIGATION)];
  plane_view__lights_taxi = attached_lights_enabled[int(AircraftLight.LIGHT_TAXI)];
  plane_view__lights_landing = attached_lights_enabled[int(AircraftLight.LIGHT_LANDING)];
  plane_view__lights_cockpit = attached_lights_enabled[int(AircraftLight.LIGHT_COCKPIT)];
}

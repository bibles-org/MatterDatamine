require ecs
require PhysVars
require vehicle
require DagorMath
require GamePhys
require game.events.events_active_matter


// Buggy propeller
[es(tag=gameClient, on_appear)]
def init_vehicle_anim_vars(evt : Event;
                           var phys_vars : PhysVars;
                           var vehicle_anim__enginePropAnimVarId : int&)
  vehicle_anim__enginePropAnimVarId = phys_vars |> registerVar("propW1:CR", 0.)


[es(tag=gameClient, no_order)]
def vehicle_anims(act : ParallelUpdateFrameDelayed;
                  var phys_vars : PhysVars;
                  vehicle_anim__enginePropAnimVarId : int;
                  vehicle_anim__enginePropAnimMult : float;
                  vehicle_net_phys : VehiclePhysActor)
  assume state = vehicle_net_phys.phys.currentState
  setVar(phys_vars, vehicle_anim__enginePropAnimVarId, state.engineOmega * vehicle_anim__enginePropAnimMult)


// Steering wheel
[es(tag=gameClient, on_appear)]
def init_vehicle_steering_anim_vars(evt : Event;
                                    var phys_vars : PhysVars;
                                    var vehicle_anim__steeringAnimVarId : int&)
  vehicle_anim__steeringAnimVarId = phys_vars |> registerVar("steering_deflection", 0.)


[es(tag=gameClient, no_order)]
def vehicle_steering_anims(act : ParallelUpdateFrameDelayed;
                           var phys_vars : PhysVars;
                           vehicle_anim__steeringAnimVarId : int;
                           vehicle_anim__steeringMult : float;
                           vehicle_net_phys : VehiclePhysActor)
  assume state = vehicle_net_phys.phys.currentState
  setVar(phys_vars, vehicle_anim__steeringAnimVarId, state.steering * vehicle_anim__steeringMult)


// Speedometer
[es(tag=gameClient, on_appear, before=anim_phys_init_es)]
def vehicle_speedometer_anim_init_es(evt : Event;
                                     vehicle_anim__speedometerVarName : string;
                                     vehicle_anim__speedometerMinMax : float2;
                                     var vehicle_anim__speedometerVarId : int&;
                                     var phys_vars : PhysVars&)
  vehicle_anim__speedometerVarId = registerVar(phys_vars, vehicle_anim__speedometerVarName, vehicle_anim__speedometerMinMax.x)


[es(tag=gameClient, after=vehicle_input_driver_es, REQUIRE=vehicleWithWatched)]
def vehicle_speedometer_anim_es(info : ParallelUpdateFrameDelayed;
                                animchar__updatable : bool;
                                vehicle_net_phys : VehiclePhysActor;
                                vehicle_anim__speedometerVarId : int;
                                vehicle_anim__speedometerMinMax : float2;
                                vehicle_anim__speedometerUnitsMult : float = 3.6; // m/s to km/h
                                var phys_vars : PhysVars&)
  if !animchar__updatable
    return

  assume phys = vehicle_net_phys.phys
  let interpk = get_phys_interpk_clamped(phys, info.curTime)
  let speedPrev = dot(float3(phys.previousState.velocity), quat_get_forward(phys.previousState.location.O.quat))
  let speedCur = dot(float3(phys.currentState.velocity), quat_get_forward(phys.currentState.location.O.quat))
  let speed = lerp(speedPrev, speedCur, interpk) * vehicle_anim__speedometerUnitsMult
  let minMax = vehicle_anim__speedometerMinMax
  setVar(phys_vars, vehicle_anim__speedometerVarId, cvt(abs(speed), minMax.x, minMax.y, 0.0, 1.0))


// RPM
[es(tag=gameClient, on_appear, before=anim_phys_init_es)]
def vehicle_rpm_meter_anim_init_es(evt : Event;
                                   vehicle_anim__rpmMeterVarName : string;
                                   vehicle_anim__rpmMeterMinMax : float2;
                                   var vehicle_anim__rpmMeterVarId : int&;
                                   var phys_vars : PhysVars&)
  vehicle_anim__rpmMeterVarId = registerVar(phys_vars, vehicle_anim__rpmMeterVarName, vehicle_anim__rpmMeterMinMax.x)


[es(tag=gameClient, after=vehicle_input_driver_es, REQUIRE=vehicleWithWatched)]
def vehicle_rpm_meter_anim_es(info : ParallelUpdateFrameDelayed;
                              animchar__updatable : bool;
                              vehicle_net_phys : VehiclePhysActor;
                              vehicle_anim__rpmMeterVarId : int;
                              vehicle_anim__rpmMeterMinMax : float2;
                              vehicle_anim__rpmMeterUnitsMult : float = 0.01;
                              var phys_vars : PhysVars&)
  if !animchar__updatable
    return

  let rpm = vehicle_net_phys.phys.engineRPM * vehicle_anim__rpmMeterUnitsMult
  let minMax = vehicle_anim__rpmMeterMinMax
  setVar(phys_vars, vehicle_anim__rpmMeterVarId, cvt(rpm, minMax.x, minMax.y, 0.0, 1.0))


// Fuel
[es(tag=gameClient, on_appear, before=anim_phys_init_es)]
def vehicle_fuel_meter_anim_init_es(evt : Event;
                                    vehicle_anim__fuelMeterVarName : string;
                                    var vehicle_anim__fuelMeterVarId : int&;
                                    var phys_vars : PhysVars&)
  vehicle_anim__fuelMeterVarId = registerVar(phys_vars, vehicle_anim__fuelMeterVarName, 0.0)


[es(tag=gameClient, after=vehicle_input_driver_es, REQUIRE=vehicleWithWatched)]
def vehicle_fuel_meter_anim_es(info : ParallelUpdateFrameDelayed;
                               animchar__updatable : bool;
                               vehicle_anim__fuelMeterVarId : int;
                               vehicle__fuel : float;
                               vehicle__maxFuel : float;
                               var phys_vars : PhysVars&)
  if !animchar__updatable
    return

  setVar(phys_vars, vehicle_anim__fuelMeterVarId, safediv(vehicle__fuel, vehicle__maxFuel))
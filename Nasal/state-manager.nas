# c172p state manager
# by Wayne Bragg 2018

var state_manager = func {

    if (!getprop("/sim/presets/airspeed-kt")) {
        setprop("/velocities/airspeed-kt", 100);
        setprop("/orientation/roll-deg", 0);
        setprop("/orientation/pitch-deg", -6);
        setprop("/velocities/uBody-fps", 163);
        setprop("/velocities/vBody-fps", 0);
        setprop("/velocities/wBody-fps", 0);
    }

    # Reset battery charge and circuit breakers
    electrical.reset_battery_and_circuit_breakers();

    # set fuel configuration
    set_fuel();

    var engine_regime = getprop("/controls/engines/active-engine");
    if (engine_regime > 0) {
        var auto_mixture = getprop("/fdm/jsbsim/engine/auto-mixture");
        setprop("/controls/engines/current-engine/mixture", auto_mixture);
    } else {
        setprop("/controls/engines/current-engine/mixture", 0.88);
    }

    # removing any ice from the carburetor
    setprop("/engines/active-engine/carb_ice", 0.0);
    setprop("/engines/active-engine/carb_icing_rate", 0.0);
    setprop("/controls/engines/current-engine/carb-heat", 1);

    setprop("/engines/active-engine/running", 1);
    setprop("/engines/active-engine/auto-start", 1);
    setprop("/engines/active-engine/cranking", 1);

    setprop("/controls/engines/engine[0]/primer", 3);
    setprop("/controls/engines/engine[0]/primer-lever", 0);
    setprop("/controls/engines/current-engine/throttle", 0.2);
    setprop("/controls/flight/elevator-trim", -0.03);

    setprop("/controls/switches/magnetos", 3);
    setprop("/controls/switches/master-bat", 1);
    setprop("/controls/switches/master-alt", 1);
    setprop("/controls/switches/master-avionics", 1); 
    setprop("/controls/switches/starter", 1);

    setprop("/fdm/jsbsim/running", 0);
    setprop("/sim/model/j3cub/securing/chock", 0);
    setprop("/sim/model/j3cub/securing/pitot-cover-visible", 0);
    setprop("/sim/model/j3cub/securing/tiedownL-visible", 0);
    setprop("/sim/model/j3cub/securing/tiedownR-visible", 0);
    setprop("/sim/model/j3cub/securing/tiedownT-visible", 0);

    if (getprop("/fdm/jsbsim/bushkit") == 3) {
        setprop("/controls/gear/gear-down-command", 1);
    }

    setprop("/sim/model/j3cub/brake-parking", 0);

    var distance_nm = getprop("/sim/presets/offset-distance-nm") or 0;

    var engine_running_check_delay = 5.0;
    settimer(func {
        if (!getprop("/engines/active-engine/running")) {
            gui.popupTip("The autostart failed to start the engine. You may have to adjust the mixture and start the engine manually.", 5);
        }
        setprop("/controls/switches/starter", 0);
        setprop("/engines/active-engine/auto-start", 0);

        var target = 0.0;
        var throttle = 0.2;

        if (distance_nm > 5) {
            target = 0.85;
            setprop("/controls/flight/flaps", .33);
        } else if (distance_nm > 1) {
            target = 0.80;
            setprop("/controls/flight/flaps", .66);
        } else {
            target = 0.75;
            setprop("/controls/flight/flaps", 1);
        }

        var throttle_timer = maketimer(0.001, func{
            setprop("/controls/engines/current-engine/throttle",  throttle);
            if (throttle < target) {
                throttle = throttle + 0.01;
                
            } else throttle_timer.stop();          
        });

        throttle_timer.start();

        # Set the altimeter
        var pressure_sea_level = getprop("/environment/pressure-sea-level-inhg");
        setprop("/instrumentation/altimeter/setting-inhg", pressure_sea_level);

        # Set heading offset
        var magnetic_variation = getprop("/environment/magnetic-variation-deg");
        setprop("/instrumentation/heading-indicator/offset-deg", -magnetic_variation);

        # Setting instrument lights if needed
        if (getprop("/sim/model/j3cub/pa-18")) {

            # Setting lights
            setprop("/controls/lighting/nav-lights", 1);
            setprop("/controls/switches/panel-lights", 0);
            setprop("/controls/lighting/taxi-light", 0);
            setprop("/controls/lighting/strobe-lights", 0);
            setprop("/controls/lighting/beacon-light", 0);
            setprop("/controls/lighting/landing-light", 0);

            # Setting instrument lights if needed
            var light_level = 1-getprop("/rendering/scene/diffuse/red");
            if (light_level > .6) {
                setprop("/controls/switches/panel-lights", 1);
                setprop("/controls/lighting/taxi-light", 1);
                setprop("/controls/lighting/strobe-lights", 1);
                setprop("/controls/lighting/beacon-light", 1);
                setprop("/controls/lighting/landing-light", 1);
            }
        }

    }, engine_running_check_delay);

};

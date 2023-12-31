var reset_all_damage = func
{
    setprop("/engines/active-engine/crash-engine", 0);

    # Landing gear
    setprop("/fdm/jsbsim/gear/unit[0]/broken", 0);
    setprop("/fdm/jsbsim/gear/unit[1]/broken", 0);
    setprop("/fdm/jsbsim/gear/unit[2]/broken", 0);
    setprop("/fdm/jsbsim/gear/unit[29]/broken", 0);

    setprop("/fdm/jsbsim/gear/unit[19]/broken", 0);
    setprop("/fdm/jsbsim/gear/unit[20]/broken", 0);
    setprop("/fdm/jsbsim/gear/unit[21]/broken", 0);
    setprop("/fdm/jsbsim/gear/unit[22]/broken", 0);

    if (getprop("/fdm/jsbsim/bushkit")==3) {
        if (getprop("/fdm/jsbsim/hydro/active-norm")) {
            setprop("controls/gear/gear-down-command", 0);
            setprop("/fdm/jsbsim/gear/gear-pos-norm", 0);
        } else {
            setprop("controls/gear/gear-down-command", 1);
            setprop("/fdm/jsbsim/gear/gear-pos-norm", 1);
        }
    }

    # Wings
    setprop("/fdm/jsbsim/wing-damage/left-wing", 0);
    setprop("/fdm/jsbsim/wing-damage/right-wing", 0);

    # Collapsed wings
    setprop("/fdm/jsbsim/crash", 0);

    # Pontoons
    setprop("/fdm/jsbsim/pontoon-damage/left-pontoon", 0);
    setprop("/fdm/jsbsim/pontoon-damage/right-pontoon", 0);

    # Ski-lite
    setprop("/fdm/jsbsim/ski-damage/left-ski", 0);
    setprop("/fdm/jsbsim/ski-damage/right-ski", 0);

    if (getprop("/fdm/jsbsim/orientation/upside-down")) {
        setprop("/orientation/pitch-deg", 0);
        setprop("/orientation/roll-deg", 0);
    }

    setprop("/fdm/jsbsim/prop-damage", 0);

    setprop("/engines/active-engine/crash-engine", 0);
    setprop("/controls/switches/magnetos", 3);
}

var repair_damage = func {
    set_bushkit(getprop("/fdm/jsbsim/bushkit"));
};

var killengine = func
{
    setprop("/engines/active-engine/crash-engine", 1);
    setprop("/controls/switches/magnetos", 0);
}

# Hydro system loop

var anchor_pos = geo.Coord.new();
var aircraft_pos = geo.Coord.new();
var anchor_dist = 0.0;
var heading_diff = 0.0;
var wind_from_heading  = 0.0;
var aircraft_heading  = 0.0;
var wind_speed = 0.0;
var forward_speed = 0.0;

var poll_hydro = func
{
    var engine_rpm = getprop("fdm/jsbsim/propulsion/engine/engine-rpm");
    var hydro_active_norm = getprop("/fdm/jsbsim/hydro/active-norm");
    var ground_splash_norm = getprop("/environment/aircraft-effects/ground-splash-norm");

    # Use engine RPM and speed to control ground splash if on the water
    # and below 2 meter AGL
    if (getprop("position/altitude-agl-m") < 2 and hydro_active_norm > 0) {
        var groundspeed_half_pc = 0.005 * getprop("/velocities/groundspeed-kt");
        var engine_rpm_almost_nothing = 0.005 * 0.065 * engine_rpm;

        var splash_norm = std.max(engine_rpm_almost_nothing, groundspeed_half_pc);
        setprop("/environment/aircraft-effects/ground-splash-norm", splash_norm);
    }
    elsif (ground_splash_norm > 0)
        setprop("/environment/aircraft-effects/ground-splash-norm", ground_splash_norm - 0.005);

    if (getprop("/controls/mooring/anchor") and !getprop("fdm/jsbsim/mooring/mooring-connected")) {
        if (getprop("/fdm/jsbsim/mooring/anchor-length") == 0) {
            wind_from_heading = getprop("/environment/wind-from-heading-deg");
            aircraft_heading = getprop("/orientation/heading-deg");
            heading_diff = math.min(math.abs(aircraft_heading-wind_from_heading),math.abs(360-aircraft_heading+wind_from_heading),math.abs(360-wind_from_heading+aircraft_heading));
            wind_speed = getprop("/environment/windsock/wind-speed-kt");
            forward_speed = getprop("/fdm/jsbsim/hydro/vbx-fps");
            if (heading_diff > 85) {
                gui.popupTip("Face into the wind to set anchor", 5);
                setprop("/controls/mooring/anchor", 0);
                return;
            } elsif (wind_speed > 40) {
                gui.popupTip("Wind too high to anchor", 5);
                setprop("/controls/mooring/anchor", 0);
                return;
            } elsif (forward_speed > 7) {
                gui.popupTip("Can't anchor while moving forward", 5);
                setprop("/controls/mooring/anchor", 0);
                return;
            } elsif (getprop("/engines/active-engine/running")) {
                gui.popupTip("Can't anchor with engine running", 5);
                setprop("/controls/mooring/anchor", 0);
                return;
            } else {
                anchor_pos.set_latlon(getprop("/fdm/jsbsim/mooring/anchor-lat"), getprop("/fdm/jsbsim/mooring/anchor-lon"));
                setprop("fdm/jsbsim/mooring/latitude-deg", anchor_pos.lat());
                setprop("fdm/jsbsim/mooring/longitude-deg", anchor_pos.lon());
                setprop("fdm/jsbsim/mooring/altitude-ft", getprop("/position/ground-elev-ft"));
                anchor_dist = 0.0;
                setprop("/fdm/jsbsim/mooring/anchor-length", 1);
                setprop("/sim/anchorbuoy/enable", 1);
                setprop("fdm/jsbsim/mooring/mooring-connected", 1);
            }
        }
    }
    
    if (getprop("fdm/jsbsim/mooring/mooring-connected")) {
        aircraft_pos = geo.aircraft_position();
        anchor_dist = aircraft_pos.distance_to(anchor_pos);
        aircraft_heading = getprop("/orientation/heading-deg");
        var bearing = aircraft_pos.course_to(anchor_pos);
        var rel_bearing = (aircraft_heading - 180) - bearing;
        setprop("fdm/jsbsim/mooring/rope-yaw", rel_bearing);

        if (anchor_dist < (getprop("/fdm/jsbsim/mooring/rope-length-ft")*0.3048)-1) {
            setprop("fdm/jsbsim/mooring/rope-visible", 0);
        } else {
            setprop("fdm/jsbsim/mooring/rope-visible", 1);
        }
    }

	setprop("/fdm/jsbsim/hydro/environment/wave-amplitude-ft-step", rand()*-0.35);
}

var amp_draw_lighting_dimmer = func
{
	var draw_percent_range = ((getprop("systems/electrical/amps") - (-47)) / (7 - (-47)));
	setprop("/sim/model/pa-18/lighting/instrument-proc-step", 0.1 + ((0.3 - 0.1)* draw_percent_range));
	setprop("/controls/lighting/instruments-norm-step", 0.5 + ((1.0 - 0.5)* draw_percent_range));
	setprop("/controls/lighting/radio-norm-step", 0.4 + ((0.8 - 0.4)* draw_percent_range));

	###
	#0.3 + ((7 - value) * (0.1 - 0.3) / (7 - (-47))); AI
	#0.1 + ((0.3 - 0.1)*((value - (-47)) / (7 - (-47)))) Dustin
	#
	#1.0 - ((7 - value)*(1.0 - 0.8) / (7 - (-47))); AI
	#0.8 + ((1.0 - 0.8)*((value - (-47)) / (7 - (-47)))); Dustin
	###
}

# Duration in which no damage will occur. Assumes the aircraft has
# stabilized within this duration.
var bushkit_change_timeout = 8.0;

var physics_loop = func
{
    if (getprop("/sim/freeze/replay-state"))
        return;

    j3cub.particle_effects_loop();

    if (getprop("/fdm/jsbsim/bushkit") == 2 or getprop("/fdm/jsbsim/bushkit") == 3)
        poll_hydro();

	amp_draw_lighting_dimmer();
	
	if (getprop("/sim/model/j3cub/pa-18") == 0) setprop("/sim/model/j3cub/brake-parking", 0);
}

var set_bushkit = func (bushkit) {
    setprop("/fdm/jsbsim/damage/repairing", 1);
    reset_all_damage();
    bushkit_changed_timer.restart(bushkit_change_timeout);
};

# This timer object is used to enable damage again a short time after
# changing to the last bush kit option.
var bushkit_changed_timer = maketimer(bushkit_change_timeout, func {
    setprop("/fdm/jsbsim/damage/repairing", 0);
});
bushkit_changed_timer.singleShot = 1;

# Update the 3D model when changing bush kit
setlistener("/fdm/jsbsim/bushkit", func (n) {
    set_bushkit(n.getValue());
}, 1, 0);

setlistener("/fdm/jsbsim/crash", func (n) {
    if (n.getBoolValue() and getprop("position/altitude-agl-m") < 10) {
        killengine();
    }
}, 0, 0);

setlistener("/fdm/jsbsim/wing-damage/left-wing", func (n) {
    var left_wing = n.getValue();
    var right_wing = getprop("/fdm/jsbsim/wing-damage/right-wing");

    if (left_wing == 1.0) {
        if (right_wing == 1.0)
            gui.popupTip("Both wings BROKEN!", 5);
        else
            gui.popupTip("Left wing BROKEN!", 5);
    }
    elsif (left_wing > 0.0) {
        if (0.0 < right_wing and right_wing < 1.0)
            gui.popupTip("Both wings DAMAGED!", 5);
        else
            gui.popupTip("Left wing DAMAGED!", 5);

        #if (getprop("position/altitude-agl-m") < 10)
        #    killengine();
    }
}, 0, 0);

setlistener("/fdm/jsbsim/wing-damage/right-wing", func (n) {
    var left_wing = getprop("/fdm/jsbsim/wing-damage/left-wing");
    var right_wing = n.getValue();

    if (right_wing == 1.0) {
        if (left_wing == 1.0)
            gui.popupTip("Both wings BROKEN!", 5);
        else
            gui.popupTip("Right wing BROKEN!", 5);
    }
    elsif (right_wing > 0.0) {
        if (0.0 < left_wing and left_wing < 1.0)
            gui.popupTip("Both wings DAMAGED!", 5);
        else
            gui.popupTip("Right wing DAMAGED!", 5);

        #if (getprop("position/altitude-agl-m") < 10)
        #    killengine();
    }
}, 0, 0);

setlistener("/fdm/jsbsim/pontoon-damage/left-pontoon", func (n) {
    var left_pontoon = n.getValue();
    var right_pontoon = getprop("/fdm/jsbsim/pontoon-damage/right-pontoon");

    if (left_pontoon == 1) {
        if (right_pontoon == 1)
            gui.popupTip("Both pontoons BROKEN!", 5);
        else
            gui.popupTip("Left pontoon BROKEN!", 5);
    }
    elsif (left_pontoon == 2) {
        if (right_pontoon == 2)
            gui.popupTip("Both pontoons DAMAGED!", 5);
        else
            gui.popupTip("Left pontoon DAMAGED!", 5);
    }
}, 0, 0);

setlistener("/fdm/jsbsim/pontoon-damage/right-pontoon", func (n) {
    var left_pontoon = getprop("/fdm/jsbsim/pontoon-damage/left-pontoon");
    var right_pontoon = n.getValue();

    if (right_pontoon == 1) {
        if (left_pontoon == 1)
            gui.popupTip("Both pontoons BROKEN!", 5);
        else
            gui.popupTip("Right pontoon BROKEN!", 5);
    }
    elsif (right_pontoon == 2) {
        if (left_pontoon == 2)
            gui.popupTip("Both pontoons DAMAGED!", 5);
        else
            gui.popupTip("Right pontoon DAMAGED!", 5);
    }
}, 0, 0);

setlistener("/engines/active-engine/crashed", func (n) {
    if (n.getValue()) killengine();
}, 0, 0);

setlistener("/fdm/jsbsim/settings/damage", func {
    reset_all_damage();
});

setlistener("controls/gear/gear-down-command", func (n) {
    if (getprop("/fdm/jsbsim/pontoon-damage/left-pontoon")==0 and getprop("/fdm/jsbsim/pontoon-damage/right-pontoon")==0) {
        setprop("/fdm/jsbsim/damage/traversing", 1);
        bushkit_changed_timer.restart(bushkit_change_timeout);
    }
}, 0, 0);

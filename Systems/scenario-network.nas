###############################################################################
## $Id$
##
## Submarine Scout airship
##
##  Copyright (C) 2007 - 2008  Anders Gidenstam  (anders(at)gidenstam.org)
##  This file is licensed under the GPL license v2 or later.
##
###############################################################################

var Binary = nil;
var broadcast = nil;
var message_id = nil;

###############################################################################
# For backwards compatibility.
var load_nasal = func (a, b) {
    if (contains(io, "load_nasal")) {
        io.load_nasal(a, b);
    } else {
        debug.load_nasal(a, b);
    }
}

###############################################################################
# MP broadcast message handler.
var handle_message = func (sender, msg) {
#    print("Message from "~ sender.getNode("callsign").getValue() ~
#          " size: " ~ size(msg));
#    debug.dump(msg);
    var type = msg[0];
    if (type == message_id["bomb_impact"][0]) {
#        print("Submarine_Scout: Bomb impact!");
        var pos = Binary.decodeCoord(substr(msg, 1));
        debug.dump(pos);
        geo.put_model("Aircraft/Submarine_Scout/Models/flare.osg",
                      pos.lat(), pos.lon(), pos.alt(),
                      0, 0, 0);
    }
    if (type == message_id["place_ground_crew"][0]) {
#        print("Submarine_Scout: Ground crew for "~ sender.getPath() ~
#              " placed!");
        SubmarineScout.ground_crew.place_remote_ground_crew
            (sender.getPath(),
             Binary.decodeCoord(substr(msg, 1)),
             Binary.decodeCoord(substr(msg, 1 + Binary.sizeOf["Coord"])),
             Binary.decodeDouble(substr(msg, 1 + 2 * Binary.sizeOf["Coord"])));
    }
}

###############################################################################
# MP Accept and disconnect handlers.
var listen_to = func (pilot) {
    if (pilot.getNode("sim/model/ac-type") != nil and
        streq("Submarine_Scout",
              pilot.getNode("sim/model/ac-type").getValue())) {
#        print("Accepted " ~ pilot.getPath());
        return 1;
    } else {
#        print("Rejected " ~ pilot.getPath());
        return 0;
    }
}

var when_disconnecting = func (pilot) {
    SubmarineScout.ground_crew.remove_remote_ground_crew(pilot.getPath());
}

###############################################################################
# Minimal ground_crew replacement.
var remote_ground_crew = {
    ##################################################
    init : func {
        me.model = {};
    },
    ##################################################
    place_remote_ground_crew : func (key, pos1, pos2, heading) {
        if (!contains(me.model, key)) me.model[key] = [nil, nil];

        if (me.model[key][0] != nil) me.model[key][0].remove();
        if (me.model[key][1] != nil) me.model[key][1].remove();
        me.model[key][0] = geo.put_model
            ("Aircraft/Submarine_Scout/Models/GroundCrew/wire-party.xml",
             pos1, heading + 135.0);
        me.model[key][1] = geo.put_model
            ("Aircraft/Submarine_Scout/Models/GroundCrew/wire-party.xml",
             pos2, heading - 135.0);
    },
    ##################################################
    remove_remote_ground_crew : func (key) {
        if (!contains(me.model, key)) return;
        if (me.model[key][0] != nil) me.model[key][0].remove();
        if (me.model[key][1] != nil) me.model[key][1].remove();
    }
    ##################################################
};
remote_ground_crew.init();

###############################################################################
# Initialization.
var scenario_network_init = func (active_participant=0) {
    # Load the broadcast module if it isn't loaded yet.

    if (!contains(globals, "mp_broadcast")) {
        load_nasal(getprop("/sim/fg-root") ~
                   "/Aircraft/Submarine_Scout/Models/mp_broadcast.nas",
                   "mp_broadcast");
    }

    Binary = mp_broadcast.Binary;
    broadcast =
        mp_broadcast.BroadcastChannel.new
            ("sim/multiplay/generic/string[0]",
             handle_message,
             0,
             listen_to,
             when_disconnecting,
             active_participant);
    # Set up the recognized message types.
    message_id = { bomb_impact       : Binary.encodeByte(1),
                   place_ground_crew : Binary.encodeByte(2) };
}


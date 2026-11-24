set top_sig_list {
    { signal core.clk }
    { signal core.rst_n}
    { signal core.ifetch_fu_inst.pc[12:0] }
}

set busses_sig_list {
    { comment "Bus 0" }
    { signal core.busses[0][31:0] }
    { signal core.raddr_busses[0][6:0] }
    { signal core.waddr_busses[0][6:0] }
    { signal core.condition_flags[0][1:0]}
    { comment "Bus 1" }
    { signal core.busses[1][31:0] }
    { signal core.raddr_busses[1][6:0] }
    { signal core.waddr_busses[1][6:0] }
    { signal core.condition_flags[1][1:0] }
    { comment "Bus 2" }
    { signal core.busses[2][31:0] }
    { signal core.raddr_busses[2][6:0] }
    { signal core.waddr_busses[2][6:0] }
    { signal core.condition_flags[2][1:0] }
    { comment "Bus 3" }
    { signal core.busses[3][31:0] }
    { signal core.raddr_busses[3][6:0] }
    { signal core.waddr_busses[3][6:0] }
    { signal core.condition_flags[3][1:0] }
    { comment "Global State" }
    { signal core.status_bus }
    { signal core.squash_line }
}
set register_sig_list {
    { signal core.register_fu_inst.registers[0][31:0] }
    { signal core.register_fu_inst.registers[1][31:0] }
    { signal core.register_fu_inst.registers[2][31:0] }
    { signal core.register_fu_inst.registers[3][31:0] }
    { signal core.register_fu_inst.registers[4][31:0] }
    { signal core.register_fu_inst.registers[5][31:0] }
    { signal core.register_fu_inst.registers[6][31:0] }
    { signal core.register_fu_inst.registers[7][31:0] }
}


# Define a helper procedure to add comments + signals and group them
proc add_and_group_signals { group_name items {group 1} {collapse 0} } {
    set start_idx [ gtkwave::getTotalNumTraces ]
    set first_signal ""

    # 1. Add comments and signals in exact order
    foreach item $items {
        set type [ lindex $item 0 ]
        set val  [ lindex $item 1 ]

        if { $type eq "comment" } {
            gtkwave::addCommentTracesFromList [ list $val ]
        } elseif { $type eq "signal" } {
            set num_added [ gtkwave::addSignalsFromList [ list $val ] ]
            if { $num_added > 0 && $first_signal eq "" } {
                set first_signal $val
            } elseif { $num_added == 0 } {
                puts "Warning: Signal '$val' not found in dumpfile."
            }
        }
    }

    set end_idx [ gtkwave::getTotalNumTraces ]
    set count [ expr { $end_idx - $start_idx } ]

    # 2. Highlight the newly added traces and group them
    if { $count > 0 && $group } {
        gtkwave::/Edit/UnHighlight_All

        # Highlight all actual signals by name
        set sig_list {}
        foreach item $items {
            if { [ lindex $item 0 ] eq "signal" } {
                lappend sig_list [ lindex $item 1 ]
            }
        }
        if { [ llength $sig_list ] > 0 } {
            gtkwave::highlightSignalsFromList $sig_list
        }

        # If you also want leading/trailing comments inside the group, 
        # set focus to the start index and extend selection down:
        if { [ catch { gtkwave::setTraceHighlightFromIndex $start_idx 1 } ] == 0 } {
            gtkwave::/Edit/UnHighlight_All
            for { set i $start_idx } { $i < $end_idx } { incr i } {
                gtkwave::setTraceHighlightFromIndex $i 1
            }
        }

        # 5. Group the highlighted traces and name the group
        gtkwave::/Edit/Create_Group $group_name
        if {$collapse} {
            gtkwave::/Edit/Toggle_Group_Open|Close
        }
        gtkwave::/Edit/UnHighlight_All
    }
}

add_and_group_signals "Top" $top_sig_list 0
add_and_group_signals "Busses" $busses_sig_list 
add_and_group_signals "Register File" $register_sig_list 1 1

gtkwave::/Time/Zoom/Zoom_Full
/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

/**
 * A grab bag of utility classes for working with GTK.
 */

namespace California.Toolkit {

/**
 * Gtk.Stack transition duration is a little quick for my tastes; this default value seems a bit
 * smoother to me.
 */
public const int DEFAULT_STACK_TRANSITION_DURATION_MSEC = 300;

/**
 * Gtk.Stack transition duration for slower transitions (where it really needs to be obvious to
 * user what's going on).
 */
public const int SLOW_STACK_TRANSITION_DURATION_MSEC = 500;

/**
 * Indicates a GTK/GDK event should not be propagated further (no processing by other handlers).
 */
public const bool STOP = true;

/**
 * Indicates a GTK/GDK event should be propagated (continue processing by other handlers).
 */
public const bool PROPAGATE = false;

private int init_count = 0;

public void init() throws Error {
    if (!Unit.do_init(ref init_count))
        return;
    
    Calendar.init();
}

public void terminate() {
    if (!Unit.do_terminate(ref init_count))
        return;
    
    Calendar.terminate();
}

/**
 * Spin the GTK event loop until all pending events are completed.
 */
public void spin_event_loop() {
    while (Gtk.events_pending())
        Gtk.main_iteration();
}

}

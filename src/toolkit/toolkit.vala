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
private Gee.Set<Gtk.Widget>? dead_pool = null;
private Scheduled? dead_pool_gc = null;

public void init() throws Error {
    if (!Unit.do_init(ref init_count))
        return;
    
    dead_pool = new Gee.HashSet<Gtk.Widget>();
    
    Calendar.init();
    Collection.init();
}

public void terminate() {
    if (!Unit.do_terminate(ref init_count))
        return;
    
    Collection.terminate();
    Calendar.terminate();
    
    dead_pool = null;
    dead_pool_gc = null;
}

/**
 * Spin the GTK event loop until all pending events are completed.
 */
public void spin_event_loop() {
    while (Gtk.events_pending())
        Gtk.main_iteration();
}

/**
 * Sets the window as "busy" by changing the cursor.
 *
 * @returns the window's current Gdk.Cursor.  This will need to be passed to
 * {@link set_window_unbusy}.
 */
public Gdk.Cursor? set_busy(Gtk.Widget widget) {
    Gtk.Widget toplevel = widget.get_toplevel();
    if (!toplevel.is_toplevel()) {
        debug("Unable to set busy: widget has no toplevel window");
        
        return null;
    }
    
    Gdk.Window gdk_window = toplevel.get_window();
    Gdk.Cursor? unbusy_cursor = gdk_window.get_cursor();
    gdk_window.set_cursor(new Gdk.Cursor.for_display(toplevel.get_display(), Gdk.CursorType.WATCH));
    
    return unbusy_cursor;
}

/**
 * Sets the window as "unbusy".
 *
 * Pass the Gdk.Cursor returned by {@link set_window_busy}.
 */
public void set_unbusy(Gtk.Widget widget, Gdk.Cursor? unbusy_cursor) {
    Gtk.Widget toplevel = widget.get_toplevel();
    if (!toplevel.is_toplevel()) {
        if (unbusy_cursor != null)
            debug("Unable to set unbusy: widget has no toplevel window");
        
        return;
    }
    
    toplevel.get_window().set_cursor(unbusy_cursor);
}

/**
 * Destroy a Gtk.Widget when the event loop is idle.
 */
public void destroy_later(Gtk.Widget widget) {
    if (!dead_pool.add(widget))
        return;
    
    // always reschedule
    dead_pool_gc = new Scheduled.once_at_idle(() => {
        // traverse_safely makes a copy of the dead_pool, so filter() won't work to remove destroyed
        // elements, but that also means we can safely remove elements from it in the iterate()
        // handler ... need to jump through these hoops because the widget.destroy() signal handlers
        // may turn around and add more widgets to the dead pool during traversal
        traverse_safely<Gtk.Widget>(dead_pool).iterate((widget) => {
            widget.destroy();
            dead_pool.remove(widget);
        });
    }, Priority.LOW);
}

}

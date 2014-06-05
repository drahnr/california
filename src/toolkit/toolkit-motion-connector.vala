/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Toolkit {

/**
 * A {@link EventConnector} for pointer (mouse) motion events, including the pointer entering and
 * exiting the widget's space.
 */

public class MotionConnector : EventConnector {
    /**
     * Fired when the pointer (mouse cursor) enters the Gtk.Widget.
     */
    public signal void entered(MotionEvent event);
    
    /**
     * Fired when the pointer (mouse cursor) leaves the Gtk.Widget.
     */
    public signal void exited(MotionEvent event);
    
    /**
     * Fired when the pointer (mouse cursor) moves across the Gtk.Widget.
     *
     * @see button_motion
     */
    public signal void motion(MotionEvent event);
    
    /**
     * Fired when the pointer (mouse cursor) moves across the Gtk.Widget while a button is pressed.
     *
     * @see motion
     */
    public signal void button_motion(MotionEvent event);
    
    public MotionConnector() {
        base (Gdk.EventMask.POINTER_MOTION_MASK | Gdk.EventMask.ENTER_NOTIFY_MASK | Gdk.EventMask.LEAVE_NOTIFY_MASK);
    }
    
    /**
     * Create a {@link MotionConnector} that only reports motion when a button is depressed.
     *
     * This generates fewer events and should be used if the subscribers signal handlers are only
     * interested in motion while a button is depressed.
     */
    public MotionConnector.button_only() {
        base (Gdk.EventMask.BUTTON_MOTION_MASK | Gdk.EventMask.ENTER_NOTIFY_MASK | Gdk.EventMask.LEAVE_NOTIFY_MASK);
    }
    
    /**
     * Subclasses may override this call to update state before or after the signal fires.
     */
    protected void notify_entered(MotionEvent event) {
        entered(event);
    }
    
    /**
     * Subclasses may override this call to update state before or after the signal fires.
     */
    protected void notify_exited(MotionEvent event) {
        exited(event);
    }
    
    /**
     * Subclasses may override this call to update state before or after the signal fires.
     */
    protected void notify_motion(MotionEvent event) {
        motion(event);
    }
    
    /**
     * Subclasses may override this call to update state before or after the signal fires.
     */
    protected void notify_button_motion(MotionEvent event) {
        button_motion(event);
    }
    
    protected override void connect_signals(Gtk.Widget widget) {
        widget.motion_notify_event.connect(on_motion_notify_event);
        widget.enter_notify_event.connect(on_enter_notify_event);
        widget.leave_notify_event.connect(on_leave_notify_event);
    }
    
    protected override void disconnect_signals(Gtk.Widget widget) {
        widget.motion_notify_event.disconnect(on_motion_notify_event);
        widget.enter_notify_event.disconnect(on_enter_notify_event);
        widget.leave_notify_event.disconnect(on_leave_notify_event);
    }
    
    private bool on_motion_notify_event(Gtk.Widget widget, Gdk.EventMotion event) {
        MotionEvent motion_event = new MotionEvent(widget, event);
        
        notify_motion(motion_event);
        if (motion_event.is_any_button_pressed())
            notify_button_motion(motion_event);
        
        return Toolkit.PROPAGATE;
    }
    
    private bool on_enter_notify_event(Gtk.Widget widget, Gdk.EventCrossing event) {
        notify_entered(new MotionEvent.for_crossing(widget, event));
        
        return Toolkit.PROPAGATE;
    }
    
    private bool on_leave_notify_event(Gtk.Widget widget, Gdk.EventCrossing event) {
        notify_entered(new MotionEvent.for_crossing(widget, event));
        
        return Toolkit.PROPAGATE;
    }
}

}


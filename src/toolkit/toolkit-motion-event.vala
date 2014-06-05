/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Toolkit {

/**
 * Details of a pointer (mouse) motion event, including entering and leaving a widget.
 */

public class MotionEvent : BaseObject {
    /**
     * The Gtk.Widget in question.
     */
    public Gtk.Widget widget { get; private set; }
    
    /**
     * The pointer location at the time of the event.
     */
    private Gdk.Point _point = Gdk.Point();
    public Gdk.Point point { get { return _point; } }
    
    /**
     * The state of the modifier keys at the time of the event.
     */
    public Gdk.ModifierType modifiers { get; private set; }
    
    internal MotionEvent(Gtk.Widget widget, Gdk.EventMotion event) {
        this.widget = widget;
        _point.x = (int) event.x;
        _point.y = (int) event.y;
        modifiers = event.state;
    }
    
    internal MotionEvent.for_crossing(Gtk.Widget widget, Gdk.EventCrossing event) {
        this.widget = widget;
        _point.x = (int) event.x;
        _point.y = (int) event.y;
        modifiers = event.state;
    }
    
    /**
     * Returns true if the {@link Button} is pressed at the time of this event.
     */
    public bool is_button_pressed(Button button) {
        return (modifiers & button.get_modifier_mask()) != 0;
    }
    
    /**
     * Returns true if any button is pressed at the time of this event.
     */
    public bool is_any_button_pressed() {
        return (modifiers &
            (Gdk.ModifierType.BUTTON1_MASK
            | Gdk.ModifierType.BUTTON1_MASK
            | Gdk.ModifierType.BUTTON1_MASK
            | Gdk.ModifierType.BUTTON1_MASK
            | Gdk.ModifierType.BUTTON1_MASK)) != 0;
    }
    
    public override string to_string() {
        return "MotionEvent %d,%d".printf(point.x, point.y);
    }
}

}


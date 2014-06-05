/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Toolkit {

/**
 * Enumeration for (mouse) buttons.
 *
 * @see ButtonConnector
 */
public enum Button {
    PRIMARY,
    SECONDARY,
    TERTIARY,
    OTHER;
    
    /**
     * Converts the button field of a Gdk.EventButton to a {@link Button} enumeration.
     */
    public static Button from_button_event(Gdk.EventButton event) {
        switch (event.button) {
            case 1:
                return PRIMARY;
            
            case 3:
                return SECONDARY;
            
            case 2:
                return TERTIARY;
            
            default:
                return OTHER;
        }
    }
    
    /**
     * Returns the Gdk.ModifierType corresponding to this {@link Button}.
     *
     * {@link OTHER} merely means any button not {@link PRIMARY}, {@link SECONDARY}, or
     * {@link TERTIARY}.
     */
    public Gdk.ModifierType get_modifier_mask() {
        switch (this) {
            case PRIMARY:
                return Gdk.ModifierType.BUTTON1_MASK;
            
            case SECONDARY:
                return Gdk.ModifierType.BUTTON2_MASK;
            
            case TERTIARY:
                return Gdk.ModifierType.BUTTON3_MASK;
            
            case OTHER:
                return Gdk.ModifierType.BUTTON4_MASK | Gdk.ModifierType.BUTTON5_MASK;
            
            default:
                assert_not_reached();
        }
    }
}

/**
 * Details of a (mouse) button event as reported by {@link ButtonConnector}.
 */

public class ButtonEvent : BaseObject {
    /**
     * The Gtk.Widget the button press occurred on.
     *
     * Even if the button is released over a different widget, this widget is always reported
     * by GTK and all coordinates are relative to it.
     */
    public Gtk.Widget widget { get; private set; }
    
    /**
     * The {@link Button} the event originated from.
     */
    public Button button { get; private set; }
    
    /**
     * The last-seen button press type.
     */
    public Gdk.EventType press_type { get; private set; }
    
    /**
     * The x,y coordinates (in {@link widget}'s coordinate system} the last press occurred.
     */
    private Gdk.Point _press_point = Gdk.Point();
    public Gdk.Point press_point { get { return _press_point; } }
    
    /**
     * The x,y coordinates (in {@link widget}'s coordinate system} the last release occurred.
     */
    private Gdk.Point _release_point = Gdk.Point();
    public Gdk.Point release_point { get { return _release_point; } }
    
    internal ButtonEvent(Gtk.Widget widget, Gdk.EventButton press_event) {
        this.widget = widget;
        button = Button.from_button_event(press_event);
        press_type = press_event.type;
        _press_point.x = (int) press_event.x;
        _press_point.y = (int) press_event.y;
    }
    
    // Update state with the next button press
    internal virtual void update_press(Gtk.Widget widget, Gdk.EventButton press_event) {
        assert(this.widget == widget);
        assert(Button.from_button_event(press_event) == button);
        
        press_type = press_event.type;
        _press_point.x = (int) press_event.x;
        _press_point.y = (int) press_event.y;
    }
    
    // Update state with the next button release and start the release timer
    internal virtual void update_release(Gtk.Widget widget, Gdk.EventButton release_event) {
        assert(this.widget == widget);
        assert(Button.from_button_event(release_event) == button);
        
        _release_point.x = (int) release_event.x;
        _release_point.y = (int) release_event.y;
    }
    
    public override string to_string() {
        return "EventDetails: button=%s press_type=%s".printf(button.to_string(), press_type.to_string());
    }
}

}


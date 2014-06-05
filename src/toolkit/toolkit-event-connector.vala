/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Toolkit {

/**
 * An EventConnector is a type of signalling mechanism for specific user-input events.
 *
 * Gtk.Widgets are connected to EventConnector via {@link connect_to}.  EventConnector signals can
 * then monitored for specific events originating from all the connected widgets.  This promotes
 * reuse of code, as EventConenctor objects may be shared among disparate widgets, or separate
 * instances for each, with each EventConnector (or a custom subclass) able to maintain its own
 * state rather than having to pollute a container widget's space with its own concerns.
 *
 * In general, EventConnectors will not work with NO_WINDOW widgets.  Place them in a Gtk.EventBox
 * and connect this object to that.
 */

public abstract class EventConnector : BaseObject {
    private Gdk.EventMask event_mask;
    private Gee.HashSet<Gtk.Widget> widgets = new Gee.HashSet<Gtk.Widget>();
    
    protected EventConnector(Gdk.EventMask event_mask) {
        this.event_mask = event_mask;
    }
    
    ~EventConnector() {
        // use to_array() to avoid iterator issues as widgets are removed
        foreach (Gtk.Widget widget in widgets.to_array())
            disconnect_from(widget);
    }
    
    /**
     * Have this {@link EventConnector} monitor the widget for the connector's specific events.
     */
    public void connect_to(Gtk.Widget widget) {
        // don't continue if already connected
        if (!widgets.add(widget))
            return;
        
        widget.add_events(event_mask);
        connect_signals(widget);
        widget.destroy.connect(on_widget_destroy);
    }
    
    /**
     * Have this {@link EventConnector} stop monitoring the widget for the connector's specific
     * events.
     *
     * If the widget is destroyed, EventConnector will automatically stop monitoring it.
     */
    public void disconnect_from(Gtk.Widget widget) {
        // don't disconnect if not connected
        if (!widgets.remove(widget))
            return;
        
        // can't remove event mask safely, so just don't
        disconnect_signals(widget);
        widget.destroy.disconnect(on_widget_destroy);
    }
    
    private void on_widget_destroy(Gtk.Widget widget) {
        disconnect_from(widget);
    }
    
    /**
     * Subclasses should use this method to connect to their appropriate signals.
     *
     * The event mask is updated automatically, so that's not necessary.
     */
    protected abstract void connect_signals(Gtk.Widget widget);
    
    /**
     * Subclasses should use this method to disconnect the signals they connected to.
     *
     * This is also a good time to clean up any lingering state.
     */
    protected abstract void disconnect_signals(Gtk.Widget widget);
    
    public override string to_string() {
        return get_class().get_type().name();
    }
}

}


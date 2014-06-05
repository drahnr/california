/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.View.Common {

/**
 * A Gtk.Widget which displays {@link Component.Instance}s.
 *
 * This does not require Gtk.Container because what's important is the display mechanism, not a
 * grouping of Gtk.Widgets, if any.
 */

public interface InstanceContainer : Gtk.Widget {
    public const string PROP_EVENT_COUNT = "event-count";
    public const string PROP_CONTAINED_SPAN = "contained-span";
    public const string PROP_HAS_EVENTS = "has-events";
    
    /**
     * The number of events held by the {@link InstanceContainer}.
     */
    public abstract int event_count { get; }
    
    /**
     * The {@link Calendar.Span} this {@link InstanceContainer} represents.
     */
    public abstract Calendar.Span contained_span { get; }
    
    /**
     * True if the {@link InstanceContainer} is holding one or more {@link Component.Event}s.
     */
    public bool has_events { get { return event_count > 0; } }
    
    /**
     * Add a {@link Component.Event} to the {@link InstanceContainer}.
     *
     * If the event is already added to the InstanceContainer, nothing is changed.
     */
    public abstract void add_event(Component.Event event);
    
    /**
     * Remove a {@link Component.Event} from the {@link InstanceContainer}.
     *
     * If the event was not previously add to the InstanceContainer, nothing is changed.
     */
    public abstract void remove_event(Component.Event event);
    
    /**
     * Clears all {@link Component.Event}s from the {@link InstanceContainer}.
     */
    public abstract void clear_events();
    
    /**
     * Performs a hit-test for the supplied Gdk.Point.
     *
     * Returns the {@link Component.Event}, if any, at the point.  Coordinates are in the widget's
     * coordinate system.
     */
    public abstract Component.Event? get_event_at(Gdk.Point point);
}

}


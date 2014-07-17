/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Backing {

/**
 * An abstract representation of a backing source of calendar information.
 *
 * CalendarSource provides information about the calendar and an interface for operating on
 * {@link Component.Instance}s in the calendar.  Use {@link CalendarSourceSubscription} to generate
 * those instances for specific windows of time.
 *
 * @see Manager
 * @see Source
 */

public abstract class CalendarSource : Source {
    /**
     * The affected range of a removal operation.
     *
     * Note that zero (0) does ''not'' mean "none", it means {@link AffectedInstances.THIS}.  The
     * additional enums merely expand the scope of the default, which is the supplied instance.
     */
    public enum AffectedInstances {
        /**
         * Include the supplied {@link Component.Instance} in the affected instances.
         */
        THIS = 0,
        /**
         * Include all future {@link Component.Instance}s in the affected instances.
         */
        THIS_AND_FUTURE,
        /**
         * Indicating all {@link Component.Instance}s should be affected.
         */
        ALL
    }
    
    protected CalendarSource(string id, string title) {
        base (id, title);
    }
    
    /**
     * Obtain a {@link CalendarSourceSubscription} for the specified date window.
     */
    public abstract async CalendarSourceSubscription subscribe_async(Calendar.ExactTimeSpan window,
        Cancellable? cancellable = null) throws Error;
    
    /**
     * Creates a new {@link Component} instance on the backing {@link CalendarSource}.
     *
     * Outstanding {@link CalendarSourceSubscriptions} will eventually report the generated
     * instance when it's available.  If the supplied instance includes an RRULE (i.e.
     * {@link Component.Instance.rrule}), one or more instances will be generated.
     *
     * @returns The {@link Component.UID}.keyed to all instances, if available.
     */
    public abstract async Component.UID? create_component_async(Component.Instance instance,
        Cancellable? cancellable = null) throws Error;
    
    /**
     * Updates an existing {@link Component} instance on the backing {@link CalendarSource}.
     *
     * To update all {@link Instance}s of a recurring {@link Instance}, submit the
     * {@link Component.Instance.master} with modifications rather than one of its generated
     * instances.  Submit a generated instance to update only that one.
     *
     * Outstanding {@link CalendarSourceSubscriptions} will eventually report the changes when
     * ready.
     */
    public abstract async void update_component_async(Component.Instance instance,
        Cancellable? cancellable = null) throws Error;
    
    /**
     * Destroys (removes) all {@link Component.Instance}s on the backing {@link CalendarSource}
     * keyed to the supplied {@link Component.UID}.
     *
     * Outstanding {@link CalendarSourceSubscriptions} will eventually report all affected instances
     * as removed.
     */
    public abstract async void remove_all_instances_async(Component.UID uid,
        Cancellable? cancellable = null) throws Error;
    
    /**
     * Destroys (removes) some or all {@link Component.Instance}s on the backing
     * {@link CalendarSource} keyed to the supplied {@link Component.UID}, the supplied RID,
     * and the {@link AffectedInstances}.
     *
     * If {@link AffectedInstances.ALL} is passed, the RID is ignored.  This is operationally the
     * same as calling {@link remove_all_instances_async}.
     *
     * Outstanding {@link CalendarSourceSubscriptions} will eventually report all affected instances
     * as removed.
     */
    public abstract async void remove_instances_async(Component.UID uid, Component.DateTime rid,
        AffectedInstances affected, Cancellable? cancellable = null) throws Error;
    
    /**
     * Imports a {@link Component.iCalendar} into the {@link CalendarSource}.
     */
    public abstract async void import_icalendar_async(Component.iCalendar ical, Cancellable? cancellable = null)
        throws Error;
}

}


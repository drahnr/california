/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Backing {

/**
 * A subscription to an active timespan of interest of a calendar.
 *
 * CalendarSourceSubscription generates {@link Component.Instance}s of the various events in a
 * window of time in a calendar.  Note that for recurring events, there is no interface to directly
 * edit or remove the "original" iCalendar source.  Rather, the caller should update or remove
 * generated instances of that recurring event with flags to indicate how the original is to be
 * altered to match these changes.  See {@link CalendarSource} for the interface to make these
 * alterations.
 *
 * The subscription can notify of calendar event updates and list a complete or partial collections
 * of the same.
 */

public abstract class CalendarSourceSubscription : BaseObject {
    /**
     * The {@link CalendarSource} providing this subscription's information.
     */
    public CalendarSource calendar { get; private set; }
    
    /**
     * The date-time window.
     *
     * This represents the span of time of interest for thie calendar source.
     */
    public Calendar.ExactTimeSpan window { get; private set; }
    
    /**
     * Indicates the subscription is running (started).
     *
     * If it's important to know when {@link start} completes in the background, the caller can
     * watch for this property to change state to true.  {@link start_failed} is fired if start()
     * completed with an Error.
     *
     * Once set, the Cancellable passed to start is no longer referenced by the subscription.
     *
     * This can't be set inactive by the caller, but it can happen at any time (such as the
     * calendar being removed or closed).
     */
    public bool active { get; protected set; default = false; }
    
    /**
     * Fired as existing {@link Component.Instance}s are discovered when starting a subscription.
     *
     * This is fired while {@link start} is working, either in the foreground or in the background.
     * It won't fire until start() is invoked.
     */
    public signal void instance_discovered(Component.Instance instance);
    
    /**
     * Indicates that an {@link Instance} within the {@link window} has been added to the calendar.
     *
     * The signal is fired for both local additions (added through this interface) and remote
     * additions.
     *
     * This signal won't fire until {@link start} is called.
     */
    public signal void instance_added(Component.Instance instance);
    
    /**
     * Indicates that an {@link Instance} within the {@link date_window} has been removed from the
     * calendar.
     *
     * The signal is fired for both local removals (added through this interface) and remote
     * removals.
     *
     * This signal won't fire until {@link start} is called.
     */
    public signal void instance_removed(Component.Instance instance);
    
    /**
     * Indicates that an {@link Instance} within the {@link date_window} has been altered.
     *
     * This is fired after the alterations have been made.  Since the {@link Component.Instance}s
     * are mutable, it's possible to monitor their properties for changes and be notified that way.
     *
     * The signal is fired for both local additions (added through this interface) and remote
     * additions.
     *
     * This signal won't fire until {@link start} is called.
     */
    public signal void instance_altered(Component.Instance instance);
    
    /**
     * Indicates than the {@link Instance} within the {@link date_window} has been dropped due to
     * the {@link Source} going unavailable.
     *
     * Generally all the subscription's instances will be reported one after another, but this
     * shouldn't be relied upon.
     *
     * Since the Source is now unavailable, this indicates that the Subscription will not be
     * very useful going forward.
     *
     * This issue is handled by this base class.  Subclasses should only call the notify method
     * if they have another method of determining the Source is unavailable.  Even then, the
     * best course is to call {@link Source.set_unavailable} and override
     * {@link notify_events_dropped} to perform internal bookkeeping.
     */
    public signal void instance_dropped(Component.Instance instance);
    
    /**
     * Fired if {@link start} failed.
     *
     * Because start() may require background operations to complete, it's possible for it to return
     * without error and only discover later the issue.  This signal is fired when that occurs.
     *
     * It's possible for this to be called in the context of start().
     *
     * If this fires, this subscription should be considered inactive.  Do not call start() again.
     */
    public signal void start_failed(Error err);
    
    // Although Component.Instance has no simple notion of one UID for multiple instances, its
    // subclasses (i.e. Event) do
    private Gee.HashMultiMap<Component.UID, Component.Instance> instances = new Gee.HashMultiMap<
        Component.UID, Component.Instance>();
    
    protected CalendarSourceSubscription(CalendarSource calendar, Calendar.ExactTimeSpan window) {
        this.calendar = calendar;
        this.window = window;
        
        calendar.notify[Source.PROP_IS_AVAILABLE].connect(on_source_unavailable);
    }
    
    /**
     * Add a @link Component.Instance} discovered while starting the subscription to the
     * internal collection of instances and notify subscribers.
     *
     * As with the other notify_*() methods, subclasses should invoke this method to fire the
     * signal rather than do it directly.  This gives {@link CalenderSourceSubscription} the
     * opportunity to update its internal state prior to firing the signal.
     *
     * It can also be overridden by a subclass to take action before or after the signal is fired.
     *
     * @see instance_discovered
     */
    protected virtual void notify_instance_discovered(Component.Instance instance) {
        if (add_instance(instance))
            instance_discovered(instance);
        else
            debug("Cannot add discovered component %s to %s: already known", instance.to_string(), to_string());
    }
    
    /**
     * Add a new {@link Component.Instance} to the subscription and notify subscribers.
     *
     * @see notify_instance_discovered
     * @see instance_added
     */
    protected virtual void notify_instance_added(Component.Instance instance) {
        if (add_instance(instance))
            instance_added(instance);
        else
            debug("Cannot add component %s to %s: already known", instance.to_string(), to_string());
    }
    
    /**
     * Remove an {@link Component.Instance} from the subscription and notify subscribers.
     *
     * @see notify_instance_discovered
     * @see instance_removed
     */
    protected virtual void notify_instance_removed(Component.UID uid) {
        Gee.Collection<Component.Instance> removed_instances;
        if (remove_instance(uid, out removed_instances)) {
            foreach (Component.Instance instance in removed_instances)
                instance_removed(instance);
        } else {
            debug("Cannot remove UID %s from %s: not known", uid.to_string(), to_string());
        }
    }
    
    /**
     * Update an altered {@link Component.Instance} and notify subscribers.
     *
     * @see notify_instance_discovered
     * @see instance_altered
     */
    protected virtual void notify_instance_altered(Component.Instance instance) {
        if (instances.contains(instance.uid))
            instance_altered(instance);
        else
            debug("Cannot notify altered component %s in %s: not known", instance.to_string(), to_string());
    }
    
    /**
     * Notify that the {@link Component.Instance}s have been dropped due to the {@link Source} going
     * unavailable.
     */
    protected virtual void notify_instance_dropped(Component.Instance instance) {
        Gee.Collection<Component.Instance> removed_instances;
        if (remove_instance(instance.uid, out removed_instances)) {
            foreach (Component.Instance removed_instance in removed_instances)
                instance_dropped(removed_instance);
        } else {
            debug("Cannot notify dropped component %s in %s: not known", instance.to_string(), to_string());
        }
    }
    
    private bool add_instance(Component.Instance instance) {
        bool already_exists = instances.get(instance.uid).contains(instance);
        if (!already_exists)
            instances.set(instance.uid, instance);
        
        return !already_exists;
    }
    
    private bool remove_instance(Component.UID uid, out Gee.Collection<Component.Instance> removed_instances) {
        bool removed = instances.contains(uid);
        if (removed) {
            removed_instances = instances.get(uid);
            instances.remove_all(uid);
        } else {
            removed_instances = new Gee.ArrayList<Component.Instance>();
        }
        
        return removed;
    }
    
    /**
     * Start the subscription.
     *
     * Notification signals won't start until this is called.  This is to allow the caller a chance
     * to connect to the signals of interest before receiving notifications, so nothing is missed.
     *
     * Only new events trigger "event-added".  To fetch a current list of all events in the
     * window, use {@link list_events}.
     *
     * A subscription can't be stopped or the {@link window} altered.  Simply drop the reference
     * and create another one with {@link CalendarSource.subscribe_async}.
     *
     * If start is cancelled, the caller should assume this object to be invalid (incomplete)
     * unless {@link active} is true.  At that point the Cancellable will no longer be used by
     * the subscription.
     */
    public abstract void start(Cancellable? cancellable = null);
    
    /**
     * Wait for {@link start} to complete.
     *
     * This call will block until the {@link CalendarSourceSubscription} has started.  It will
     * pump the event loop to ensure other operations can complete, although be warned that
     * introduces the possibility of reentrancy, which this method is not guaraneteed to deal with.
     *
     * @throws BackingError.INVALID if called before start() has been invoked or IOError.CANCELLED
     * if the Cancellable is cancelled.
     */
    public abstract void wait_until_started(MainContext context = MainContext.default(),
        Cancellable? cancellable = null) throws Error;
    
    private void on_source_unavailable() {
        if (calendar.is_available)
            return;
        
        // Use to_array() so no iteration troubles when notify_instance_dropped removes it from
        // the multimap
        debug("Dropping %d instances to %s: unavailable", instances.size, calendar.to_string());
        foreach (Component.Instance instance in instances.get_values().to_array())
            notify_instance_dropped(instance);
    }
    
    /**
     * Returns true if the {@link Component.UID} has been seen in this
     * {@link CalendarSourceSubscription}.
     */
    public bool has_uid(Component.UID uid) {
        return instances.contains(uid);
    }
    
    /**
     * Returns all {@link Component.Instance}s for the {@link Component.UID}.
     *
     * @returns null if the UID has not been seen.
     */
    public Gee.Collection<Component.Instance>? for_uid(Component.UID uid) {
        return instances.contains(uid) ? instances.get(uid) : null;
    }
    
    /**
     * Returns the seen {@link Component.Instance} matching the supplied (possibly partially
     * filled-out) Instance.
     *
     * This is for duplicate detection, especially if the {@link Backing} is receiving raw iCal
     * source and needs to verify if it's been parsed and introduced into the system.
     *
     * A blank Instance with partial fields filled out can be supplied.
     */
    public Component.Instance? has_instance(Component.Instance instance) {
        Gee.Collection<Component.Instance>? seen_instances = for_uid(instance.uid);
        if (seen_instances == null || seen_instances.size == 0)
            return null;
        
        // for every instance matching its UID, look for the original
        foreach (Component.Instance seen_instance in seen_instances) {
            if (seen_instance.equal_to(instance))
                return seen_instance;
        }
        
        return null;
    }
    
    public override string to_string() {
        return "%s::%s".printf(calendar.to_string(), window.to_string());
    }
}

}


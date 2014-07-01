/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Backing {

/**
 * A calendar subscription to an EDS source.
 */

internal class EdsCalendarSourceSubscription : CalendarSourceSubscription {
    private E.CalClientView view;
    // this is different than "active", which gets set when start completes
    private bool started = false;
    private Error? start_err = null;
    
    // Called from EdsCalendarSource.subscribe_async().  The CalClientView should not be started
    public EdsCalendarSourceSubscription(EdsCalendarSource eds_calendar, Calendar.ExactTimeSpan window,
        E.CalClientView view) {
        base (eds_calendar, window);
        
        this.view = view;
    }
    
    ~EdsCalendarSourceSubscription() {
        // need to wait for the finished callback if started
        if (started && !active)
            wait_until_started();
    }
    
    /**
     * @inheritDoc
     */
    public override void wait_until_started(MainContext context = MainContext.default(),
        Cancellable? cancellable = null) throws Error {
        if (!started)
            throw new BackingError.INVALID("EdsCalendarSourceSubscription not started");
        
        if (start_err != null)
            throw start_err;
        
        while (!active) {
            if (cancellable != null && cancellable.is_cancelled())
                throw new IOError.CANCELLED("wait_until_started() cancelled");
            
            context.iteration(true);
        }
    }
    
    /**
     * @inheritDoc
     */
    public override void start(Cancellable? cancellable) {
        // silently ignore repeated starts
        if (started || start_err != null)
            return;
        
        started = true;
        
        try {
            internal_start(cancellable);
        } catch (Error err) {
            start_err = err;
            
            start_failed(err);
        }
    }
    
    private void internal_start(Cancellable? cancellable) throws Error {
        // prepare flags and fields of interest .. don't want known events delivered via signals
        view.set_fields_of_interest(null);
        view.set_flags(E.CalClientViewFlags.NONE);
        
        // subscribe *before* starting so nothing is missed
        view.objects_added.connect(on_objects_added);
        view.objects_removed.connect(on_objects_removed);
        view.objects_modified.connect(on_objects_modified);
        
        // start now ... will be notified of new events, but not existing ones, which are fetched
        // next
        view.start();
        
        // prime with the list of known events
        view.client.generate_instances(
            window.start_exact_time.to_time_t(),
            window.end_exact_time.to_time_t(),
            cancellable,
            on_instance_generated,
            on_generate_finished);
    }
    
    private bool on_instance_generated(E.CalComponent eds_component, time_t instance_start,
        time_t instance_end) {
        try {
            Component.Event? event = Component.Instance.convert(calendar, eds_component.get_icalcomponent())
                as Component.Event;
            if (event != null)
                notify_instance_discovered(event);
        } catch (Error err) {
            debug("Unable to generate discovered event for %s: %s", to_string(), err.message);
        }
        
        return true;
    }
    
    private void on_generate_finished() {
        // only set when generation (start) is finished
        active = true;
    }
    
    private void on_objects_added(SList<weak iCal.icalcomponent> objects) {
        foreach (weak iCal.icalcomponent ical_component in objects) {
            view.client.generate_instances_for_object(
                ical_component,
                window.start_exact_time.to_time_t(),
                window.end_exact_time.to_time_t(),
                null,
                on_instance_added,
                null);
        }
    }
    
    private bool on_instance_added(E.CalComponent eds_component, time_t instance_start,
        time_t instance_end) {
        unowned iCal.icalcomponent ical_component = eds_component.get_icalcomponent();
        
        // convert the added component into a new Event
        Component.Event? added_event;
        try {
            added_event = Component.Instance.convert(calendar, ical_component) as Component.Event;
            if (added_event == null)
                return true;
        } catch (Error err) {
            debug("Unable to process added event: %s", err.message);
            
            return true;
        }
        
        // see if this was seen before
        Component.Event? seen_event = has_instance(added_event) as Component.Event;
        if (seen_event != null)
            return true;
        
        // nope, it's a new one
        notify_instance_added(added_event);
        
        return true;
    }
    
    private void on_objects_modified(SList<weak iCal.icalcomponent> objects) {
        foreach (weak iCal.icalcomponent ical_component in objects) {
            // convert the modified event source into an orphaned event (for comparison purposes)
            Component.Event modified_event;
            try {
                modified_event = new Component.Event(null, ical_component);
            } catch (Error err) {
                debug("Unable to process modified event: %s", err.message);
                
                continue;
            }
            
            // find original event instance for this one
            Component.Event? seen_event = has_instance(modified_event) as Component.Event;
            if (seen_event == null)
                continue;
            
            try {
                seen_event.full_update(ical_component, null);
            } catch (Error err) {
                debug("Unable to update event %s: %s", seen_event.to_string(), err.message);
            }
            
            notify_instance_altered(seen_event);
        }
    }
    
    private void on_objects_removed(SList<weak E.CalComponentId?> ids) {
        foreach (weak E.CalComponentId id in ids)
            notify_instance_removed(new Component.UID(id.uid));
    }
}

}


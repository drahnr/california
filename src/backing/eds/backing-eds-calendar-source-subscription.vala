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
    public EdsCalendarSourceSubscription(EdsCalendarSource eds_calendar, Calendar.DateTimeSpan window,
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
            (time_t) window.start_date_time.to_unix(),
            (time_t) window.end_date_time.to_unix(),
            cancellable,
            on_instance_generated,
            on_generate_finished);
    }
    
    private bool on_instance_generated(E.CalComponent eds_component, time_t instance_start,
        time_t instance_end) {
        try {
            Component.Event? event = Component.Instance.convert(eds_component) as Component.Event;
            if (event != null)
                notify_event_discovered(event);
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
            E.CalComponent eds_component = new E.CalComponent.from_string(ical_component.as_ical_string());
            try {
                Component.Event? event = Component.Instance.convert(eds_component) as Component.Event;
                if (event != null)
                    notify_event_added(event);
            } catch (Error err) {
                debug("Unable to generate added event for %s: %s", to_string(), err.message);
            }
        }
    }
    
    private void on_objects_modified(SList<weak iCal.icalcomponent> objects) {
        foreach (weak iCal.icalcomponent ical_component in objects) {
            E.CalComponent eds_component = new E.CalComponent.from_string(ical_component.as_ical_string());
            
            unowned string uid_string;
            eds_component.get_uid(out uid_string);
            Component.UID uid = new Component.UID(uid_string);
            
            Component.Event? event = for_uid(uid) as Component.Event;
            if (event == null)
                continue;
            
            try {
                event.update(eds_component);
            } catch (Error err) {
                debug("Unable to update event %s: %s", event.to_string(), err.message);
            }
            
            notify_event_altered(event);
        }
    }
    
    private void on_objects_removed(SList<weak E.CalComponentId?> ids) {
        foreach (weak E.CalComponentId id in ids)
            notify_event_removed(new Component.UID(id.uid));
    }
}

}


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
            if (String.is_empty(ical_component.get_uid()))
                continue;
            
            Component.UID uid = new Component.UID(ical_component.get_uid());
            
            // remove all existing components with this UID
            if (has_uid(uid))
                notify_instance_removed(uid);
            
            // if no recurrences, add this alone
            if (!E.Util.component_has_recurrences(ical_component)) {
                add_instance(ical_component);
                
                continue;
            }
            
            // generate recurring instances
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
        add_instance(eds_component.get_icalcomponent());
        
        return true;
    }
    
    // Assumes all existing events with UID/RID have been removed already
    private void add_instance(iCal.icalcomponent ical_component) {
        // convert the added component into a new Event
        Component.Event? added_event;
        try {
            added_event = Component.Instance.convert(calendar, ical_component) as Component.Event;
            if (added_event != null)
                notify_instance_added(added_event);
        } catch (Error err) {
            debug("Unable to process added event: %s", err.message);
        }
    }
    
    private void on_objects_modified(SList<weak iCal.icalcomponent> objects) {
        SList<weak iCal.icalcomponent> add_list = new SList<weak iCal.icalcomponent>();
        foreach (weak iCal.icalcomponent ical_component in objects) {
            // if not an instance and has recurring, treat as an add (which removes and adds generated
            // instances)
            if (!E.Util.component_is_instance(ical_component) && E.Util.component_has_recurrences(ical_component)) {
                add_list.append(ical_component);
                
                continue;
            }
            
            if (String.is_empty(ical_component.get_uid()))
                continue;
            
            // if none present, skip
            Component.UID uid = new Component.UID(ical_component.get_uid());
            if (!has_uid(uid))
                continue;
            
            // find original for this one
            Gee.Collection<Component.Instance>? instances = for_uid(uid);
            if (instances == null || instances.size == 0)
                continue;
            
            foreach (Component.Instance instance in instances) {
                Component.Event? known_event = instance as Component.Event;
                if (known_event == null)
                    continue;
                
                try {
                    known_event.full_update(ical_component, null);
                } catch (Error err) {
                    debug("Unable to update event %s: %s", known_event.to_string(), err.message);
                    
                    continue;
                }
                
                notify_instance_altered(known_event);
            }
            
            if (instances.size > 1)
                debug("Warning: updated %d modified events, expecting only 1", instances.size);
        }
        
        // add any recurring events
        on_objects_added(add_list);
    }
    
    private void on_objects_removed(SList<weak E.CalComponentId?> ids) {
        foreach (weak E.CalComponentId id in ids)
            notify_instance_removed(new Component.UID(id.uid));
    }
}

}


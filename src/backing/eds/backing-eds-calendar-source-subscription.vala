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
    private delegate void InstanceNotifier(Component.Instance instance);
    
    private E.CalClientView view;
    private string sexp;
    // this is different than "active", which gets set when start completes
    private bool started = false;
    private Error? start_err = null;
    
    // Called from EdsCalendarSource.subscribe_async().  The CalClientView should not be started
    public EdsCalendarSourceSubscription(EdsCalendarSource eds_calendar, Calendar.ExactTimeSpan window,
        E.CalClientView view, string sexp) {
        base (eds_calendar, window);
        
        this.view = view;
        this.sexp = sexp;
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
        
        discovery_async.begin(cancellable);
    }
    
    private async void discovery_async(Cancellable? cancellable) {
        SList<unowned iCal.icalcomponent> ical_components;
        try {
            yield view.client.get_object_list(sexp, cancellable, out ical_components);
        } catch (Error err) {
            start_err = err;
            
            start_failed(err);
            
            return;
        }
        
        // process all known objects within the sexp range
        on_objects_discovered_added(ical_components, notify_instance_discovered);
        
        // only set when generation (start) is finished
        active = true;
    }
    
    private void on_objects_added(SList<unowned iCal.icalcomponent> ical_components) {
        // process all added objects
        on_objects_discovered_added(ical_components, notify_instance_added);
    }
    
    private void on_objects_discovered_added(SList<unowned iCal.icalcomponent> ical_components,
        InstanceNotifier notifier) {
        foreach (unowned iCal.icalcomponent ical_component in ical_components) {
            if (String.is_empty(ical_component.get_uid()))
                continue;
            
            Component.UID uid = new Component.UID(ical_component.get_uid());
            
            // remove all existing components with this UID
            if (has_uid(uid))
                notify_instance_removed(uid);
            
            // add all instances, master and generated
            Component.Instance? master = add_instance(null, ical_component, notifier);
            if (master == null)
                continue;
            
            // if no recurrences, done
            if (!E.Util.component_has_recurrences(ical_component))
                continue;
            
            // generate recurring instances
            view.client.generate_instances_for_object_sync(
                ical_component,
                window.start_exact_time.to_time_t(),
                window.end_exact_time.to_time_t(),
                (eds_component, start, end) => {
                    add_instance(master, eds_component.get_icalcomponent(), notifier);
                    
                    return true;
                }
            );
        }
    }
    
    // Assumes all existing events with UID/RID have been removed already
    private Component.Instance? add_instance(Component.Instance? master, iCal.icalcomponent ical_component,
        InstanceNotifier notifier) {
        // convert the added component into a new Event
        Component.Event? added_event = null;
        try {
            added_event = Component.Instance.convert(calendar, ical_component) as Component.Event;
            if (added_event != null) {
                // assign the master (if this isn't the master already)
                added_event.master = master;
                
                // notify of didscovery/addition
                notifier(added_event);
            }
        } catch (Error err) {
            debug("Unable to process added event: %s", err.message);
        }
        
        return added_event;
    }
    
    private void on_objects_modified(SList<unowned iCal.icalcomponent> ical_components) {
        SList<unowned iCal.icalcomponent> add_list = new SList<unowned iCal.icalcomponent>();
        foreach (unowned iCal.icalcomponent ical_component in ical_components) {
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
            
            Component.DateTime? rid = null;
            try {
                rid = new Component.DateTime(ical_component, iCal.icalproperty_kind.RECURRENCEID_PROPERTY);
            } catch (ComponentError comperr) {
                if (!(comperr is ComponentError.UNAVAILABLE)) {
                    debug("Unable to get RID of modified component: %s", comperr.message);
                    
                    continue;
                }
            }
            
            // get all instances known for this UID to find original to alter
            Gee.Collection<Component.Instance>? instances = for_uid(uid);
            
            // if no RID, then only one should be returned
            Component.Instance? instance = null;
            if (rid == null) {
                instance = traverse<Component.Instance>(instances).one();
                if (instance == null) {
                    debug("%d instances found for modified instance, expected 1", Collection.size(instances));
                    
                    continue;
                }
            } else {
                // if RID != null, then find the matching instance
                instance = traverse<Component.Instance>(instances)
                    .first_matching(inst => inst.rid != null && inst.rid.equal_to(rid));
                if (instance == null) {
                    debug("Cannot find instance with UID %s RID %s, skipping", uid.to_string(), rid.to_string());
                    
                    continue;
                }
            }
            
            Component.Event? modified_event = instance as Component.Event;
            if (modified_event == null)
                continue;
            
            try {
                modified_event.full_update(ical_component, null);
            } catch (Error err) {
                debug("Unable to update event %s: %s", modified_event.to_string(), err.message);
                
                continue;
            }
            
            notify_instance_altered(modified_event);
        }
        
        // remove and re-add any recurring events
        on_objects_added(add_list);
    }
    
    private void on_objects_removed(SList<unowned E.CalComponentId?> ids) {
        foreach (unowned E.CalComponentId id in ids)
            notify_instance_removed(new Component.UID(id.uid));
    }
}

}


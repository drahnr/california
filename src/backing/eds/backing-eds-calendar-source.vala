/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Backing {

/**
 * An interface to an EDS calendar source.
 */

internal class EdsCalendarSource : CalendarSource {
    private const int UPDATE_DELAY_MSEC = 500;
    
    private E.Source eds_source;
    private E.SourceCalendar eds_calendar;
    private E.CalClient? client = null;
    private Scheduled? scheduled_source_write = null;
    private Cancellable? source_write_cancellable = null;
    
    public EdsCalendarSource(E.Source eds_source, E.SourceCalendar eds_calendar) {
        base (eds_source.uid, eds_source.display_name);
        
        this.eds_source = eds_source;
        this.eds_calendar = eds_calendar;
        
        // read-only until opened, when state can be determined from client
        read_only = true;
        
        // use unidirectional bindings so source updates (writing) only occurs when changed from
        // within the app
        eds_source.bind_property("display-name", this, PROP_TITLE, BindingFlags.SYNC_CREATE);
        eds_calendar.bind_property("selected", this, PROP_VISIBLE, BindingFlags.SYNC_CREATE);
        eds_calendar.bind_property("color", this, PROP_COLOR, BindingFlags.SYNC_CREATE);
        
        // when changed within the app, need to write it back out
        notify[PROP_TITLE].connect(on_title_changed);
        notify[PROP_VISIBLE].connect(on_visible_changed);
        notify[PROP_COLOR].connect(on_color_changed);
    }
    
    ~EdsCalendarSource() {
        if (scheduled_source_write != null)
            scheduled_source_write.wait();
    }
    
    private void on_title_changed() {
        // on schedule write if something changed
        if (eds_source.display_name == title)
            return;
        
        eds_source.display_name = title;
        schedule_source_write("title=%s".printf(title));
    }
    
    private void on_visible_changed() {
        // only schedule source writes if something actually changed
        if (eds_calendar.selected == visible)
            return;
        
        eds_calendar.selected = visible;
        schedule_source_write("visible=%s".printf(visible.to_string()));
    }
    
    private void on_color_changed() {
        // only schedule writes if something changed
        if (eds_calendar.color == color)
            return;
        
        eds_calendar.color = color;
        schedule_source_write("color=%s".printf(color));
    }
    
    private void schedule_source_write(string reason) {
        debug("Scheduling update of %s due to %s...", to_string(), reason);
        
        // cancel an outstanding write
        if (source_write_cancellable != null)
            source_write_cancellable.cancel();
        source_write_cancellable = new Cancellable();
        
        scheduled_source_write = new Scheduled.once_after_msec(UPDATE_DELAY_MSEC,
            () => on_background_write_source_async.begin(), Priority.LOW);
    }
    
    private async void on_background_write_source_async() {
        Cancellable? cancellable = source_write_cancellable;
        source_write_cancellable = null;
        
        if (cancellable == null || cancellable.is_cancelled())
            return;
        
        try {
            debug("Updating EDS source %s...", to_string());
            yield eds_source.write(cancellable);
            debug("Updated EDS source %s", to_string());
        } catch (Error err) {
            debug("Error updating EDS source %s: %s", to_string(), err.message);
        }
    }
    
    // Invoked by EdsStore prior to making it available outside of unit
    internal async void open_async(Cancellable? cancellable) throws Error {
        client = (E.CalClient) yield E.CalClient.connect(eds_source, E.CalClientSourceType.EVENTS,
            cancellable);
        
        client.bind_property("readonly", this, PROP_READONLY, BindingFlags.SYNC_CREATE);
        client.notify["readonly"].connect(() => {
            debug("%s readonly: %s", to_string(), client.readonly.to_string());
        });
    }
    
    // Invoked by EdsStore when closing and dropping all its refs
    internal async void close_async(Cancellable? cancellable) throws Error {
        // no close -- just drop the ref
        client = null;
        read_only = true;
    }
    
    private void check_open() throws BackingError {
        if (client == null)
            throw new BackingError.UNAVAILABLE("%s has been removed", to_string());
    }
    
    public override async CalendarSourceSubscription subscribe_async(Calendar.ExactTimeSpan window,
        Cancellable? cancellable = null) throws Error {
        check_open();
        
        // construct s-expression describing the CalClientView's purview
        string sexp = "occur-in-time-range? (make-time \"%s\") (make-time \"%s\")".printf(
            E.isodate_from_time_t(window.start_exact_time.to_time_t()),
            E.isodate_from_time_t(window.end_exact_time.to_time_t()));
        
        E.CalClientView view;
        yield client.get_view(sexp, cancellable, out view);
        
        return new EdsCalendarSourceSubscription(this, window, view);
    }
    
    public override async Component.UID? create_component_async(Component.Instance instance,
        Cancellable? cancellable = null) throws Error {
        check_open();
        
        string? uid;
        yield client.create_object(instance.ical_component, cancellable, out uid);
        
        return !String.is_empty(uid) ? new Component.UID(uid) : null;
    }
    
    public override async void update_component_async(Component.Instance instance,
        Cancellable? cancellable = null) throws Error {
        check_open();
        
        yield client.modify_object(instance.ical_component, E.CalObjModType.THIS, cancellable);
    }
    
    public override async void remove_all_instances_async(Component.UID uid,
        Cancellable? cancellable = null) throws Error {
        check_open();
        
        yield client.remove_object(uid.value, null, E.CalObjModType.ALL, cancellable);
    }
    
    public override async void remove_instances_async(Component.UID uid, Component.DateTime rid,
        CalendarSource.AffectedInstances affected, Cancellable? cancellable = null) throws Error {
        check_open();
        
        // Note that E.CalObjModType.ONLY_THIS is *never* used ... examining EDS source code,
        // it appears in e-cal-backend-file.c that ONLY_THIS merely removes the instance but does not
        // include an EXDATE in the original iCal source ... I don't quite understand the benefit of
        // this, as this suggests (a) other calendar clients won't learn of the removal and (b) the
        // instance will be re-generated the next time the user runs an EDS calendar client.  In
        // either case, ONLY maps to our desired effect by adding an EXDATE to the iCal source.
        switch (affected) {
            case CalendarSource.AffectedInstances.THIS:
                yield client.remove_object(uid.value, rid.value, E.CalObjModType.THIS, cancellable);
            break;
            
            case CalendarSource.AffectedInstances.THIS_AND_FUTURE:
                yield remove_this_and_future_async(uid, rid, cancellable);
            break;
            
            case CalendarSource.AffectedInstances.ALL:
                yield remove_all_instances_async(uid, cancellable);
            break;
            
            default:
                assert_not_reached();
        }
    }
    
    private async void remove_this_and_future_async(Component.UID uid, Component.DateTime rid,
        Cancellable? cancellable) throws Error {
        // get the master instance ... remember that the Backing.CalendarSource only stores generated
        // instances
        iCal.icalcomponent ical_component;
        yield client.get_object(uid.value, null, cancellable, out ical_component);
        
        // change the RRULE's UNTIL indicating the end of the recurring set (which is, handily enough,
        // the RID)
        unowned iCal.icalproperty? rrule_property = ical_component.get_first_property(
            iCal.icalproperty_kind.RRULE_PROPERTY);
        if (rrule_property == null)
            return;
        
        iCal.icalrecurrencetype rrule = rrule_property.get_rrule();
        
        // In order to be inclusive, need to set UNTIL one tick earlier to ensure the supplied RID
        // is now excluded
        if (rid.is_date) {
            Component.date_to_ical(rid.to_date().previous(), &rrule.until);
        } else {
            Component.exact_time_to_ical(rid.to_exact_time().adjust_time(-1, Calendar.TimeUnit.SECOND),
                &rrule.until);
        }
        
        // COUNT and UNTIL are mutually exclusive in an RRULE ... COUNT can be reliably reset
        // because the RID enforces a new de facto COUNT (assuming the RID originated from the UID's
        // recurring instance; if not, the user has screwed up)
        rrule.count = 0;
        
        rrule_property.set_rrule(rrule);
        
        // write it out ... essentially, this style of remove is actually an update
        yield client.modify_object(ical_component, E.CalObjModType.THIS, cancellable);
    }
    
    public override async void import_icalendar_async(Component.iCalendar ical, Cancellable? cancellable = null)
        throws Error {
        check_open();
        
        yield client.receive_objects(ical.ical_component, cancellable);
    }
}

}


/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Component {

/**
 * A mutable iCalendar component that has a definitive instance within a calendar.
 *
 * By "instance", this means {@link Event}s, To-do's, and Journal components.  In other words,
 * components which allocate a specific amount of time within a calendar.  (Free/Busy does allow
 * for time to be published/reserved, but this implementation doesn't deal with that component.)
 *
 * Mutability is achieved two separate ways.  One is to call {@link full_update} supplying a new
 * iCal component to update an existing one (verified by UID).  This will update all fields.
 *
 * The second is to update the mutable properties themselves, which will then update the underlying
 * iCal component.
 *
 * Instances produced by {@link Backing.CalendarSourceSubscription}s will be updated by the
 * subscription if the Instance is updated or removed locally or remotely.  Cloned Instances,
 * however, are not automatically updated.  See {@link clone}.
 *
 * Alarms will be contained within Instance components.  Timezones are handled separately.
 *
 * Instance also offers a number of methods to convert iCal structures into internal objects.
 */

public abstract class Instance : BaseObject, Gee.Hashable<Instance> {
    public const string PROP_CALENDAR_SOURCE = "calendar-source";
    public const string PROP_DTSTAMP = "dtstamp";
    public const string PROP_UID = "uid";
    public const string PROP_ICAL_COMPONENT = "ical-component";
    public const string PROP_RRULE = "rrule";
    public const string PROP_RID = "rid";
    public const string PROP_EXDATES = "exdates";
    public const string PROP_RDATES = "rdates";
    public const string PROP_SEQUENCE = "sequence";
    public const string PROP_MASTER = "master";
    
    protected const string PROP_IN_FULL_UPDATE = "in-full-update";
    
    /**
     * The {@link Backing.CalendarSource} this {@link Instance} originated from.
     *
     * This will initialize as null if created as a {@link blank} Instance.
     */
    public Backing.CalendarSource? calendar_source { get; set; default = null; }
    
    /**
     * The date-time stamp of the {@link Instance}.
     *
     * Any update to the Instance will result in this being updated as well.  It cannot be set
     * manually.
     *
     * See [[https://tools.ietf.org/html/rfc5545#section-3.8.7.2]]
     *
     * @see notify_altered
     */
    public Calendar.ExactTime? dtstamp { get; private set; default = null; }
    
    /**
     * The {@link UID} of the {@link Instance}.
     *
     * This element is immutable, as it represents the identify of this Instance.
     */
    public UID uid { get; private set; }
    
    /**
     * {@link RecurrenceRule} (RRULE) for {@link Instance}.
     *
     * If the RecurrenceRule is itself altered, that signal is reflected to {@link altered}.
     *
     * @see make_recurring
     */
    public RecurrenceRule? rrule { get; private set; default = null; }
    
    /**
     * The RECURRENCE-ID of a recurring component.
     *
     * See [[https://tools.ietf.org/html/rfc5545#section-3.8.4.4]]
     */
    public Component.DateTime? rid { get; set; default = null; }
    
    /**
     * All EXDATEs (DATE-TIME exceptions for recurring instances) in the {@link Instance}.
     *
     * Returns a read-only set of {@link DateTime}s.  Use {@link set_exdates} to change.
     *
     * See [[https://tools.ietf.org/html/rfc5545#section-3.8.5.1]]
     */
    private Gee.SortedSet<DateTime>? _exdates = null;
    public Gee.SortedSet<DateTime>? exdates {
        owned get {
            return Collection.is_empty(_exdates) ? null : _exdates.read_only_view;
        }
        
        set {
            _exdates = value;
        }
    }
    
    /**
     * All RDATEs (DATE-TIMEs manually set for recurring instances) in the {@link Instance}.
     *
     * See [[https://tools.ietf.org/html/rfc5545#section-3.8.5.2]]
     */
    private Gee.SortedSet<DateTime>? _rdates = null;
    public Gee.SortedSet<DateTime>? rdates {
        owned get {
            return Collection.is_empty(_rdates) ? null : _rdates.read_only_view;
        }
        
        set {
            _rdates = value;
        }
    }
    
    /**
     * Returns true if the {@link Instance} is a master instance.
     *
     * A master instance is one that has not been generated from another Instance's recurring
     * rule (RRULE).  In practice, this means the Instance does not have a RECURRENCE-ID.
     *
     * @see rid
     * @see rrule
     */
    public bool is_master_instance { get { return rid == null; } }
    
    /**
     * Returns true if the {@link Instance} is a generated recurring instance.
     *
     * A generated recurring instance is one that has been artificially constructed from another
     * Instance's recurring rule (RRULE).  In practice, this means the Instance has a
     * RECURRENCE-ID.
     *
     * @see rid
     * @see Backing.CalendarSource.fetch_master_component_async
     */
    public bool is_generated_instance { get { return rid != null; } }
    
    /**
     * Returns true if the master {@link Instance} can generate recurring instances.
     *
     * This indicates the Instance is a master Instance and can generate recurring instances from
     * its RRULE.  In practice, this means the Instance has no RECURRENCE-ID but does have an
     * RRULE.  (Generated instances will have the RRULE that construct them as well as a
     * RECURRENCE-ID.)
     *
     * @see rid
     * @see Backing.CalendarSource.fetch_master_component_async
     */
    public bool can_generate_instances { get { return rid == null && rrule != null; } }
    
    /**
     * If a generated {@link Instance}, holds a reference to the master Instance that generated it.
     *
     * The {@link Backing} should do everything it can to provide a master Instance for all
     * generated Instances.  However, if this is null it is not a guarantee this is a master
     * Instance.  Use {@link is_master_instance}.
     */
    public Instance? master { get; internal set; default = null; }
    
    /**
     * The SEQUENCE of a VEVENT, VTODO, or VJOURNAL.
     *
     * See [[https://tools.ietf.org/html/rfc5545#section-3.8.7.4]]
     */
    public int sequence { get; set; default = 0; }
    
    /**
     * The iCal component being represented by this {@link Instance}.
     */
    private iCal.icalcomponent _ical_component;
    public iCal.icalcomponent ical_component { get { return _ical_component; } }
    
    /**
     * Returns the iCal source for this {@link Instance}.
     */
    public string source { get { return ical_component.as_ical_string(); } }
    
    /**
     * True if inside {@link full_update}.
     *
     * Subclasses want to ignore updates to various properties (their own and {@link Instance}'s)
     * if this is true.
     */
    protected bool in_full_update { get; private set; default = false; }
    
    /**
     * Fired when an {@link Instance} is altered in any way.
     *
     * Although "notify" is probably good enough for most situations (and tells the subscriber
     * which property changed), there's no guarantee that all fields in subclasses of Instance
     * will be stored in properties, so this is the final word on knowing when an Instance has
     * been altered.
     *
     * Subclasses should use {@link notify_altered} rather than firing this signal directly.
     */
    public signal void altered(bool from_full_update);
    
    /**
     * An {@link Instance} representing an iCal component.
     *
     * This contructor will call {@link full_update}, which gives the subclass a single code path
     *for updating its properties and internal state.  Anything which should not be updated by an
     * external invocation of full_update() (such as immutable data) should update that state after
     * the base constructor returns.
     */
    protected Instance(Backing.CalendarSource? calendar_source, iCal.icalcomponent ical_component,
        iCal.icalcomponent_kind kind) throws Error {
        if (ical_component.isa() != kind) {
            throw new ComponentError.MISMATCH("Cannot create VTYPE %s from component of VTYPE %s",
                kind.to_string(), ical_component.isa().to_string());
        }
        
        this.calendar_source = calendar_source;
        // although base update() sets this, set it here in case it's referred to by the subclasses
        // as the "old" component during it's update()
        _ical_component = ical_component.clone();
        
        // this needs to be stored before calling update() or the equality check there will fail
        string? ical_uid = _ical_component.get_uid();
        uid = !String.is_empty(ical_uid) ? new UID(ical_uid) : UID.generate();
        
        full_update(_ical_component, uid);
        
        // watch for property changes and update ical_component when happens
        notify.connect(on_notify);
    }
    
    /**
     * Creates a blank {@link Instance} for a new iCal component with a generated {@link uid}.
     *
     * Unlike the primary constructor, this will not call {@link full_update}.
     */
    protected Instance.blank(iCal.icalcomponent_kind kind) {
        _ical_component = new iCal.icalcomponent(kind);
        uid = Component.UID.generate();
        _ical_component.set_uid(uid.value);
        
        notify.connect(on_notify);
    }
    
    /**
     * Fires the {@link altered} signal, allowing for subclasses to update internal state before
     * or after the trigger.
     */
    protected virtual void notify_altered(bool from_full_update) {
        altered(from_full_update);
        
        // only update dtstamp if not altered by a full update (as dtstamp is updated there)
        if (from_full_update)
            return;
        
        dtstamp = Calendar.System.now;
        
        iCal.icaltimetype ical_dtstamp = {};
        exact_time_to_ical(dtstamp, &ical_dtstamp);
        ical_component.set_dtstamp(ical_dtstamp);
    }
    
    /**
     * Updates the {@link Instance} with information from the iCal component.
     *
     * The Instance will update whatever changes it discovers from this new component and fire
     * signals to update subscribers.
     *
     * This is also called by the Instance base class constructor to give subclasses a single
     * code path for updating their state.
     *
     * The {@link UID} may be supplied if the iCal component does not have one.
     *
     * @throws BackingError if eds_component is not for this Instance.
     */
    public void full_update(iCal.icalcomponent ical_component, UID? supplied_uid) throws Error {
        in_full_update = true;
        
        bool notify = false;
        try {
            update_from_component(ical_component, supplied_uid);
            notify = true;
        } finally {
            in_full_update = false;
            
            // notify when !in_full_update
            if (notify)
                notify_altered(true);
        }
    }
    
    /**
     * The "real" update method that should be overridden by subclasses to update their fields.
     *
     * It's highly recommended the subclass call the base class update_from_component() first to
     * allow it to do basic sanity checking before proceeding to update its own state.
     *
     * If supplied_uid is non-null, it should be used in preference over the UID in the iCal
     * component.  In either case, at least one method should return a valid UID.
     *
     * @see full_update
     */
    protected virtual void update_from_component(iCal.icalcomponent ical_component, UID? supplied_uid)
        throws Error {
        if (supplied_uid == null)
            assert(!String.is_empty(ical_component.get_uid()));
        
        // use the supplied UID before using the one in the iCal component (for dealing with
        // malformed iCal w/ no UID ... I'm looking at you, EventBrite)
        Component.UID other_uid = supplied_uid ?? new Component.UID(ical_component.get_uid());
        if (!uid.equal_to(other_uid)) {
            throw new BackingError.MISMATCH("Attempt to update component %s with component %s",
                this.uid.to_string(), other_uid.to_string());
        }
        
        try {
            DateTime dt_stamp = new DateTime(ical_component, iCal.icalproperty_kind.DTSTAMP_PROPERTY);
            if (!dt_stamp.is_date)
                dtstamp = dt_stamp.to_exact_time();
        } catch (ComponentError comperr) {
            // if unavailable, generate a DTSTAMP ... like UID, this is for malformed iCal with
            // no DTSTAMP, i.e. EventBrite
            if (!(comperr is ComponentError.UNAVAILABLE))
                throw comperr;
            
            dtstamp = Calendar.System.now;
        }
        
        try {
            rid = new DateTime(ical_component, iCal.icalproperty_kind.RECURRENCEID_PROPERTY);
        } catch (ComponentError comperr) {
            // ignore if unavailable
            if (!(comperr is ComponentError.UNAVAILABLE))
                throw comperr;
            
            rid = null;
        }
        
        sequence = ical_component.get_sequence();
        
        try {
            make_recurring(new RecurrenceRule.from_ical(ical_component, false));
        } catch (ComponentError comperr) {
            // ignored; generally means no RRULE in component
            if (!(comperr is ComponentError.UNAVAILABLE))
                debug("Unable to parse RRULE for %s: %s", to_string(), comperr.message);
        }
        
        exdates = get_multiple_date_times(iCal.icalproperty_kind.EXDATE_PROPERTY);
        rdates = get_multiple_date_times(iCal.icalproperty_kind.RDATE_PROPERTY);
        
        // save own copy of component; no ownership transferrance w/ current bindings
        if (_ical_component != ical_component)
            _ical_component = ical_component.clone();
    }
    
    private void on_notify(ParamSpec pspec) {
        // don't worry if in full update, that call is supposed to update properties
        if (in_full_update)
            return;
        
        bool altered = true;
        switch (pspec.name) {
            case PROP_RID:
                remove_all_properties(iCal.icalproperty_kind.RECURRENCEID_PROPERTY);
                if (rid != null)
                    ical_component.set_recurrenceid(rid.dt);
            break;
            
            case PROP_SEQUENCE:
                remove_all_properties(iCal.icalproperty_kind.SEQUENCE_PROPERTY);
                ical_component.set_sequence(sequence);
            break;
            
            case PROP_RRULE:
                // always remove existing RRULE
                remove_all_properties(iCal.icalproperty_kind.RRULE_PROPERTY);
                
                // add new one, if added
                if (rrule != null)
                    rrule.add_to_ical(ical_component);
            break;
            
            case PROP_EXDATES:
                if (Collection.is_empty(exdates))
                    remove_all_properties(iCal.icalproperty_kind.EXDATE_PROPERTY);
                else
                    set_multiple_date_times(iCal.icalproperty_kind.EXDATE_PROPERTY, exdates);
            break;
            
            case PROP_RDATES:
                if (Collection.is_empty(rdates))
                    remove_all_properties(iCal.icalproperty_kind.RDATE_PROPERTY);
                else
                    set_multiple_date_times(iCal.icalproperty_kind.RDATE_PROPERTY, rdates);
            break;
            
            default:
                altered = false;
            break;
        }
        
        if (altered)
            notify_altered(false);
    }
    
    /**
     * Make a detached copy of the {@link Instance}.
     *
     * This produces an exact copy of the Instance at the time of the call.  Unlike Instances
     * produced by {@link Backing.CalendarSourceSubscription}s, cloned Instances are not
     * automatically updated as local and/or remote changes are made.  This makes them good for
     * editing (where a number of changes are made and stored in the Instance, only being submitted
     * when the user gives the okay).
     *
     * Cloning will also clone the {@link master}, if present.
     */
    public abstract Component.Instance clone() throws Error;
    
    /**
     * Add a {@link RecurrenceRule} to the {@link Instance}.
     *
     * Pass null to make the Instance non-recurring.
     */
    public void make_recurring(RecurrenceRule? rrule) {
        if (this.rrule != null) {
            this.rrule.notify.disconnect(on_rrule_updated);
            this.rrule.by_rule_updated.disconnect(on_rrule_updated);
        }
        
        if (rrule != null) {
            rrule.notify.connect(on_rrule_updated);
            rrule.by_rule_updated.connect(on_rrule_updated);
        }
        
        this.rrule = rrule;
    }
    
    private void on_rrule_updated() {
        // remove old property, replace with new one
        remove_all_properties(iCal.icalproperty_kind.RRULE_PROPERTY);
        rrule.add_to_ical(ical_component);
        
        // count this as an alteration
        notify_altered(false);
    }
    
    /**
     * Returns an appropriate {@link Component} instance for the iCalendar component.
     *
     * VCALENDARs should use {@link Component.iCalendar}.
     *
     * @returns null if the component is not represented in this namespace (yet).
     */
    public static Component.Instance? convert(Backing.CalendarSource? calendar_source,
        iCal.icalcomponent ical_component) throws Error {
        switch (ical_component.isa()) {
            case iCal.icalcomponent_kind.VEVENT_COMPONENT:
                return new Event(calendar_source, ical_component);
            
            default:
                debug("Unable to construct component %s: unimplemented",
                    ical_component.isa().to_string());
                
                return null;
        }
    }
    
    /**
     * Convenience method to convert a collection of DATE/DATE-TIME properties into a SortedSet of
     * {@link DateTime}s.
     *
     * @see set_multiple_date_times
     */
    protected Gee.SortedSet<DateTime>? get_multiple_date_times(iCal.icalproperty_kind kind) {
        Gee.SortedSet<DateTime> date_times = new Gee.TreeSet<DateTime>();
        
        unowned iCal.icalproperty? prop = ical_component.get_first_property(kind);
        while (prop != null) {
            try {
                date_times.add(new DateTime.from_property(prop));
            } catch (ComponentError comperr) {
                debug("Unable to parse DATE/DATE-TIME for %s: %s", kind.to_string(), comperr.message);
            }
            
            prop = ical_component.get_next_property(kind);
        }
        
        return date_times.size > 0 ? date_times : null;
    }
    
    /**
     * Convenience method to set (replace) a collection of DATE/DATE-TIME properties from a
     * Collection of {@link DateTime}s.
     *
     * @see get_multiple_date_times
     */
    protected void set_multiple_date_times(iCal.icalproperty_kind kind, Gee.Collection<DateTime> date_times) {
        remove_all_properties(kind);
        
        foreach (DateTime date_time in date_times) {
            iCal.icalproperty prop = new iCal.icalproperty(kind);
            prop.set_value(date_time.to_ical_value());
            
            ical_component.add_property(prop);
        }
    }
    
    /**
     * Convenience method to convert a {@link Calendar.DateSpan} to a pair of iCal DATEs.
     *
     * dtend_inclusive indicates whether the dt_end should be treated as inclusive or exclusive
     * of the span.  See the iCal specification for information on how each component should
     * treat the situation.
     */
    protected static void date_span_to_ical(Calendar.DateSpan date_span, bool dtend_inclusive,
        iCal.icaltimetype *ical_dtstart, iCal.icaltimetype *ical_dtend) {
        date_to_ical(date_span.start_date, ical_dtstart);
        date_to_ical(date_span.end_date.adjust_by(dtend_inclusive ? 0 : 1, Calendar.DateUnit.DAY),
            ical_dtend);
    }
    
    /**
     * Convenience method to convert a {@link Calendar.ExactTimeSpan} to a pair of iCal DATE-TIMEs.
     */
    protected static void exact_time_span_to_ical(Calendar.ExactTimeSpan exact_time_span,
        iCal.icaltimetype *ical_dtstart, iCal.icaltimetype *ical_dtend) {
        exact_time_to_ical(exact_time_span.start_exact_time, ical_dtstart);
        exact_time_to_ical(exact_time_span.end_exact_time, ical_dtend);
    }
    
    /**
     * Convenience method to remove all instances of a property from {@link ical_component}.
     *
     * @returns The number of properties found with the specified kind.
     */
    protected int remove_all_properties(iCal.icalproperty_kind kind) {
        int count = 0;
        unowned iCal.icalproperty? prop;
        while ((prop = ical_component.get_first_property(kind)) != null) {
            ical_component.remove_property(prop);
            count++;
        }
        
        return count;
    }
    
    /**
     * Returns true if all the fields necessary for creating/updating the {@link Instance} are
     * present with proper values.
     *
     * The presence of {@link calendar_source} is not necessary to deem an Instance valid.
     *
     * and_useful indicates that, while technically valid according to the iCalendar specification,
     * the Instance also has optional fields available that the user will almost likely need or
     * require for the event to be of use.
     */
    public virtual bool is_valid(bool and_useful) {
        return dtstamp != null;
    }
    
    /**
     * Equality is defined as {@link Component.Instance}s having the same {@link uid}, {@link rid},
     * and {@link sequence}.
     *
     * Subclasses should override this and {@link hash} if more definite equality is necessary.
     */
    public virtual bool equal_to(Instance other) {
        if (this == other)
            return true;
        
        if (is_generated_instance != other.is_generated_instance)
            return false;
        
        if (is_generated_instance && !rid.equal_to(other.rid))
            return false;
        
        if (sequence != other.sequence)
            return false;
        
        return uid.equal_to(other.uid);
    }
    
    /**
     * Hash is calculated using the {@link Instance} {@link UID}, {@link rid}, and {@link sequence}.
     *
     * Subclasses should override if they override {@link equal_to}.
     */
    public virtual uint hash() {
        return uid.hash() ^ ((rid != null) ? rid.hash() : 0) ^ sequence;
    }
}

}


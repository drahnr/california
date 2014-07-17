/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Host {

[GtkTemplate (ui = "/org/yorba/california/rc/create-update-recurring.ui")]
public class CreateUpdateRecurring : Gtk.Grid, Toolkit.Card {
    public const string ID = "CreateUpdateRecurring";
    
    private const string PROP_START_DATE = "start-date";
    private const string PROP_END_DATE = "end-date";
    
    // DO NOT CHANGE VALUES UNLESS YOU KNOW WHAT YOU'RE DOING.  These values are mirrored in the
    // Glade file's repeats_combobox model.
    private enum Repeats {
        DAILY = 0,
        WEEKLY = 1,
        DAY_OF_THE_WEEK = 2,
        DAY_OF_THE_MONTH = 3,
        YEARLY = 4
    }
    
    public string card_id { get { return ID; } }
    
    public string? title { get { return null; } }
    
    public Gtk.Widget? default_widget { get { return ok_button; } }
    
    public Gtk.Widget? initial_focus { get { return make_recurring_checkbutton; } }
    
    public Calendar.Date? start_date { get; private set; default = null; }
    public Calendar.Date? end_date { get; private set; default = null; }
    
    [GtkChild]
    private Gtk.CheckButton make_recurring_checkbutton;
    
    [GtkChild]
    private Gtk.Grid child_grid;
    
    [GtkChild]
    private Gtk.ComboBoxText repeats_combobox;
    
    [GtkChild]
    private Gtk.Entry every_entry;
    
    [GtkChild]
    private Gtk.Label every_label;
    
    [GtkChild]
    private Gtk.Label on_days_label;
    
    [GtkChild]
    private Gtk.Box on_days_box;
    
    [GtkChild]
    private Gtk.CheckButton sunday_checkbutton;
    
    [GtkChild]
    private Gtk.CheckButton monday_checkbutton;
    
    [GtkChild]
    private Gtk.CheckButton tuesday_checkbutton;
    
    [GtkChild]
    private Gtk.CheckButton wednesday_checkbutton;
    
    [GtkChild]
    private Gtk.CheckButton thursday_checkbutton;
    
    [GtkChild]
    private Gtk.CheckButton friday_checkbutton;
    
    [GtkChild]
    private Gtk.CheckButton saturday_checkbutton;
    
    [GtkChild]
    private Gtk.Button start_date_button;
    
    [GtkChild]
    private Gtk.RadioButton never_radiobutton;
    
    [GtkChild]
    private Gtk.RadioButton after_radiobutton;
    
    [GtkChild]
    private Gtk.Entry after_entry;
    
    [GtkChild]
    private Gtk.Label after_label;
    
    [GtkChild]
    private Gtk.RadioButton ends_on_radiobutton;
    
    [GtkChild]
    private Gtk.Label warning_label;
    
    [GtkChild]
    private Gtk.Button end_date_button;
    
    [GtkChild]
    private Gtk.Button ok_button;
    
    private new Component.Event? event = null;
    private Component.Event? master = null;
    private Gee.HashMap<Calendar.DayOfWeek, Gtk.CheckButton> on_day_checkbuttons = new Gee.HashMap<
        Calendar.DayOfWeek, Gtk.CheckButton>();
    private bool blocking_insert_text_numbers_only_signal = false;
    
    public CreateUpdateRecurring() {
        // "Repeating event" checkbox activates almost every other control in this dialog
        make_recurring_checkbutton.bind_property("active", child_grid, "sensitive",
            BindingFlags.SYNC_CREATE);
        
        // On Days and its checkbox are only visible when Repeats is set to Weekly
        repeats_combobox.bind_property("active", on_days_label, "visible",
            BindingFlags.SYNC_CREATE, transform_repeats_active_to_on_days_visible);
        repeats_combobox.bind_property("active", on_days_box, "visible",
            BindingFlags.SYNC_CREATE, transform_repeats_active_to_on_days_visible);
        
        // Ends radio buttons need to make their assoc. controls sensitive when active
        after_radiobutton.bind_property("active", after_entry, "sensitive",
            BindingFlags.SYNC_CREATE);
        ends_on_radiobutton.bind_property("active", end_date_button, "sensitive",
            BindingFlags.SYNC_CREATE);
        
        // use private Date properties to synchronize with date button labels
        bind_property(PROP_START_DATE, start_date_button, "label", BindingFlags.SYNC_CREATE,
            transform_date_to_string);
        bind_property(PROP_END_DATE, end_date_button, "label", BindingFlags.SYNC_CREATE,
            transform_date_to_string);
        
        // map on-day checkboxes to days of week
        on_day_checkbuttons[Calendar.DayOfWeek.SUN] = sunday_checkbutton;
        on_day_checkbuttons[Calendar.DayOfWeek.MON] = monday_checkbutton;
        on_day_checkbuttons[Calendar.DayOfWeek.TUE] = tuesday_checkbutton;
        on_day_checkbuttons[Calendar.DayOfWeek.WED] = wednesday_checkbutton;
        on_day_checkbuttons[Calendar.DayOfWeek.THU] = thursday_checkbutton;
        on_day_checkbuttons[Calendar.DayOfWeek.FRI] = friday_checkbutton;
        on_day_checkbuttons[Calendar.DayOfWeek.SAT] = saturday_checkbutton;
        
        // Ok button's sensitivity is tied to a whole-lotta controls here
        make_recurring_checkbutton.bind_property("active", ok_button, "sensitive",
            BindingFlags.SYNC_CREATE, transform_to_ok_button_sensitive);
        every_entry.bind_property("text", ok_button, "sensitive",
            BindingFlags.SYNC_CREATE, transform_to_ok_button_sensitive);
        repeats_combobox.bind_property("active", ok_button, "sensitive",
            BindingFlags.SYNC_CREATE, transform_to_ok_button_sensitive);
        foreach (Gtk.CheckButton checkbutton in on_day_checkbuttons.values) {
            checkbutton.bind_property("active", ok_button, "sensitive",
                BindingFlags.SYNC_CREATE, transform_to_ok_button_sensitive);
        }
        bind_property(PROP_START_DATE, ok_button, "sensitive",
            BindingFlags.SYNC_CREATE, transform_to_ok_button_sensitive);
        ends_on_radiobutton.bind_property("active", ok_button, "sensitive",
            BindingFlags.SYNC_CREATE, transform_to_ok_button_sensitive);
        bind_property(PROP_END_DATE, ok_button, "sensitive",
            BindingFlags.SYNC_CREATE, transform_to_ok_button_sensitive);
        after_radiobutton.bind_property("active", ok_button, "sensitive",
            BindingFlags.SYNC_CREATE, transform_to_ok_button_sensitive);
        after_entry.bind_property("text", ok_button, "sensitive",
            BindingFlags.SYNC_CREATE, transform_to_ok_button_sensitive);
    }
    
    private bool transform_repeats_active_to_on_days_visible(Binding binding, Value source_value,
        ref Value target_value) {
        target_value = (repeats_combobox.active == Repeats.WEEKLY);
        
        return true;
    }
    
    private bool transform_date_to_string(Binding binding, Value source_value, ref Value target_value) {
        Calendar.Date? date = (Calendar.Date?) source_value;
        target_value = (date != null) ? date.to_standard_string() : "";
        
        return true;
    }
    
    private bool transform_to_ok_button_sensitive(Binding binding, Value source_value, ref Value target_value) {
        target_value = is_ok_ready();
        
        return true;
    }
    
    // if controls are added or removed here, that needs to be reflected in the ctor by binding/
    // unbinding to its properties
    private bool is_ok_ready() {
        // if not recurring, ok
        if (!make_recurring_checkbutton.active)
            return true;
        
        // every entry must be positive value
        if (String.is_empty(every_entry.text) || int.parse(every_entry.text) <= 0)
            return false;
        
        // if weekly, at least one checkbox must be active
        if (repeats_combobox.active == Repeats.WEEKLY) {
            if (!traverse<Gtk.CheckButton>(on_day_checkbuttons.values).any(checkbutton => checkbutton.active))
                return false;
        }
        
        // need a start date
        if (start_date == null)
            return false;
        
        // end date required if specified
        if (ends_on_radiobutton.active && end_date == null)
            return false;
        
        // count required if specified
        if (after_radiobutton.active) {
            if (String.is_empty(after_entry.text) || int.parse(after_entry.text) <= 0)
                return false;
        }
        
        return true;
    }
    
    public void jumped_to(Toolkit.Card? from, Toolkit.Card.Jump reason, Value? message) {
        assert(message != null);
        
        event = (Component.Event) message;
        master = event.is_master_instance ? event : (Component.Event) event.master;
        
        update_controls();
    }
    
    private void update_controls() {
        make_recurring_checkbutton.active = (master.rrule != null);
        
        // some defaults that may not be set even if an RRULE is present
        
        // "Ends ... After" entry
        after_entry.text = "1";
        
        // "Starts" and "Ends...On" entries
        Calendar.DateSpan event_span = master.get_event_date_span(Calendar.Timezone.local);
        start_date = event_span.start_date;
        end_date = event_span.end_date;
        
        // Clear all "On days" checkboxes for sanity's sake
        foreach (Gtk.CheckButton checkbutton in on_day_checkbuttons.values)
            checkbutton.active = false;
        
        // set remaining defaults if not a recurring event
        if (master.rrule == null) {
            repeats_combobox.active = Repeats.DAILY;
            every_entry.text = "1";
            never_radiobutton.active = true;
            warning_label.visible = false;
            
            return;
        }
        
        // "Repeats" combobox
        switch (master.rrule.freq) {
            case iCal.icalrecurrencetype_frequency.WEEKLY_RECURRENCE:
                repeats_combobox.active = Repeats.WEEKLY;
            break;
            
            case iCal.icalrecurrencetype_frequency.MONTHLY_RECURRENCE:
                bool by_day = master.rrule.get_by_rule(Component.RecurrenceRule.ByRule.DAY).size > 0;
                bool by_monthday = master.rrule.get_by_rule(Component.RecurrenceRule.ByRule.MONTH_DAY).size > 0;
                
                // fall back on month day of the week
                if (!by_day && by_monthday)
                    repeats_combobox.active = Repeats.DAY_OF_THE_MONTH;
                else
                    repeats_combobox.active = Repeats.DAY_OF_THE_WEEK;
            break;
            
            case iCal.icalrecurrencetype_frequency.YEARLY_RECURRENCE:
                repeats_combobox.active = Repeats.YEARLY;
            break;
            
            // Fall back on Daily for default, warning label is shown if anything not supported
            case iCal.icalrecurrencetype_frequency.DAILY_RECURRENCE:
            default:
                repeats_combobox.active = Repeats.DAILY;
            break;
        }
        
        // "Every" entry
        every_entry.text = master.rrule.interval.to_string();
        
        // "On days" week day checkboxes are only visible if a WEEKLY event
        if (master.rrule.is_weekly) {
            Gee.Map<Calendar.DayOfWeek?, int> by_days =
                Component.RecurrenceRule.decode_days(master.rrule.get_by_rule(Component.RecurrenceRule.ByRule.DAY));
            
            // the presence of a "null" day means every or all days
            if (by_days.has_key(null)) {
                foreach (Gtk.CheckButton checkbutton in on_day_checkbuttons.values)
                    checkbutton.active = true;
            } else {
                foreach (Calendar.DayOfWeek dow in by_days.keys)
                    on_day_checkbuttons[dow].active = true;
            }
        }
        
        // "Ends" choices
        if (!master.rrule.has_duration) {
            never_radiobutton.active = true;
        } else if (master.rrule.count > 0) {
            after_radiobutton.active = true;
            after_entry.text = master.rrule.count.to_string();
        } else {
            assert(master.rrule.until_date != null || master.rrule.until_exact_time != null);
            
            ends_on_radiobutton.active = true;
            end_date = master.rrule.get_recurrence_end_date();
        }
        
        // look for RRULEs that our editor cannot deal with
        string? supported = is_supported_rrule();
        if (supported != null)
            debug("Unsupported RRULE: %s", supported);
        
        warning_label.visible = supported != null;
    }
    
    // Returns a logging string for why not reported, null if supported
    private string? is_supported_rrule() {
        // only some frequencies support, and in some of those, certain requirements
        switch (master.rrule.freq) {
            case iCal.icalrecurrencetype_frequency.DAILY_RECURRENCE:
            case iCal.icalrecurrencetype_frequency.YEARLY_RECURRENCE:
                // do nothing, continue
            break;
            
            case iCal.icalrecurrencetype_frequency.WEEKLY_RECURRENCE:
                // can only hold BYDAY rules and all BYDAY rules must be zero
                Gee.Set<Component.RecurrenceRule.ByRule> active = master.rrule.get_active_by_rules();
                if (!active.contains(Component.RecurrenceRule.ByRule.DAY))
                    return "weekly-not-byday";
                
                if (active.size > 1)
                    return "weekly-multiple-byrules";
                
                foreach (int day in master.rrule.get_by_rule(Component.RecurrenceRule.ByRule.DAY)) {
                    int position;
                    if (!Component.RecurrenceRule.decode_day(day, null, out position))
                        return "weekly-undecodeable-byday";
                    
                    if (position != 0)
                        return "weekly-nonzero-byday-position";
                }
            break;
            
            // Must be a "simple" monthly recurrence
            case iCal.icalrecurrencetype_frequency.MONTHLY_RECURRENCE:
                bool by_day = master.rrule.get_by_rule(Component.RecurrenceRule.ByRule.DAY).size > 0;
                bool by_monthday = master.rrule.get_by_rule(Component.RecurrenceRule.ByRule.MONTH_DAY).size > 0;
                
                // can support one and only one
                if (by_day == by_monthday)
                    return "monthly-byday-and-bymonthday";
                
                if (master.rrule.get_active_by_rules().size > 1)
                    return "monthly-multiple-byrules";
            break;
            
            default:
                return "unsupported-frequency";
        }
        
        // do not support editing w/ EXDATEs
        if (!Collection.is_empty(master.exdates))
            return "exdates";
        
        // do not support editing w/ RDATEs
        if (!Collection.is_empty(master.rdates))
            return "rdates";
        
        return null;
    }
    
    [GtkCallback]
    private void on_repeats_combobox_changed() {
        on_repeats_combobox_or_every_entry_changed();
    }
    
    [GtkCallback]
    private void on_every_entry_changed() {
        on_repeats_combobox_or_every_entry_changed();
    }
    
    private void on_repeats_combobox_or_every_entry_changed() {
        int every_count = !String.is_empty(every_entry.text) ? int.parse(every_entry.text) : 1;
        every_count = every_count.clamp(1, int.MAX);
        
        unowned string text;
        switch (repeats_combobox.active) {
            case Repeats.DAY_OF_THE_MONTH:
            case Repeats.DAY_OF_THE_WEEK:
                text = ngettext("month", "months", every_count);
            break;
            
            case Repeats.WEEKLY:
                text = ngettext("week", "weeks", every_count);
            break;
            
            case Repeats.YEARLY:
                text = ngettext("year", "years", every_count);
            break;
            
            case Repeats.DAILY:
            default:
                text = ngettext("day", "days", every_count);
            break;
        }
        
        every_label.label = text;
    }
    
    [GtkCallback]
    private void on_after_entry_changed() {
        int after_count = !String.is_empty(after_entry.text) ? int.parse(after_entry.text) : 1;
        after_count = after_count.clamp(1, int.MAX);
        
        after_label.label = ngettext("event", "events", after_count);
    }
    
    [GtkCallback]
    private void on_date_button_clicked(Gtk.Button date_button) {
        bool is_dtstart = (date_button == start_date_button);
        
        Toolkit.CalendarPopup popup = new Toolkit.CalendarPopup(date_button,
            is_dtstart ? start_date : end_date);
        
        popup.date_activated.connect((date) => {
            if (is_dtstart)
                start_date = date;
            else
                end_date = date;
        });
        
        popup.dismissed.connect(() => {
            popup.destroy();
        });
        
        popup.show_all();
    }
    
    [GtkCallback]
    private void on_insert_text_numbers_only(Gtk.Editable editable, string new_text, int new_text_length,
        ref int position) {
        // prevent recursion when our modified text is inserted (i.e. allow the base handler to
        // deal new text directly)
        if (blocking_insert_text_numbers_only_signal)
            return;
        
        // filter out everything not a number
        string numbers_only = from_string(new_text)
            .filter(ch => ch.isdigit())
            .to_string(ch => ch.to_string());
        
        // insert new text into place, ensure this handler doesn't attempt to process this
        // modified text ... would use SignalHandler.block_by_func() and unblock_by_func(), but
        // the bindings are ungood
        if (!String.is_empty(numbers_only)) {
            blocking_insert_text_numbers_only_signal = true;
            editable.insert_text(numbers_only, numbers_only.length, ref position);
            blocking_insert_text_numbers_only_signal = false;
        }
        
        // don't let the base handler have at the original text
        Signal.stop_emission_by_name(editable, "insert-text");
    }
    
    [GtkCallback]
    private void on_cancel_button_clicked() {
        jump_back();
    }
    
    [GtkCallback]
    private void on_ok_button_clicked() {
        update_master();
        jump_to_card_by_name(CreateUpdateEvent.ID, event);
    }
    
    private void update_master() {
        if (!make_recurring_checkbutton.active) {
            master.make_recurring(null);
            
            return;
        }
        
        iCal.icalrecurrencetype_frequency freq;
        switch (repeats_combobox.active) {
            case Repeats.DAILY:
                freq = iCal.icalrecurrencetype_frequency.DAILY_RECURRENCE;
            break;
            
            case Repeats.WEEKLY:
                freq = iCal.icalrecurrencetype_frequency.WEEKLY_RECURRENCE;
            break;
            
            case Repeats.DAY_OF_THE_WEEK:
            case Repeats.DAY_OF_THE_MONTH:
                freq = iCal.icalrecurrencetype_frequency.MONTHLY_RECURRENCE;
            break;
            
            case Repeats.YEARLY:
                freq = iCal.icalrecurrencetype_frequency.YEARLY_RECURRENCE;
            break;
            
            default:
                assert_not_reached();
        }
        
        Component.RecurrenceRule rrule = new Component.RecurrenceRule(freq);
        rrule.interval = Numeric.floor_int(int.parse(every_entry.text), 1);
        
        if (rrule.is_weekly) {
            Gee.HashMap<Calendar.DayOfWeek?, int> by_day = new Gee.HashMap<Calendar.DayOfWeek?, int>();
            foreach (Calendar.DayOfWeek dow in on_day_checkbuttons.keys) {
                if (on_day_checkbuttons[dow].active)
                    by_day[dow] = 0;
            }
            
            // although control sensitivity should prevent this from happening, be double-sure to
            // prevent infinite loops below
            if (by_day.size == 0)
                by_day[start_date.day_of_week] = 0;
            
            rrule.set_by_rule(Component.RecurrenceRule.ByRule.DAY,
                Component.RecurrenceRule.encode_days(by_day));
            
            // need to also update the start date to fall on one of the selected days of the week
            // start by looking backward
            Calendar.Date new_start_date = start_date.prior(true, (date) => {
                return date.day_of_week in by_day.keys;
            });
            
            // if start date is prior to today's day, move forward
            if (new_start_date.compare_to(Calendar.System.today) < 0) {
                new_start_date = start_date.upcoming(true, (date) => {
                    return date.day_of_week in by_day.keys;
                });
            }
            
            start_date = new_start_date;
        }
        
        // set start and end dates (which may actually be date-times, so use adjust)
        if (never_radiobutton.active) {
            // no duration
            master.adjust_event_date_span(start_date.to_date_span());
            rrule.set_recurrence_end_date(null);
        } else if (ends_on_radiobutton.active) {
            master.adjust_event_date_span(new Calendar.DateSpan(start_date, end_date));
            rrule.set_recurrence_end_date(end_date);
        } else {
            assert(after_radiobutton.active);
            
            master.adjust_event_date_span(start_date.to_date_span());
            rrule.set_recurrence_count(Numeric.floor_int(int.parse(after_entry.text), 1));
        }
        
        if (rrule.is_monthly) {
            if (repeats_combobox.active == Repeats.DAY_OF_THE_WEEK) {
                Gee.HashMap<Calendar.DayOfWeek?, int> by_day = new Gee.HashMap<Calendar.DayOfWeek?, int>();
                by_day[start_date.day_of_week] = start_date.week_of(Calendar.System.first_of_week).week_of_month;
                rrule.set_by_rule(Component.RecurrenceRule.ByRule.DAY,
                    Component.RecurrenceRule.encode_days(by_day));
            } else {
                Gee.Collection<int> by_month_day = new Gee.ArrayList<int>();
                by_month_day.add(start_date.day_of_month.value);
                rrule.set_by_rule(Component.RecurrenceRule.ByRule.MONTH_DAY, by_month_day);
            }
        }
        
        // remove EXDATEs and RDATEs, those are not currently supported
        master.exdates = null;
        master.rdates = null;
        
        master.make_recurring(rrule);
    }
}

}


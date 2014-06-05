/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Host {

/**
 * A blank "form" of widgets for the user to enter or update event details.
 */

[GtkTemplate (ui = "/org/yorba/california/rc/create-update-event.ui")]
public class CreateUpdateEvent : Gtk.Grid, Toolkit.Card {
    public const string ID = "CreateUpdateEvent";
    
    public const string PROP_SELECTED_DATE_SPAN = "selected-date-span";
    
    private const int START_HOUR = 0;
    private const int END_HOUR = 23;
    private const int MIN_DIVISIONS = 15;
    
    public string card_id { get { return ID; } }
    
    public string? title { get { return null; } }
    
    public Gtk.Widget? default_widget { get { return accept_button; } }
    
    public Gtk.Widget? initial_focus { get { return summary_entry; } }
    
    [GtkChild]
    private Gtk.Entry summary_entry;
    
    [GtkChild]
    private Gtk.Button dtstart_date_button;
    
    [GtkChild]
    private Gtk.ComboBoxText dtstart_time_combo;
    
    [GtkChild]
    private Gtk.Button dtend_date_button;
    
    [GtkChild]
    private Gtk.ComboBoxText dtend_time_combo;
    
    [GtkChild]
    private Gtk.CheckButton all_day_toggle;
    
    [GtkChild]
    private Gtk.Entry location_entry;
    
    [GtkChild]
    private Gtk.TextView description_textview;
    
    [GtkChild]
    private Gtk.ComboBoxText calendar_combo;
    
    [GtkChild]
    private Gtk.Button accept_button;
    
    public Calendar.DateSpan selected_date_span { get; set; }
    
    public bool is_update { get; set; default = false; }
    
    private new Component.Event event = new Component.Event.blank();
    private Gee.HashMap<string, Calendar.WallTime> time_map = new Gee.HashMap<string, Calendar.WallTime>();
    private Backing.CalendarSource? original_calendar_source;
    private Toolkit.ComboBoxTextModel<Backing.CalendarSource> calendar_model;
    private Gtk.Button? last_date_button_touched = null;
    private bool both_date_buttons_touched = false;
    
    public CreateUpdateEvent() {
        // when selected_date_span updates, update date buttons as well
        notify[PROP_SELECTED_DATE_SPAN].connect(() => {
            dtstart_date_button.label = selected_date_span.start_date.to_standard_string();
            dtend_date_button.label = selected_date_span.end_date.to_standard_string();
        });
        
        // create button is active only if summary is filled out; all other fields (so far)
        // guarantee valid values at all times
        summary_entry.bind_property("text-length", accept_button, "sensitive",
            BindingFlags.SYNC_CREATE);
        
        // hide start/end time widgets if an all-day event ..."no-show-all" needed to avoid the
        // merciless effects of show_all()
        all_day_toggle.bind_property("active", dtstart_time_combo, "visible",
            BindingFlags.INVERT_BOOLEAN | BindingFlags.SYNC_CREATE);
        dtstart_time_combo.no_show_all = true;
        all_day_toggle.bind_property("active", dtend_time_combo, "visible",
            BindingFlags.INVERT_BOOLEAN | BindingFlags.SYNC_CREATE);
        dtend_time_combo.no_show_all = true;
        
        // use model to control calendars combo box
        calendar_model = new Toolkit.ComboBoxTextModel<Backing.CalendarSource>(calendar_combo,
            (cal) => cal.title);
        foreach (Backing.CalendarSource calendar_source in
            Backing.Manager.instance.get_sources_of_type<Backing.CalendarSource>()) {
            if (!calendar_source.visible || calendar_source.read_only)
                continue;
            
            calendar_model.add(calendar_source);
        }
        
        update_controls();
    }
    
    public void jumped_to(Toolkit.Card? from, Value? message) {
        if (message != null) {
            event = message as Component.Event;
            assert(event != null);
        } else {
            event = new Component.Event.blank();
        }
        
        update_controls();
    }
    
    private void update_controls() {
        if (event.summary != null)
            summary_entry.text = event.summary;
        else
            summary_entry.text = "";
        
        Calendar.WallTime initial_start_time, initial_end_time;
        if (event.exact_time_span != null) {
            all_day_toggle.active = false;
            selected_date_span = event.exact_time_span.get_date_span();
            initial_start_time =
                event.exact_time_span.start_exact_time.to_timezone(Calendar.Timezone.local).to_wall_time();
            initial_end_time =
                event.exact_time_span.end_exact_time.to_timezone(Calendar.Timezone.local).to_wall_time();
        } else if (event.date_span != null) {
            all_day_toggle.active = true;
            selected_date_span = event.date_span;
            initial_start_time = Calendar.System.now.to_wall_time();
            initial_end_time = Calendar.System.now.adjust_time(1, Calendar.TimeUnit.HOUR).to_wall_time();
        } else {
            all_day_toggle.active = false;
            selected_date_span = new Calendar.DateSpan(Calendar.System.today, Calendar.System.today);
            initial_start_time = Calendar.System.now.to_wall_time();
            initial_end_time = Calendar.System.now.adjust_time(1, Calendar.TimeUnit.HOUR).to_wall_time();
        }
        
        // initialize start and end time controls (as in, wall clock time)
        Calendar.WallTime current = new Calendar.WallTime(START_HOUR, Calendar.WallTime.MIN_MINUTE, 0);
        Calendar.WallTime end = new Calendar.WallTime(END_HOUR, Calendar.WallTime.MAX_MINUTE, 0);
        int index = 0;
        int dtstart_active_index = -1, dtend_active_index = -1;
        bool rollover = false;
        while (current.compare_to(end) <= 0 && !rollover) {
            string fmt = current.to_pretty_string(Calendar.WallTime.PrettyFlag.NONE);
            
            dtstart_time_combo.append_text(fmt);
            dtend_time_combo.append_text(fmt);
            
            // use the latest time for each end of the span to initialize combo boxes, looking for
            // exact match, otherwise taking the *next* index (to default to the future slot, not
            // one that's past)
            int cmp = initial_start_time.compare_to(current);
            if (cmp == 0)
                dtstart_active_index = index;
            else if (cmp > 0)
                dtstart_active_index = index + 1;
            
            cmp = initial_end_time.compare_to(current);
            if (cmp == 0)
                dtend_active_index = index;
            else if (cmp > 0)
                dtend_active_index = index + 1;
            
            index++;
            
            time_map.set(fmt, current);
            current = current.adjust(MIN_DIVISIONS, Calendar.TimeUnit.MINUTE, out rollover);
        }
        
        // set initial indices, careful to avoid overrun
        dtstart_time_combo.set_active(dtstart_active_index.clamp(0, index - 1));
        dtend_time_combo.set_active(dtend_active_index.clamp(0, index - 1));
        
        // set combo to event's calendar
        if (event.calendar_source != null) {
            calendar_model.set_item_active(event.calendar_source);
        } else {
            calendar_combo.active = 0;
            is_update = false;
        }
        
        location_entry.text = event.location ?? "";
        description_textview.buffer.text = event.description ?? "";
        
        accept_button.label = is_update ? _("_Update") : _("C_reate");
        original_calendar_source = event.calendar_source;
    }
    
    [GtkCallback]
    private void on_date_button_clicked(Gtk.Button button) {
        bool is_dtstart = (button == dtstart_date_button);
        
        // if both buttons have been touched, go into free-selection mode with the dates, otherwise
        // respect the original span duration
        both_date_buttons_touched =
            both_date_buttons_touched
            || (last_date_button_touched != null && last_date_button_touched != button);
        
        Toolkit.CalendarPopup popup = new Toolkit.CalendarPopup(button,
            is_dtstart ? selected_date_span.start_date : selected_date_span.end_date);
        
        popup.date_selected.connect((date) => {
            // if both buttons touched, use free date selection, otherwise respect the original
            // span duration
            if (both_date_buttons_touched) {
                selected_date_span = new Calendar.DateSpan(
                    is_dtstart ? date : selected_date_span.start_date,
                    !is_dtstart ? date : selected_date_span.end_date
                );
            } else {
                selected_date_span = is_dtstart
                    ? selected_date_span.adjust_start_date(date)
                    : selected_date_span.adjust_end_date(date);
            }
        });
        
        popup.dismissed.connect(() => {
            popup.destroy();
        });
        
        popup.show_all();
        
        last_date_button_touched = button;
    }
    
    [GtkCallback]
    private void on_accept_clicked() {
        if (calendar_model.active == null)
            return;
        
        event.calendar_source = calendar_model.active;
        event.summary = summary_entry.text;
        event.location = location_entry.text;
        event.description = description_textview.buffer.text;
        
        if (all_day_toggle.active) {
            event.set_event_date_span(selected_date_span);
        } else {
            // use existing timezone unless not specified in original event
            Calendar.Timezone tz = (event.exact_time_span != null)
                ? event.exact_time_span.start_exact_time.tz
                : Calendar.Timezone.local;
            event.set_event_exact_time_span(
                new Calendar.ExactTimeSpan(
                    new Calendar.ExactTime(tz, selected_date_span.start_date,
                        time_map.get(dtstart_time_combo.get_active_text())),
                    new Calendar.ExactTime(tz, selected_date_span.end_date,
                        time_map.get(dtend_time_combo.get_active_text()))
                )
            );
        }
        
        if (is_update)
            update_event_async.begin(null);
        else
            create_event_async.begin(null);
    }
    
    [GtkCallback]
    private void on_cancel_button_clicked() {
        jump_home_or_user_closed();
    }
    
    private async void create_event_async(Cancellable? cancellable) {
        if (event.calendar_source == null) {
            notify_failure(_("Unable to create event: calendar must be specified"));
            
            return;
        }
        
        try {
            yield event.calendar_source.create_component_async(event, cancellable);
            notify_success();
        } catch (Error err) {
            notify_failure(_("Unable to create event: %s").printf(err.message));
        }
    }
    
    // TODO: Delete from original source if not the same as the new source
    private async void update_event_async(Cancellable? cancellable) {
        if (event.calendar_source == null) {
            notify_failure(_("Unable to update event: calendar must be specified"));
            
            return;
        }
        
        try {
            yield event.calendar_source.update_component_async(event, cancellable);
            notify_success();
        } catch (Error err) {
            notify_failure(_("Unable to update event: %s").printf(err.message));
        }
    }
    
}

}

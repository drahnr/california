/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Host {

/**
 * A blank "form" of widgets for the user to enter or update event details.
 *
 * Message IN: If creating a new event, send Component.Event.blank() (pre-filled with any known
 * details).  If updating an existing event, send Component.Event.clone().
 */

[GtkTemplate (ui = "/org/yorba/california/rc/create-update-event.ui")]
public class CreateUpdateEvent : Gtk.Grid, Toolkit.Card {
    public const string ID = "CreateUpdateEvent";
    
    public const string PROP_SELECTED_DATE_SPAN = "selected-date-span";
    
    private const int START_HOUR = 0;
    private const int END_HOUR = 23;
    private const int MIN_DIVISIONS = 15;
    
    private const string FAMILY_NORMAL = "normal";
    private const string FAMILY_RECURRING = "recurring";
    
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
    private Gtk.Box rotating_button_box_container;
    
    public Calendar.DateSpan selected_date_span { get; set; }
    
    public bool is_update { get; set; default = false; }
    
    private new Component.Event event = new Component.Event.blank();
    private Gee.HashMap<string, Calendar.WallTime> time_map = new Gee.HashMap<string, Calendar.WallTime>();
    private Backing.CalendarSource? original_calendar_source;
    private Toolkit.ComboBoxTextModel<Backing.CalendarSource> calendar_model;
    private Gtk.Button? last_date_button_touched = null;
    private bool both_date_buttons_touched = false;
    
    private Toolkit.RotatingButtonBox rotating_button_box = new Toolkit.RotatingButtonBox();
    
    private Gtk.Button accept_button = new Gtk.Button();
    private Gtk.Button cancel_button = new Gtk.Button.with_mnemonic(_("_Cancel"));
    private Gtk.Button update_all_button = new Gtk.Button.with_mnemonic(_("Update A_ll Events"));
    private Gtk.Button update_this_button = new Gtk.Button.with_mnemonic(_("Update _This Event"));
    private Gtk.Button cancel_recurring_button = new Gtk.Button.with_mnemonic(_("_Cancel"));
    
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
        
        accept_button.get_style_context().add_class("suggested-action");
        
        accept_button.clicked.connect(on_accept_button_clicked);
        cancel_button.clicked.connect(on_cancel_button_clicked);
        update_all_button.clicked.connect(on_update_all_button_clicked);
        update_this_button.clicked.connect(on_update_this_button_clicked);
        cancel_recurring_button.clicked.connect(on_cancel_recurring_button_clicked);
        
        rotating_button_box.pack_end(FAMILY_NORMAL, cancel_button);
        rotating_button_box.pack_end(FAMILY_NORMAL, accept_button);
        
        rotating_button_box.pack_end(FAMILY_RECURRING, cancel_recurring_button);
        rotating_button_box.pack_end(FAMILY_RECURRING, update_all_button);
        rotating_button_box.pack_end(FAMILY_RECURRING, update_this_button);
        
        // The cancel-recurring-update button looks big compared to other buttons, so allow for the
        // ButtonBox to reduce it in size
        rotating_button_box.get_family_container(FAMILY_RECURRING).child_set_property(cancel_recurring_button,
            "non-homogeneous", true);
        
        rotating_button_box.expand = true;
        rotating_button_box.halign = Gtk.Align.FILL;
        rotating_button_box.valign = Gtk.Align.END;
        rotating_button_box_container.add(rotating_button_box);
        
        update_controls();
    }
    
    public void jumped_to(Toolkit.Card? from, Toolkit.Card.Jump reason, Value? message) {
        // if no message, leave everything as it is
        if (message == null)
            return;
        
        event = (Component.Event) message;
        
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
            
            // set in Component.Event as well, to at least initialize it for use elsewhere while
            // editing (such as the RRULE)
            event.set_event_exact_time_span(new Calendar.ExactTimeSpan(
                new Calendar.ExactTime(Calendar.Timezone.local, Calendar.System.today, initial_start_time),
                new Calendar.ExactTime(Calendar.Timezone.local, Calendar.System.today, initial_end_time)
            ));
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
        accept_button.use_underline = true;
        
        rotating_button_box.family = FAMILY_NORMAL;
        
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
    private void on_recurring_button_clicked() {
        // update the component with what's in the controls now
        update_component(event, true);
        
        // send off to recurring editor
        jump_to_card_by_name(CreateUpdateRecurring.ID, event);
    }
    
    private void on_accept_button_clicked() {
        if (calendar_model.active == null)
            return;
        
        // if updating a recurring event, need to ask about update scope
        if (event.is_generated_instance && is_update) {
            rotating_button_box.family = FAMILY_RECURRING;
            
            return;
        }
        
        // create/update this instance of the event
        create_update_event(event, true);
    }
    
    // TODO: Now that a clone is being used for editing, can directly bind controls properties to
    // Event's properties and update that way ... doesn't quite work when updating the master event,
    // however
    private void update_component(Component.Event target, bool replace_dtstart) {
        target.calendar_source = calendar_model.active;
        target.summary = summary_entry.text;
        target.location = location_entry.text;
        target.description = description_textview.buffer.text;
        
        // if updating the master, don't replace the dtstart/dtend, but do want to adjust it from
        // DATE to DATE-TIME or vice-versa
        if (!replace_dtstart) {
            if (target.is_all_day != all_day_toggle.active) {
                if (all_day_toggle.active) {
                    target.timed_to_all_day_event();
                } else {
                    target.all_day_to_timed_event(
                        time_map.get(dtstart_time_combo.get_active_text()),
                        time_map.get(dtend_time_combo.get_active_text()),
                        Calendar.Timezone.local
                    );
                }
            }
            
            return;
        }
        
        if (all_day_toggle.active) {
            target.set_event_date_span(selected_date_span);
        } else {
            target.set_event_exact_time_span(
                new Calendar.ExactTimeSpan(
                    new Calendar.ExactTime(Calendar.Timezone.local, selected_date_span.start_date,
                        time_map.get(dtstart_time_combo.get_active_text())),
                    new Calendar.ExactTime(Calendar.Timezone.local, selected_date_span.end_date,
                        time_map.get(dtend_time_combo.get_active_text()))
                )
            );
        }
    }
    
    private void create_update_event(Component.Event target, bool replace_dtstart) {
        update_component(target, replace_dtstart);
        
        if (is_update)
            update_event_async.begin(target, null);
        else
            create_event_async.begin(target, null);
    }
    
    private void on_cancel_button_clicked() {
        notify_user_closed();
    }
    
    private void on_update_all_button_clicked() {
        create_update_event(event.is_master_instance ? event : (Component.Event) event.master, false);
    }
    
    private void on_update_this_button_clicked() {
        create_update_event(event, true);
    }
    
    private void on_cancel_recurring_button_clicked() {
        rotating_button_box.family = FAMILY_NORMAL;
    }
    
    private async void create_event_async(Component.Event target, Cancellable? cancellable) {
        if (target.calendar_source == null) {
            notify_failure(_("Unable to create event: calendar must be specified"));
            
            return;
        }
        
        Gdk.Cursor? cursor = Toolkit.set_busy(this);
        
        Error? create_err = null;
        try {
            yield event.calendar_source.create_component_async(target, cancellable);
        } catch (Error err) {
            create_err = err;
        }
        
        Toolkit.set_unbusy(this, cursor);
        
        if (create_err == null)
            notify_success();
        else
            notify_failure(_("Unable to create event: %s").printf(create_err.message));
    }
    
    // TODO: Delete from original source if not the same as the new source
    private async void update_event_async(Component.Event target, Cancellable? cancellable) {
        if (target.calendar_source == null) {
            notify_failure(_("Unable to update event: calendar must be specified"));
            
            return;
        }
        
        Gdk.Cursor? cursor = Toolkit.set_busy(this);
        
        Error? update_err = null;
        try {
            yield event.calendar_source.update_component_async(target, cancellable);
        } catch (Error err) {
            update_err = err;
        }
        
        Toolkit.set_unbusy(this, cursor);
        
        if (update_err == null)
            notify_success();
        else
            notify_failure(_("Unable to update event: %s").printf(update_err.message));
    }
    
}

}

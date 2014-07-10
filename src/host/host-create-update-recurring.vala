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
    
    // DO NOT CHANGE UNLESS YOU KNOW WHAT YOU'RE DOING.  These values are mirrored in the Glade
    // file's repeats_combobox model.
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
    private Gtk.Button end_date_button;
    
    [GtkChild]
    private Gtk.Button ok_button;
    
    private new Component.Event? event = null;
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
    
    public void jumped_to(Toolkit.Card? from, Toolkit.Card.Jump reason, Value? message) {
        if (message != null)
            event = (Component.Event) message;
        
        // *must* have an Event by this point, whether from before or due to this jump
        assert(event != null);
        update_controls();
    }
    
    private void update_controls() {
        make_recurring_checkbutton.active = (event.rrule != null);
        
        // set to defaults if not a recurring event
        if (event.rrule == null) {
            repeats_combobox.active = Repeats.DAILY;
            every_entry.text = "1";
            never_radiobutton.active = true;
            after_entry.text = "1";
            
            Calendar.DateSpan event_span = event.get_event_date_span(Calendar.Timezone.local);
            start_date = event_span.start_date;
            end_date = event_span.end_date;
            
            return;
        }
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
        // modified text
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
        jump_back();
    }
}

}


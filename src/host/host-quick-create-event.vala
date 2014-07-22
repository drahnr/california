/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Host {

[GtkTemplate (ui = "/org/yorba/california/rc/quick-create-event.ui")]
public class QuickCreateEvent : Gtk.Grid, Toolkit.Card {
    public const string ID = "QuickCreateEvent";
    
    public string card_id { get { return ID; } }
    
    public string? title { get { return null; } }
    
    public new Component.Event? event { get; private set; default = null; }
    
    public Gtk.Widget? default_widget { get { return create_button; } }
    
    public Gtk.Widget? initial_focus { get { return details_entry; } }
    
    [GtkChild]
    private Gtk.Box when_box;
    
    [GtkChild]
    private Gtk.Label when_text_label;
    
    [GtkChild]
    private Gtk.Entry details_entry;
    
    [GtkChild]
    private Gtk.Label example_label;
    
    [GtkChild]
    private Gtk.ComboBoxText calendar_combo_box;
    
    [GtkChild]
    private Gtk.Button create_button;
    
    private Toolkit.ComboBoxTextModel<Backing.CalendarSource> model;
    
    public QuickCreateEvent() {
        // create and initialize combo box model
        model = new Toolkit.ComboBoxTextModel<Backing.CalendarSource>(calendar_combo_box,
            (cal) => cal.title);
        foreach (Backing.CalendarSource calendar_source in
            Backing.Manager.instance.get_sources_of_type<Backing.CalendarSource>()) {
            if (calendar_source.visible && !calendar_source.read_only)
                model.add(calendar_source);
        }
        
        details_entry.secondary_icon_name = get_direction() == Gtk.TextDirection.RTL
            ? "edit-clear-rtl-symbolic" : "edit-clear-symbolic";
    }
    
    public void jumped_to(Toolkit.Card? from, Toolkit.Card.Jump reason, Value? message) {
        event = (message != null) ? message as Component.Event : null;
        
        // if initial date/times supplied, reveal to the user and change the example
        string eg;
        if (event != null && (event.date_span != null || event.exact_time_span != null)) {
            when_box.visible = true;
            when_text_label.label = event.get_event_time_pretty_string(Calendar.Timezone.local);
            if (event.date_span != null)
                eg = _("Example: Dinner at Tadich Grill 7:30pm");
            else
                eg = _("Example: Dinner at Tadich Grill");
        } else {
            when_box.visible = false;
            when_box.no_show_all = true;
            eg = _("Example: Dinner at Tadich Grill 7:30pm tomorrow");
        }

        example_label.label = "<small><i>%s</i></small>".printf(eg);
        
        // make first item active
        calendar_combo_box.active = 0;
    }
    
    [GtkCallback]
    private void on_details_entry_icon_release(Gtk.Entry entry, Gtk.EntryIconPosition icon,
        Gdk.Event event) {
        // check for clear icon being pressed
        if (icon == Gtk.EntryIconPosition.SECONDARY)
            details_entry.text = "";
    }
    
    [GtkCallback]
    private void on_cancel_button_clicked() {
        notify_user_closed();
    }
    
    [GtkCallback]
    private void on_create_button_clicked() {
        string details = details_entry.text.strip();
        
        if (String.is_empty(details)) {
            create_empty_event();
            
            return;
        }
        
        Component.DetailsParser parser = new Component.DetailsParser(details, model.active,
            event);
        event = parser.event;
        
        if (event.is_valid(true))
            create_event_async.begin(null);
        else
            create_empty_event();
    }
    
    private void create_empty_event() {
        // Must pass some kind of event to create/update, so use blank if required
        if (event == null)
            event = new Component.Event.blank();
        
        // jump to Create/Update dialog and remove this Card from the Deck ... this ensures
        // that if the user presses Cancel in the Create/Update dialog the Deck exits rather
        // than returns here (via jump_home_or_user_closed())
        jump_to_card_by_name(CreateUpdateEvent.ID, event);
        deck.remove_cards(iterate<Toolkit.Card>(this).to_array_list());
    }
    
    private async void create_event_async(Cancellable? cancellable) {
        if (event.calendar_source == null) {
            notify_failure(_("Unable to create event: calendar must be specified"));
            
            return;
        }
        
        Gdk.Cursor? cursor = Toolkit.set_busy(this);
        
        Error? create_err = null;
        try {
            yield event.calendar_source.create_component_async(event, cancellable);
        } catch (Error err) {
            create_err = err;
        }
        
        Toolkit.set_unbusy(this, cursor);
        
        if (create_err == null)
            notify_success();
        else
            notify_failure(_("Unable to create event: %s").printf(create_err.message));
    }
}

}


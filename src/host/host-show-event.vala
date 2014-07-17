/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Host {

/**
 * MESSAGE IN: Send the Component.Event to be displayed.
 */

[GtkTemplate (ui = "/org/yorba/california/rc/show-event.ui")]
public class ShowEvent : Gtk.Grid, Toolkit.Card {
    public const string ID = "ShowEvent";
    
    public string card_id { get { return ID; } }
    
    public string? title { get { return null; } }
    
    public Gtk.Widget? default_widget { get { return close_button; } }
    
    public Gtk.Widget? initial_focus { get { return close_button; } }
    
    [GtkChild]
    private Gtk.Label summary_text;
    
    [GtkChild]
    private Gtk.Label when_label;
    
    [GtkChild]
    private Gtk.Label when_text;
    
    [GtkChild]
    private Gtk.Label where_label;
    
    [GtkChild]
    private Gtk.Label where_text;
    
    [GtkChild]
    private Gtk.Label description_text;
    
    [GtkChild]
    private Gtk.Button update_button;
    
    [GtkChild]
    private Gtk.Button remove_button;
    
    [GtkChild]
    private Gtk.Button close_button;
    
    [GtkChild]
    private Gtk.Revealer button_box_revealer;
    
    [GtkChild]
    private Gtk.Revealer remove_recurring_revealer;
    
    private new Component.Event event;
    
    public ShowEvent() {
        Calendar.System.instance.is_24hr_changed.connect(build_display);
        Calendar.System.instance.today_changed.connect(build_display);
    }
    
    ~ShowEvent() {
        Calendar.System.instance.is_24hr_changed.disconnect(build_display);
        Calendar.System.instance.today_changed.disconnect(build_display);
    }
    
    public void jumped_to(Toolkit.Card? from, Toolkit.Card.Jump reason, Value? message) {
        // no message, don't update display
        if (message == null)
            return;
        
        event = message as Component.Event;
        assert(event != null);
        
        build_display();
    }
    
    private void build_display() {
        // summary
        set_label(null, summary_text, event.summary);
        
        // location
        set_label(where_label, where_text, event.location);
        
        // time
        set_label(when_label, when_text, event.get_event_time_pretty_string(Calendar.Timezone.local));
        
        // description
        set_label(null, description_text, Markup.linkify(escape(event.description), linkify_delegate));
        
        bool read_only = event.calendar_source != null && event.calendar_source.read_only;
        
        update_button.visible = !read_only;
        update_button.no_show_all = !read_only;
        
        remove_button.visible = !read_only;
        remove_button.no_show_all = !read_only;
    }
    
    private string? escape(string? plain) {
        return !String.is_empty(plain) ? GLib.Markup.escape_text(plain) : plain;
    }
    
    private bool linkify_delegate(string uri, bool known_protocol, out string? pre_markup,
        out string? post_markup) {
        // preserve but don't linkify if unknown protocol
        if (!known_protocol) {
            pre_markup = null;
            post_markup = null;
            
            return true;
        }
        
        // anchor it
        pre_markup = "<a href=\"%s\">".printf(uri);
        post_markup = "</a>";
        
        return true;
    }
    
    // Note that text is not escaped, up to caller to determine if necessary or not.
    private void set_label(Gtk.Label? label, Gtk.Label text, string? str) {
        if (!String.is_empty(str)) {
            text.label = str;
        } else {
            text.visible = false;
            text.no_show_all = true;
            
            // hide its associated label as well
            if (label != null) {
                label.visible = false;
                label.no_show_all = true;
            }
        }
    }
    
    [GtkCallback]
    private void on_remove_button_clicked() {
        // If recurring (and so this is a generated instance of the VEVENT, not the VEVENT itself),
        // reveal additional remove buttons
        //
        // TODO: Gtk.Stack would be a better widget for this animation, but it's unavailable in
        // Glade as of GTK+ 3.12.
        if (event.is_generated_instance) {
            button_box_revealer.reveal_child = false;
            remove_recurring_revealer.reveal_child = true;
            
            return;
        }
        
        remove_events_async.begin(null, Backing.CalendarSource.AffectedInstances.ALL);
    }
    
    [GtkCallback]
    private void on_cancel_remove_recurring_button_clicked() {
        button_box_revealer.reveal_child = true;
        remove_recurring_revealer.reveal_child = false;
    }
    
    [GtkCallback]
    private void on_remove_this_button_clicked() {
        remove_events_async.begin(event.rid, Backing.CalendarSource.AffectedInstances.THIS);
    }
    
    [GtkCallback]
    private void on_remove_future_button_clicked() {
        remove_events_async.begin(event.rid, Backing.CalendarSource.AffectedInstances.THIS_AND_FUTURE);
    }
    
    [GtkCallback]
    private void on_remove_all_button_clicked() {
        remove_events_async.begin(null, Backing.CalendarSource.AffectedInstances.ALL);
    }
    
    [GtkCallback]
    private void on_update_button_clicked() {
        // pass a clone of the existing event for editing
        try {
            jump_to_card_by_name(CreateUpdateEvent.ID, event.clone() as Component.Event);
        } catch (Error err) {
            notify_failure(_("Unable to update event: %s").printf(err.message));
        }
    }
    
    [GtkCallback]
    private void on_close_button_clicked() {
        notify_user_closed();
    }
    
    private async void remove_events_async(Component.DateTime? rid,
        Backing.CalendarSource.AffectedInstances affected) {
        Gdk.Cursor? cursor = Toolkit.set_busy(this);
        
        Error? remove_err = null;
        try {
            if (rid == null || affected == Backing.CalendarSource.AffectedInstances.ALL)
                yield event.calendar_source.remove_all_instances_async(event.uid, null);
            else
                yield event.calendar_source.remove_instances_async(event.uid, rid, affected, null);
        } catch (Error err) {
            remove_err = err;
        }
        
        Toolkit.set_unbusy(this, cursor);
        
        if (remove_err == null) {
            notify_success();
        } else {
            bool multiple = (rid != null) || (affected != Backing.CalendarSource.AffectedInstances.THIS);
            
            // No number is supplied because the number of events removed is indefinite in certain
            // situations ... plural text should simply be for "more than one"
            notify_failure(ngettext("Unable to remove event: %s", "Unable to remove events: %s",
                !multiple ? 1 : 2).printf(remove_err.message));
        }
    }
}

}


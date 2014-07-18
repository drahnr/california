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
    
    private const string FAMILY_NORMAL = "normal";
    private const string FAMILY_REMOVING = "removing";
    
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
    private Gtk.Box rotating_button_box_container;
    
    private new Component.Event event;
    
    private Toolkit.RotatingButtonBox rotating_button_box = new Toolkit.RotatingButtonBox();
    
    private Gtk.Button close_button = new Gtk.Button.with_mnemonic(_("_Close"));
    private Gtk.Button update_button = new Gtk.Button.with_mnemonic(_("_Update"));
    private Gtk.Button remove_button = new Gtk.Button.with_mnemonic(_("_Remove"));
    private Gtk.Button remove_all_button = new Gtk.Button.with_mnemonic(_("Remove A_ll Events"));
    private Gtk.Button remove_this_button = new Gtk.Button.with_mnemonic(_("Remove _This Event"));
    private Gtk.Button remove_this_future_button = new Gtk.Button.with_mnemonic(
        _("Remove This and _Future Events"));
    private Gtk.Button cancel_remove_button = new Gtk.Button.with_mnemonic(_("_Cancel"));
    
    public ShowEvent() {
        Calendar.System.instance.is_24hr_changed.connect(build_display);
        Calendar.System.instance.today_changed.connect(build_display);
        
        remove_button.get_style_context().add_class("destructive-action");
        remove_this_button.get_style_context().add_class("destructive-action");
        remove_this_future_button.get_style_context().add_class("destructive-action");
        remove_all_button.get_style_context().add_class("destructive-action");
        
        close_button.clicked.connect(on_close_button_clicked);
        update_button.clicked.connect(on_update_button_clicked);
        remove_button.clicked.connect(on_remove_button_clicked);
        remove_all_button.clicked.connect(on_remove_all_button_clicked);
        remove_this_button.clicked.connect(on_remove_this_button_clicked);
        remove_this_future_button.clicked.connect(on_remove_future_button_clicked);
        cancel_remove_button.clicked.connect(on_cancel_remove_recurring_button_clicked);
        
        rotating_button_box.pack_end(FAMILY_NORMAL, remove_button);
        rotating_button_box.pack_end(FAMILY_NORMAL, update_button);
        rotating_button_box.pack_end(FAMILY_NORMAL, close_button);
        
        rotating_button_box.pack_end(FAMILY_REMOVING, remove_this_button);
        rotating_button_box.pack_end(FAMILY_REMOVING, remove_this_future_button);
        rotating_button_box.pack_end(FAMILY_REMOVING, remove_all_button);
        rotating_button_box.pack_end(FAMILY_REMOVING, cancel_remove_button);
        
        rotating_button_box.expand = true;
        rotating_button_box.halign = Gtk.Align.FILL;
        rotating_button_box.valign = Gtk.Align.END;
        rotating_button_box_container.add(rotating_button_box);
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
    
    private void on_remove_button_clicked() {
        // If recurring (and so this is a generated instance of the VEVENT, not the VEVENT itself),
        // reveal additional remove buttons
        //
        // TODO: Gtk.Stack would be a better widget for this animation, but it's unavailable in
        // Glade as of GTK+ 3.12.
        if (event.is_generated_instance) {
            rotating_button_box.family = FAMILY_REMOVING;
            
            return;
        }
        
        remove_events_async.begin(null, Backing.CalendarSource.AffectedInstances.ALL);
    }
    
    private void on_cancel_remove_recurring_button_clicked() {
        rotating_button_box.family = FAMILY_NORMAL;
    }
    
    private void on_remove_this_button_clicked() {
        remove_events_async.begin(event.rid, Backing.CalendarSource.AffectedInstances.THIS);
    }
    
    private void on_remove_future_button_clicked() {
        remove_events_async.begin(event.rid, Backing.CalendarSource.AffectedInstances.THIS_AND_FUTURE);
    }
    
    private void on_remove_all_button_clicked() {
        remove_events_async.begin(null, Backing.CalendarSource.AffectedInstances.ALL);
    }
    
    private void on_update_button_clicked() {
        // pass a clone of the existing event for editing
        try {
            jump_to_card_by_name(CreateUpdateEvent.ID, event.clone() as Component.Event);
        } catch (Error err) {
            notify_failure(_("Unable to update event: %s").printf(err.message));
        }
    }
    
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


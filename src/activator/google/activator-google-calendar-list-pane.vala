/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Activator {

[GtkTemplate (ui = "/org/yorba/california/rc/google-calendar-list.ui")]
public class GoogleCalendarListPane : Gtk.Grid, Toolkit.Card {
    public const string ID = "GoogleCalendarListPane";
    
    public class Message : BaseObject {
        public string username { get; private set; }
        public GData.Feed own_calendars { get; private set; }
        public GData.Feed all_calendars { get; private set; }
        
        public Message(string username, GData.Feed own_calendars, GData.Feed all_calendars) {
            this.username = username;
            this.own_calendars = own_calendars;
            this.all_calendars = all_calendars;
        }
        
        public override string to_string() {
            return "Google Calendar feeds";
        }
    }
    
    public string card_id { get { return ID; } }
    
    public string? title { get { return null; } }
    
    public Gtk.Widget? default_widget { get { return subscribe_button; } }
    
    public Gtk.Widget? initial_focus { get { return null; } }
    
    [GtkChild]
    private Gtk.ListBox own_calendars_listbox;
    
    [GtkChild]
    private Gtk.ListBox unowned_calendars_listbox;
    
    [GtkChild]
    private Gtk.Button subscribe_button;
    
    private Backing.CalDAVSubscribable store;
    private string? username = null;
    private Toolkit.ListBoxModel<GData.CalendarCalendar> own_calendars_model;
    private Toolkit.ListBoxModel<GData.CalendarCalendar> unowned_calendars_model;
    
    public GoogleCalendarListPane(Backing.CalDAVSubscribable store) {
        this.store = store;
        
        own_calendars_listbox.set_placeholder(create_placeholder());
        unowned_calendars_listbox.set_placeholder(create_placeholder());
        
        own_calendars_model = new Toolkit.ListBoxModel<GData.CalendarCalendar>(own_calendars_listbox,
            entry_to_widget, null, entry_comparator);
        unowned_calendars_model = new Toolkit.ListBoxModel<GData.CalendarCalendar>(unowned_calendars_listbox,
            entry_to_widget, null, entry_comparator);
    }
    
    private static Gtk.Widget create_placeholder() {
        Gtk.Label label = new Gtk.Label(null);
        label.set_markup("<i>" + _("None") + "</i>");
        
        return label;
    }
    
    public void jumped_to(Toolkit.Card? from, Toolkit.Card.Jump reason, Value? message) {
        Message? feeds = message as Message;
        assert(feeds != null);
        
        own_calendars_model.clear();
        unowned_calendars_model.clear();
        subscribe_button.sensitive = false;
        
        username = feeds.username;
        
        // add all "own" calendars, keeping track of id to not add them when traversing all calendars
        Gee.HashSet<string> own_ids = new Gee.HashSet<string>();
        foreach (GData.Entry entry in feeds.own_calendars.get_entries()) {
            GData.CalendarCalendar calendar = (GData.CalendarCalendar) entry;
            
            own_calendars_model.add(calendar);
            own_ids.add(calendar.id);
        }
        
        // add everything not in previous list
        foreach (GData.Entry entry in feeds.all_calendars.get_entries()) {
            GData.CalendarCalendar calendar = (GData.CalendarCalendar) entry;
            
            if (!own_ids.contains(calendar.id))
                unowned_calendars_model.add(calendar);
        }
    }
    
    [GtkCallback]
    private void on_cancel_button_clicked() {
        jump_home();
    }
    
    [GtkCallback]
    private void on_subscribe_button_clicked() {
        if (own_calendars_model.selected != null)
            subscribe_async.begin(own_calendars_model.selected);
        else if (unowned_calendars_model.selected != null)
            subscribe_async.begin(unowned_calendars_model.selected);
    }
    
    private Gtk.Widget entry_to_widget(GData.CalendarCalendar calendar) {
        Gtk.Label label = new Gtk.Label(calendar.title);
        label.xalign = 0.0f;
        
        return label;
    }
    
    private int entry_comparator(GData.CalendarCalendar a, GData.CalendarCalendar b) {
        return String.stricmp(a.title, b.title);
    }
    
    [GtkCallback]
    private void on_listbox_selected(Gtk.ListBox listbox, Gtk.ListBoxRow? row) {
        // make sure there's only one selection between the two listboxes
        if (row != null) {
            if (listbox == own_calendars_listbox)
                unowned_calendars_listbox.select_row(null);
            else
                own_calendars_listbox.select_row(null);
        }
        
        subscribe_button.sensitive = (row != null);
    }
    
    private async void subscribe_async(GData.CalendarCalendar calendar) {
        subscribe_button.sensitive = false;
        
        // convert feed URI into an iCal URI
        Soup.URI? uri = null;
        string? errmsg = null;
        try {
            uri = URI.parse(calendar.content_uri);
            
            // look for first path element after "/feeds/", which is the resource name of the
            // calendar
            string[] elements = Soup.URI.decode(uri.path).split("/");
            string? resource_name = null;
            for (int ctr = 0; ctr < elements.length; ctr++) {
                if (elements[ctr] == "feeds") {
                    if (ctr < elements.length - 1)
                        resource_name = elements[ctr + 1];
                    
                    break;
                }
            }
            
            if (resource_name == null)
                errmsg = _("Bad Google URI \"%s\"").printf(uri.to_string(false));
            else
                uri.set_path("/calendar/dav/%s/events".printf(Soup.URI.encode(resource_name, null)));
        } catch (Error err) {
            errmsg = err.message;
        }
        
        if (errmsg != null) {
            notify_failure(_("Unable to subscribe to %s: %s").printf(calendar.title, errmsg));
            
            return;
        }
        
        debug("Subscribing to %s", uri.to_string(false));
        
        Gdk.Cursor? cursor = Toolkit.set_busy(this);
        
        Error? subscribe_err = null;
        try {
            yield store.subscribe_caldav_async(calendar.title, uri, username,
                calendar.color.to_hexadecimal(), null);
        } catch (Error err) {
            subscribe_err = err;
        }
        
        Toolkit.set_unbusy(this, cursor);
        
        if (subscribe_err == null)
            notify_success();
        else
            notify_failure(_("Unable to subscribe to %s: %s").printf(calendar.title, subscribe_err.message));
    }
}

}

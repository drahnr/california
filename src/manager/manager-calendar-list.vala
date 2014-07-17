/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Manager {

/**
 * A list of available calendars and basic configuration controls.
 */

[GtkTemplate (ui = "/org/yorba/california/rc/calendar-manager-list.ui")]
internal class CalendarList : Gtk.Grid, Toolkit.Card {
    public const string PROP_SELECTED = "selected";
    
    public const string ID = "CalendarList";
    
    public string card_id { get { return ID; } }
    
    public string? title { get { return null; } }
    
    public Gtk.Widget? default_widget { get { return null; } }
    
    public Gtk.Widget? initial_focus { get { return calendar_list_box; } }
    
    public CalendarListItem? selected { get; private set; default = null; }
    
    [GtkChild]
    private Gtk.ListBox calendar_list_box;
    
    private Toolkit.ListBoxModel<Backing.CalendarSource> model;
    
    public CalendarList() {
        model = new Toolkit.ListBoxModel<Backing.CalendarSource>(calendar_list_box, model_presentation);
        
        // if already open, initialize now
        if (Backing.Manager.instance.is_open)
            init();
        
        // use Manager's signals to add and remove from model
        Backing.Manager.instance.source_added.connect(on_source_added_to_manager);
        Backing.Manager.instance.source_removed.connect(on_source_removed_from_manager);
        
        // otherwise, initialize when it does open
        Backing.Manager.instance.notify[Backing.Manager.PROP_IS_OPEN].connect(on_manager_opened_closed);
    }
    
    ~CalendarList() {
        Backing.Manager.instance.source_added.disconnect(on_source_added_to_manager);
        Backing.Manager.instance.source_removed.disconnect(on_source_removed_from_manager);
        
        Backing.Manager.instance.notify[Backing.Manager.PROP_IS_OPEN].disconnect(on_manager_opened_closed);
    }
    
    public void jumped_to(Toolkit.Card? from, Toolkit.Card.Jump reason, Value? message) {
    }
    
    private void on_manager_opened_closed() {
        if (Backing.Manager.instance.is_open)
            init();
        else
            model.clear();
    }
    
    private void init() {
        assert(Backing.Manager.instance.is_open);
        
        model.clear();
        model.add_many(Backing.Manager.instance.get_sources_of_type<Backing.CalendarSource>());
    }
    
    private Gtk.Widget model_presentation(Backing.CalendarSource calendar) {
        return new CalendarListItem(calendar);
    }
    
    private void on_source_added_to_manager(Backing.Store store, Backing.Source source) {
        Backing.CalendarSource? calendar = source as Backing.CalendarSource;
        if (calendar != null)
            model.add(calendar);
    }
    
    private void on_source_removed_from_manager(Backing.Store store, Backing.Source source) {
        Backing.CalendarSource? calendar = source as Backing.CalendarSource;
        if (calendar != null)
            model.remove(calendar);
    }
    
    [GtkCallback]
    private void on_calendar_list_box_row_activated(Gtk.ListBoxRow row) {
    }
    
    [GtkCallback]
    private void on_calendar_list_box_row_selected(Gtk.ListBoxRow? row) {
        if (selected != null)
            selected.is_selected = false;
        
        if (row != null) {
            selected = (CalendarListItem) row.get_child();
            selected.is_selected = true;
        } else {
            selected = null;
        }
    }
    
    [GtkCallback]
    private void on_close_button_clicked() {
        notify_user_closed();
    }
}

}


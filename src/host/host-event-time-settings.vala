/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Host {

[GtkTemplate (ui = "/org/yorba/california/rc/event-time-settings.ui")]
public class EventTimeSettings : Gtk.Box, Toolkit.Card {
    public const string ID = "CaliforniaHostEventTimeSettings";
    
    [GtkChild]
    private Gtk.Calendar from_calendar;
    
    [GtkChild]
    private Gtk.Entry from_hour_entry;
    
    [GtkChild]
    private Gtk.Entry from_minutes_entry;
    
    [GtkChild]
    private Gtk.Entry from_meridiem;
    
    public string card_id { get { return ID; } }
    public string? title { get { return null; } }
    public Gtk.Widget? default_widget { get { return null; } }
    public Gtk.Widget? initial_focus { get { return null; } }
    
    private new Component.Event? event = null;
    
    public EventTimeSettings() {
    }
    
    public void jumped_to(Toolkit.Card? from, Toolkit.Card.Jump reason, Value? message) {
        event = (Component.Event) message;
        
        init_controls();
    }
    
    private void init_controls() {
        Calendar.DateSpan event_span = event.get_event_date_span(Calendar.Timezone.local);
        
        from_calendar.day = event_span.start_date.day_of_month.value;
        from_calendar.month = event_span.start_date.month.value - 1;
        from_calendar.year = event_span.start_date.year.value;
    }
}

}


/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Toolkit {

/**
 * A simple {@link Popup} window featuring only a GtkCalendar.
 *
 * The {@link date_selected} signal is fired when the user clicks on a day of the month.  The
 * GtkCalendar can be configured with the {@link calendar} property.
 *
 * In current implementation, merely selecting a day (single- or double-click) will fire the
 * date_selected signal and {@link dismiss} the Popup.
 */

public class CalendarPopup : Popup {
    /**
     * The child Gtk.Calendar.
     */
    public Gtk.Calendar calendar { get; private set; default = new Gtk.Calendar(); }
    
    /**
     * Fired when the user selects a day of a month and year.
     *
     * @see date_activated
     */
    public signal void date_selected(Calendar.Date date);
    
    /**
     * Fired when the user activates (double-clicks) a day of a month and year.
     *
     * Note that a double-click will result in {@link date_selected} followed by this signal
     * followed by {@link dismissed}.
     */
    public signal void date_activated(Calendar.Date date);
    
    /**
     * inheritDoc
     */
    public CalendarPopup(Gtk.Widget relative_to, Calendar.Date initial_date) {
        base (relative_to, Popup.Position.BELOW);
        
        calendar.day = initial_date.day_of_month.value;
        calendar.month = initial_date.month.value - 1;
        calendar.year = initial_date.year.value;
        
        calendar.day_selected.connect(() => {
            on_day_selected(false);
        });
        calendar.day_selected_double_click.connect(() => {
            on_day_selected(true);
        });
        
        add(calendar);
    }
    
    private void on_day_selected(bool activated) {
        Calendar.Date date;
        try {
            date = new Calendar.Date(
                Calendar.DayOfMonth.for(calendar.day),
                Calendar.Month.for(calendar.month + 1),
                new Calendar.Year(calendar.year)
            );
        } catch (CalendarError calerr) {
            debug("Unable to generate date from Gtk.Calendar: %s", calerr.message);
            
            return;
        }
        
        date_selected(date);
        
        if (activated) {
            date_activated(date);
            dismiss();
        }
    }
}

}


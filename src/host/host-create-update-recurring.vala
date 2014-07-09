/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Host {

[GtkTemplate (ui = "/org/yorba/california/rc/create-update-recurring.ui")]
public class CreateUpdateRecurring : Gtk.Grid, Toolkit.Card {
    public const string ID = "CreateUpdateRecurring";
    
    public string card_id { get { return ID; } }
    
    public string? title { get { return null; } }
    
    public Gtk.Widget? default_widget { get { return null; } }
    
    public Gtk.Widget? initial_focus { get { return null; } }
    
    public CreateUpdateRecurring() {
    }
    
    public void jumped_to(Toolkit.Card? from, Toolkit.Card.Jump reason, Value? message) {
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


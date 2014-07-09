/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Activator {

[GtkTemplate (ui = "/org/yorba/california/rc/google-login.ui")]
internal class GoogleLoginPane : Gtk.Grid, Toolkit.Card {
    public const string ID = "GoogleLoginPane";
    
    public string card_id { get { return ID; } }
    
    public string? title { get { return null; } }
    
    public Gtk.Widget? default_widget { get { return login_button; } }
    
    public Gtk.Widget? initial_focus { get { return account_entry; } }
    
    [GtkChild]
    private Gtk.Entry account_entry;
    
    [GtkChild]
    private Gtk.Entry password_entry;
    
    [GtkChild]
    private Gtk.Button login_button;
    
    public GoogleLoginPane() {
        account_entry.bind_property("text-length", login_button, "sensitive",
            BindingFlags.SYNC_CREATE, on_entry_changed);
        password_entry.bind_property("text-length", login_button, "sensitive",
            BindingFlags.SYNC_CREATE, on_entry_changed);
    }
    
    public void jumped_to(Toolkit.Card? from, Toolkit.Card.Jump reason, Value? msg) {
        password_entry.text = "";
    }
    
    private bool on_entry_changed(Binding binding, Value source_value, ref Value target_value) {
        target_value = account_entry.text_length > 0 && password_entry.text_length > 0;
        
        return true;
    }
    
    [GtkCallback]
    private void on_cancel_button_clicked() {
        jump_home();
    }
    
    [GtkCallback]
    private void on_login_button_clicked() {
        jump_to_card_by_name(GoogleAuthenticatingPane.ID, new GoogleAuthenticatingPane.Message(
            account_entry.text, password_entry.text));
    }
}

}


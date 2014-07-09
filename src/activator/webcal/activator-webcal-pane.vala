/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Activator {

[GtkTemplate (ui = "/org/yorba/california/rc/webcal-subscribe.ui")]
internal class WebCalActivatorPane : Gtk.Grid, Toolkit.Card {
    public const string ID = "WebCalActivatorPane";
    
    public string card_id { get { return ID; } }
    
    public string? title { get { return null; } }
    
    public Gtk.Widget? default_widget { get { return subscribe_button; } }
    
    public Gtk.Widget? initial_focus { get { return name_entry; } }
    
    [GtkChild]
    private Gtk.ColorButton color_button;
    
    [GtkChild]
    private Gtk.Entry name_entry;
    
    [GtkChild]
    private Gtk.Entry url_entry;
    
    [GtkChild]
    private Gtk.Button subscribe_button;
    
    private Backing.WebCalSubscribable store;
    
    public WebCalActivatorPane(Backing.WebCalSubscribable store, Soup.URI? supplied_url) {
        this.store = store;
        
        if (supplied_url != null) {
            url_entry.text = supplied_url.to_string(false);
            url_entry.sensitive = false;
        }
        
        name_entry.bind_property("text-length", subscribe_button, "sensitive",
            BindingFlags.SYNC_CREATE, on_entry_changed);
        url_entry.bind_property("text-length", subscribe_button, "sensitive",
            BindingFlags.SYNC_CREATE, on_entry_changed);
    }
    
    public void jumped_to(Toolkit.Card? from, Toolkit.Card.Jump reason, Value? message) {
    }
    
    private bool on_entry_changed(Binding binding, Value source_value, ref Value target_value) {
        target_value =
            name_entry.text_length > 0 
            && url_entry.text_length > 0
            && URI.is_valid(url_entry.text, { "http://", "https://", "webcal://" });
        
        return true;
    }
    
    [GtkCallback]
    private void on_cancel_button_clicked() {
        jump_home();
    }
    
    [GtkCallback]
    private void on_subscribe_button_clicked() {
        sensitive = false;
        
        subscribe_async.begin();
    }
    
    private async void subscribe_async() {
        Gdk.Cursor? cursor = Toolkit.set_busy(this);
        
        Error? subscribe_err = null;
        try {
            yield store.subscribe_webcal_async(name_entry.text, URI.parse(url_entry.text),
                null, Gfx.rgba_to_uint8_rgb_string(color_button.rgba), null);
        } catch (Error err) {
            subscribe_err = err;
        }
        
        Toolkit.set_unbusy(this, cursor);
        
        if (subscribe_err == null) {
            notify_success();
        } else {
            notify_failure(_("Unable to subscribe to Web calendar at %s: %s").printf(url_entry.text,
                subscribe_err.message));
        }
    }
}

}


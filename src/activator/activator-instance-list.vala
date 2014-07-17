/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Activator {

[GtkTemplate (ui = "/org/yorba/california/rc/activator-list.ui")]
public class InstanceList : Gtk.Grid, Toolkit.Card {
    public const string ID = "ActivatorInstanceList";
    
    public string card_id { get { return ID; } }
    
    public string? title { get { return null; } }
    
    public Gtk.Widget? default_widget { get { return add_button; } }
    
    public Gtk.Widget? initial_focus { get { return listbox; } }
    
    [GtkChild]
    private Gtk.ListBox listbox;
    
    [GtkChild]
    private Gtk.Button add_button;
    
    private Toolkit.ListBoxModel<Instance> model;
    
    public InstanceList() {
        model = new Toolkit.ListBoxModel<Instance>(listbox, model_presentation, null, activator_comparator);
        model.add_many(activators);
        
        model.activated.connect(on_item_activated);
        model.bind_property(Toolkit.ListBoxModel.PROP_SELECTED, add_button, "sensitive", BindingFlags.SYNC_CREATE,
            selected_to_sensitive);
        
        show_all();
    }
    
    private bool selected_to_sensitive(Binding binding, Value source_value, ref Value target_value) {
        target_value = (model.selected != null);
        
        return true;
    }
    
    public void jumped_to(Toolkit.Card? from, Toolkit.Card.Jump reason, Value? message) {
    }
    
    private void on_item_activated(Instance activator) {
        start(activator);
    }
    
    [GtkCallback]
    private void on_add_button_clicked() {
        if (model.selected != null)
            start(model.selected);
    }
    
    [GtkCallback]
    private void on_cancel_button_clicked() {
        notify_user_closed();
    }
    
    private void start(Instance activator) {
        jump_to_card_by_name(activator.first_card_id, null);
    }
    
    private Gtk.Widget model_presentation(Instance activator) {
        Gtk.Label label = new Gtk.Label(activator.title);
        label.xalign = 0.0f;
        label.margin = 4;
        
        return label;
    }
    
    private int activator_comparator(Instance a, Instance b) {
        return String.stricmp(a.title, b.title);
    }
}

}


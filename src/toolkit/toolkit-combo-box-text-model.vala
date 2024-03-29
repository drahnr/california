/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Toolkit {

/**
 * A simple model for a Gtk.ComboBoxText.
 */

public class ComboBoxTextModel<G> : BaseObject {
    public const string PROP_ACTIVE = "active";
    
    /**
     * Returns a string that is the representation of the item in the Gtk.ComboBoxText.
     */
    public delegate string ModelPresentation<G>(G item);
    
    public Gtk.ComboBoxText combo_box { get; private set; }
    
    /**
     * Synchronized to the active property of {@link combo_box}.
     */
    public G? active { get; private set; }
    
    private unowned ModelPresentation<G> model_presentation;
    private unowned CompareDataFunc<G>? comparator;
    private unowned Gee.HashDataFunc<G> hash_func;
    private unowned Gee.EqualDataFunc<G>? equal_func;
    private Gee.ArrayList<G> items;
    private Gee.HashMap<G, int> indices;
    
    public ComboBoxTextModel(Gtk.ComboBoxText combo_box, ModelPresentation<G> model_presentation,
        CompareDataFunc<G>? comparator = null, Gee.HashDataFunc<G>? hash_func = null,
        Gee.EqualDataFunc<G>? equal_func = null) {
        this.combo_box = combo_box;
        this.model_presentation = model_presentation;
        this.comparator = comparator;
        this.hash_func = hash_func;
        this.equal_func = equal_func;
        
        items = new Gee.ArrayList<G>(item_equal_func);
        indices = new Gee.HashMap<G, int>(item_hash_func, item_equal_func);
        
        combo_box.notify["active"].connect(on_combo_box_active);
    }
    
    ~ComboBoxTextModel() {
        combo_box.notify["active"].disconnect(on_combo_box_active);
    }
    
    private int item_comparator(G a, G b) {
        if (comparator != null)
            return comparator(a, b);
        
        return Gee.Functions.get_compare_func_for(typeof(G))(a, b);
    }
    
    private bool item_equal_func(G a, G b) {
        if (equal_func != null)
            return equal_func(a, b);
        
        return Gee.Functions.get_equal_func_for(typeof(G))(a, b);
    }
    
    private uint item_hash_func(G item) {
        if (hash_func != null)
            return hash_func(item);
        
        return Gee.Functions.get_hash_func_for(typeof(G))(item);
    }
    
    /**
     * Add an item to the model and the Gtk.ComboBoxText.
     *
     * Returns false if the item was not added (already present in model).
     */
    public bool add(G item) {
        if (!items.add(item))
            return false;
        
        // sort item according to comparator and determine its index
        items.sort(item_comparator);
        int added_index = items.index_of(item);
        
        // any existing indices need to be incremented
        foreach (G key in indices.keys.to_array()) {
            int existing_index = indices.get(key);
            if (existing_index >= added_index)
                indices.set(key, existing_index + 1);
        }
        
        // add new item to index map
        indices.set(item, added_index);
        
        combo_box.insert_text(added_index, model_presentation(item));
        
        return true;
    }
    
    /**
     * Removes the item from the model and the Gtk.ComboBoxText.
     *
     * Returns false if not removed (not present in model).
     */
    public bool remove(G item) {
        if (!items.remove(item))
            return false;
        
        int removed_index;
        if (!indices.unset(item, out removed_index))
            return false;
        
        foreach (G key in indices.keys.to_array()) {
            int existing_index = indices.get(key);
            assert(existing_index != removed_index);
            
            if (existing_index > removed_index)
                indices.set(key, existing_index - 1);
        }
        
        combo_box.remove(removed_index);
        
        return true;
    }
    
    /**
     * Makes the item active in the Gtk.ComboBoxText.
     *
     * Returns true if the item is present in the model, whether or not it's already active.
     */
    public bool set_item_active(G item) {
        if (!indices.has_key(item))
            return false;
        
        combo_box.active = indices.get(item);
        
        return true;
    }
    
    /**
     * Returns the item at the Gtk.ComboBoxText index.
     */
    public G? get_item_at(int index) {
        Gee.MapIterator<G, int> iter = indices.map_iterator();
        while (iter.next()) {
            if (iter.get_value() == index)
                return iter.get_key();
        }
        
        return null;
    }
    
    private void on_combo_box_active() {
        active = get_item_at(combo_box.active);
    }
    
    public override string to_string() {
        return "ComboBoxTextModel (%d items)".printf(items.size);
    }
}

}


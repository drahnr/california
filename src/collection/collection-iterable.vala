/* Copyright 2013-2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California {

/**
 * Take a Gee object and return a California.Iterable for convenience.
 *
 * An empty Gee.Iterable is created and used if null is passed in.
 */
public California.Iterable<G> traverse<G>(Gee.Iterable<G>? gee_iterable) {
    Gee.Iterable<G>? iterable = gee_iterable ?? new Gee.ArrayList<G>();
    
    return new California.Iterable<G>(iterable.iterator());
}

/**
 * Like {@link traverse}, but make a copy of the Gee.Iterable to allow for safe iteration over
 * it.
 *
 * "Safe iteration" means later operations that remove elements while iterating do not cause an
 * assertion.
 *
 * An empty Gee.Iterable is created and used if null is passed in.
 */
public California.Iterable<G> traverse_safely<G>(Gee.Iterable<G>? iterable) {
    Gee.ArrayList<G> list = new Gee.ArrayList<G>();
    
    if (iterable != null) {
        foreach (G element in iterable)
            list.add(element);
    }
    
    return California.traverse<G>(list);
}

/**
 * Take some non-null items (all must be of type G) and return a California.Iterable for
 * convenience.
 */
public California.Iterable<G> iterate<G>(G g, ...) {
    va_list args = va_list();
    G arg = g;
    
    Gee.ArrayList<G> list = new Gee.ArrayList<G>();
    do {
        list.add(arg);
    } while((arg = args.arg()) != null);
    
    return California.traverse<G>(list);
}

/**
 * Take an array of non-null items (all of type G) and return a California.Iterable for convenience.
 *
 * An empty Gee.Iterable is created and used if null is passed in.
 */
public California.Iterable<G> from_array<G>(G[]? ar) {
    Gee.ArrayList<G> list = new Gee.ArrayList<G>();
    
    if (ar != null) {
        foreach (G item in ar)
            list.add(item);
    }
    
    return California.traverse<G>(list);
}

/**
 * Returns an {@link Iterable} of Unicode characters for each in the supplied string.
 *
 * An empty Gee.Iterable is created and used if null is passed in.
 */
public Iterable<unichar> from_string(string? str) {
    Gee.ArrayList<unichar> list = new Gee.ArrayList<unichar>();
    
    if (!String.is_empty(str)) {
        int index = 0;
        unichar ch;
        while (str.get_next_char(ref index, out ch))
            list.add(ch);
    }
    
    return California.traverse<unichar>(list);
}

/**
 * An Iterable that simply wraps an existing Iterator.  You get one iteration,
 * and only one iteration.  Basically every method triggers one iteration and
 * returns a new object.
 *
 * Note that this can't inherit from Gee.Iterable because its interface
 * requires that map/filter/etc. return Iterators, not Iterables.  It still
 * works in foreach.
 */

public class Iterable<G> : Object {
    /**
     * For {@link to_string}.
     */
    public delegate string? ToString<G>(G element);
    
    /**
     * For simple iteration of the {@link Iterable}.
     */
    public delegate void Iterate<G>(G element);
    
    /**
     * A private class that lets us take a California.Iterable and convert it back
     * into a Gee.Iterable.
     */
    private class GeeIterable<G> : Gee.Traversable<G>, Gee.Iterable<G>, Object {
        private Gee.Iterator<G> i;
        
        public GeeIterable(Gee.Iterator<G> iterator) {
            i = iterator;
        }
        
        public Gee.Iterator<G> iterator() {
            return i;
        }
        
        // Unfortunately necessary for Gee.Traversable.
        public virtual bool @foreach(Gee.ForallFunc<G> f) {
            foreach (G g in this) {
                if (!f(g))
                    return false;
            }
            return true;
        }
    }
    
    private Gee.Iterator<G> i;
    
    public Iterable(Gee.Iterator<G> iterator) {
        i = iterator;
    }
    
    public virtual Gee.Iterator<G> iterator() {
        return i;
    }
    
    /**
     * Be called for each element in the {@link Iterable}.
     *
     * No transformation of the Iterable is made.  The returned Iterable is for the same set of
     * elements as had been iterated over.
     */
    public Iterable<G> iterate(Iterate<G> iteratee) {
        Gee.ArrayList<G> list = new Gee.ArrayList<G>();
        foreach (G g in this) {
            iteratee(g);
            list.add(g);
        }
        
        return new Iterable<G>(list.iterator());
    }
    
    public Iterable<A> map<A>(Gee.MapFunc<A, G> f) {
        return new Iterable<A>(i.map<A>(f));
    }
    
    public Iterable<A> scan<A>(Gee.FoldFunc<A, G> f, owned A seed) {
        return new Iterable<A>(i.scan<A>(f, seed));
    }
    
    public Iterable<G> filter(owned Gee.Predicate<G> f) {
        return new Iterable<G>(i.filter((owned) f));
    }
    
    public Iterable<G> chop(int offset, int length = -1) {
        return new Iterable<G>(i.chop(offset, length));
    }
    
    public Iterable<A> map_nonnull<A>(Gee.MapFunc<A, G> f) {
        return new Iterable<A>(i.map<A>(f).filter(g => g != null));
    }
    
    /**
     * Return only objects of the destination type, as the destination type.
     * Only works on types derived from Object.
     */
    public Iterable<A> cast_object<A>() {
        return new Iterable<G>(
            // This would be a lot simpler if valac didn't barf on the shorter,
            // more obvious syntax for each of these delegates here.
            i.filter(g => ((Object) g).get_type().is_a(typeof(A)))
            .map<A>(g => { return (A) g; }));
    }
    
    public G? first() {
        return (i.next() ? i.@get() : null);
    }
    
    public G? first_matching(owned Gee.Predicate<G> f) {
        foreach (G g in this) {
            if (f(g))
                return g;
        }
        return null;
    }
    
    public bool any(owned Gee.Predicate<G> f) {
        foreach (G g in this) {
            if (f(g))
                return true;
        }
        return false;
    }
    
    public bool contains_any(Gee.Collection<G> c) {
        foreach (G g in this) {
            if (c.contains(g))
                return true;
        }
        
        return false;
    }
    
    public bool all(owned Gee.Predicate<G> f) {
        foreach (G g in this) {
            if (!f(g))
                return false;
        }
        return true;
    }
    
    public int count_matching(owned Gee.Predicate<G> f) {
        int count = 0;
        foreach (G g in this) {
            if (f(g))
                count++;
        }
        return count;
    }
    
    /**
     * The resulting Gee.Iterable comes with the same caveat that you may only
     * iterate over it once.
     */
    public Gee.Iterable<G> to_gee_iterable() {
        return new GeeIterable<G>(i);
    }
    
    /**
     * Convert the {@link Iterable} into a flat array of elements.
     */
    public G[] to_array() {
        G[] ar = new G[0];
        while (i.next())
            ar += i.get();
        
        return ar;
    }
    
    public Gee.Collection<G> add_all_to(Gee.Collection<G> c) {
        while (i.next())
            c.add(i.@get());
        return c;
    }
    
    public Gee.ArrayList<G> to_array_list(owned Gee.EqualDataFunc<G>? equal_func = null) {
        return (Gee.ArrayList<G>) add_all_to(new Gee.ArrayList<G>((owned) equal_func));
    }
    
    public Gee.LinkedList<G> to_linked_list(owned Gee.EqualDataFunc<G>? equal_func = null) {
        return (Gee.LinkedList<G>) add_all_to(new Gee.LinkedList<G>((owned) equal_func));
    }
    
    public Gee.HashSet<G> to_hash_set(owned Gee.HashDataFunc<G>? hash_func = null,
        owned Gee.EqualDataFunc<G>? equal_func = null) {
        return (Gee.HashSet<G>) add_all_to(new Gee.HashSet<G>((owned) hash_func, (owned) equal_func));
    }
    
    public Gee.TreeSet<G> to_tree_set(owned CompareDataFunc<G>? compare_func = null) {
        return (Gee.TreeSet<G>) add_all_to(new Gee.TreeSet<G>((owned) compare_func));
    }
    
    /**
     * Add this {@link Iterable}'s values to an existing Gee.Map, with this Iterable's values as
     * values for the map.
     */
    public Gee.Map<K, G> add_to_map_values<K>(Gee.Map<K, G> c, Gee.MapFunc<K, G> key_func) {
        while (i.next()) {
            G g = i.@get();
            c.@set(key_func(g), g);
        }
        return c;
    }
    
    /**
     * Add this {@link Iterable}'s values to an existing Gee.Map, with this Iterable's values as
     * keys for the map.
     *
     * @see add_to_map_keys
     */
    public Gee.Map<G, V> add_to_map_keys<V>(Gee.Map<G, V> map, Gee.MapFunc<V, G> value_func) {
        while (i.next()) {
            G g = i.get();
            map.set(g, value_func(g));
        }
        
        return map;
    }
    
    /**
     * Transform the {@link Iterable} into a Gee.HashMap, with this Iterable's values as values
     * for the map.
     *
     * @see add_to_map_values
     */
    public Gee.HashMap<K, G> to_hash_map_as_values<K>(Gee.MapFunc<K, G> key_func,
        owned Gee.HashDataFunc<K>? key_hash_func = null,
        owned Gee.EqualDataFunc<K>? key_equal_func = null,
        owned Gee.EqualDataFunc<G>? value_equal_func = null) {
        return (Gee.HashMap<K, G>) add_to_map_values<K>(new Gee.HashMap<K, G>(
            (owned) key_hash_func, (owned) key_equal_func, (owned) value_equal_func), key_func);
    }
    
    /**
     * Transform the {@link Iterable} into a Gee.HashMap, with this Iterable's values as keys
     * for the map.
     */
    public Gee.HashMap<G, V> to_hash_map_as_keys<V>(Gee.MapFunc<V, G> value_func,
        owned Gee.HashDataFunc<G>? key_hash_func = null,
        owned Gee.EqualDataFunc<G>? key_equal_func = null,
        owned Gee.EqualDataFunc<V>? value_equal_func = null) {
        return (Gee.HashMap<G, V>) add_to_map_keys<V>(new Gee.HashMap<G, V>(
            (owned) key_hash_func, (owned) key_equal_func, (owned) value_equal_func), value_func);
    }
    
    /**
     * Convert the {@link Iterable}'s values into a single plain string.
     *
     * If {@link ToString} returns null or an empty string, nothing is appended to the final string.
     *
     * If the final string is empty, null is returned instead.
     */
    public string? to_string(ToString<G> string_cb) {
        StringBuilder builder = new StringBuilder();
        foreach (G element in this) {
            string? str = string_cb(element);
            if (!String.is_empty(str))
                builder.append(str);
        }
        
        return !String.is_empty(builder.str) ? builder.str : null;
    }
}

}

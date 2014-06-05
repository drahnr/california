/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

/**
 * Utility methods to facilitiate loading Resources and converting them into useful objects.
 */

namespace California.Resource {

public const string DEFAULT_PATH = "/org/yorba/california/rc";

/**
 * Loads the resource and returns it as a casted object.
 *
 * Any load error will cause the application to panic.  This generally indicates the resource
 * was not compiled in or that the path is malformed.
 */
public T load<T>(string resource, string object_name, string path = DEFAULT_PATH) {
    string fullpath = "%s%s%s".printf(path, path.has_suffix("/") ? "" : "/", resource);
    
    Gtk.Builder builder = new Gtk.Builder();
    try {
        builder.add_from_resource(fullpath);
    } catch (Error err) {
        error("Unable to load resource %s: %s", fullpath, err.message);
    }
    
    Object? object = builder.get_object(object_name);
    if (object == null)
        error("Unable to load object \"%s\" from %s: not found", object_name, fullpath);
    
    if (!object.get_type().is_a(typeof(T))) {
        error("Unable to load object \"%s\" from %s: not of type %s (is %s)", object_name, fullpath,
            typeof(T).name(), object.get_type().name());
    }
    
    return object;
}

}


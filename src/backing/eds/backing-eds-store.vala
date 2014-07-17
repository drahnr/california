/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

extern void e_source_webdav_set_soup_uri(E.SourceWebdav webdav, Soup.URI uri);

namespace California.Backing {

/**
 * An interface to the EDS source registry.
 */

internal class EdsStore : Store, WebCalSubscribable, CalDAVSubscribable {
    private E.SourceRegistry? registry = null;
    private Gee.HashMap<E.Source, Source> sources = new Gee.HashMap<E.Source, Source>();
    
    public EdsStore() {
        base ("EDS Source Registry");
    }
    
    internal async override void open_async(Cancellable? cancellable) throws Error {
        registry = yield new E.SourceRegistry(cancellable);
        
        List<E.Source> eds_sources = registry.list_sources(E.SOURCE_EXTENSION_CALENDAR);
        foreach (E.Source eds_source in eds_sources)
            yield add_eds_source_async(eds_source);
        
        registry.source_added.connect(eds_source => add_eds_source_async.begin(eds_source));
        registry.source_removed.connect(eds_source => remove_eds_source(eds_source));
        
        is_open = true;
    }
    
    internal async override void close_async(Cancellable? cancellable) throws Error {
        // apparently just drop the ref and disconnect from DBus server will occur
        registry = null;
        
        foreach (E.Source eds_source in sources.keys.to_array())
            remove_eds_source(eds_source);
        
        is_open = false;
    }
    
    /**
     * @inheritDoc
     */
    public async void subscribe_webcal_async(string title, Soup.URI uri, string? username, string color,
        Cancellable? cancellable) throws Error {
        yield subscribe_eds_async(title, uri, username, color, "webcal", cancellable);
    }
    
    /**
     * @inheritDoc
     */
    public async void subscribe_caldav_async(string title, Soup.URI uri, string? username, string color,
        Cancellable? cancellable) throws Error {
        yield subscribe_eds_async(title, uri, username, color, "caldav", cancellable);
    }
    
    private async void subscribe_eds_async(string title, Soup.URI uri, string? username, string color,
        string backend_name, Cancellable? cancellable) throws Error {
        if (!is_open)
            throw new BackingError.UNAVAILABLE("EDS not open");
        
        E.Source scratch = new E.Source(null, null);
        // Surprise -- Google gets special treatment
        scratch.parent = uri.host.has_suffix("google.com") ? "google-stub" : "webcal-stub";
        scratch.enabled = true;
        scratch.display_name = title;
        
        // required
        E.SourceCalendar? calendar = scratch.get_extension(E.SOURCE_EXTENSION_CALENDAR)
            as E.SourceCalendar;
        if (calendar == null)
            throw new BackingError.UNAVAILABLE("No SourceCalendar extension for scratch source");
        calendar.backend_name = backend_name;
        calendar.selected = true;
        calendar.color = color;
        
        // required
        E.SourceWebdav? webdav = scratch.get_extension(E.SOURCE_EXTENSION_WEBDAV_BACKEND)
            as E.SourceWebdav;
        if (webdav == null)
            throw new BackingError.UNAVAILABLE("No SourceWebdav extension for scratch source");
        // nice method that takes care of setting things correctly in a lot of other extensions
        e_source_webdav_set_soup_uri(webdav, uri);
        
        // required
        E.SourceAuthentication? auth = scratch.get_extension(E.SOURCE_EXTENSION_AUTHENTICATION)
            as E.SourceAuthentication;
        if (auth == null)
            throw new BackingError.UNAVAILABLE("No SourceAuthentication extension for scratch source");
        auth.user = username;
        
        // optional w/ baked-in defaults
        E.SourceOffline? offline = scratch.get_extension(E.SOURCE_EXTENSION_OFFLINE)
            as E.SourceOffline;
        if (offline != null)
            offline.stay_synchronized = true;
        
        // optional w/ baked-in defaults
        E.SourceRefresh? refresh = scratch.get_extension(E.SOURCE_EXTENSION_REFRESH)
            as E.SourceRefresh;
        if (refresh != null) {
            refresh.enabled = true;
            refresh.interval_minutes = 1;
        }
        
        List<E.Source> sources = new List<E.Source>();
        sources.append(scratch);
        
        yield registry.create_sources(sources, cancellable);
    }
    
    public override Gee.List<Source> get_sources() {
        Gee.List<Source> list = new Gee.ArrayList<Source>();
        list.add_all(sources.values.read_only_view);
        list.sort((a, b) => {
            return strcmp(((Source) a).title, ((Source) b).title);
        });
        
        return list;
    }
    
    private async void add_eds_source_async(E.Source eds_source) {
        // only interested in calendars for now
        E.SourceCalendar? eds_calendar =
            eds_source.get_extension(E.SOURCE_EXTENSION_CALENDAR) as E.SourceCalendar;
        if (eds_calendar == null)
            return;
        
        EdsCalendarSource calendar = new EdsCalendarSource(eds_source, eds_calendar);
        try {
            yield calendar.open_async(null);
        } catch (Error err) {
            debug("Unable to open %s: %s", calendar.to_string(), err.message);
            
            return;
        }
        
        sources.set(eds_source, calendar);
        
        source_added(calendar);
    }
    
    // since the registry ref may have been dropped (in close_async), it shouldn't be ref'd here
    private void remove_eds_source(E.Source eds_source) {
        // remove from mapping first
        Source? source;
        if (sources.unset(eds_source, out source)) {
            assert(source != null);
            
            source.set_unavailable();
            source_removed(source);
        }
        
        // close in background
        EdsCalendarSource? calendar = source as EdsCalendarSource;
        if (calendar != null)
            calendar.close_async.begin(null);
    }
}

}


/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Calendar {

/**
 * A singleton offering system-based calendar and time information and updates of important changes.
 *
 * Most of System's properties are static as a convenience for callers (to avoid having to always
 * reference {@link instance}).  Since static properties have no notification mechanism, callers
 * interested in being notified of changes must subscribe to the instance's particular signals,
 * i.e. {@link zone_changed}.
 */

public class System : BaseObject {
    private const string CLOCK_FORMAT_SCHEMA = "org.gnome.desktop.interface";
    private const string CLOCK_FORMAT_KEY = "clock-format";
    private const string CLOCK_FORMAT_24H = "24h";
    
    private const int CHECK_DATE_PRIORITY = Priority.LOW;
    private const int MIN_CHECK_DATE_INTERVAL_SEC = 1;
    private const int MAX_CHECK_DATE_INTERVAL_SEC = 30;
    
    public static System instance { get; private set; }
    
    /**
     * The current date according to the local timezone.
     *
     * @see today_changed
     */
    public static Date today { get; private set; }
    
    /**
     * Returns the current {@link ExactTime} of the local {@link Timezone}.
     */
    public static ExactTime now {
        owned get {
            return new ExactTime.now(Timezone.local);
        }
    }
    
    /**
     * If the current user is configured to use 12 or 24-hour time.
     */
    public static bool is_24hr { get; private set; }
    
    /**
     * Returns the system's configured zone as an {@link OlsonZone}.
     */
    public static OlsonZone zone { get; private set; }
    
    /**
     * The current system {@link Timezone}.
     *
     * @see timezone_changed
     * @see Timezone.utc
     */
    public static Timezone timezone { get; private set; }
    
    /**
     * The user's preferred start of the week.
     *
     * Unlike most of the other properties here (which are determined by examining and monitoring
     * the system), this is strictly a user preference that should be configured by the outer
     * application.  It's stored here because it's something that many components in {@link Calendar}
     * need access to and passing it around is often inconvenient.  However, many of the "basic"
     * classes (such as {@link Date} and {@link DayOfWeek}) still ask for it as a parameter to
     * remain flexible.  In the case of {@link Week}, it ''must'' store it, as its span of days is
     * strictly determined by the decision, which can change at runtime.
     *
     * @see first_of_week_changed
     */
    private static FirstOfWeek _first_of_week = FirstOfWeek.DEFAULT;
    public static FirstOfWeek first_of_week {
        get {
            return _first_of_week;
        }
        
        set {
            if (_first_of_week == value)
                return;
            
            FirstOfWeek old_fow = _first_of_week;
            _first_of_week = value;
            
            instance.first_of_week_changed(old_fow, _first_of_week);
        }
    }
    
    private static DBus.timedated timedated_service;
    private static DBus.Properties timedated_properties;
    
    /**
     * Fired when {@link today} changes.
     *
     * This indicates that the system time has crossed midnight (potentially either direction since
     * clock adjustments can happen for a variety of reasons).
     */
    public signal void today_changed(Calendar.Date old_today, Calendar.Date new_today);
    
    /**
     * Fired when {@link is_24hr} changes.
     *
     * This means the user has changed the their clock format configuration.
     */
    public signal void is_24hr_changed(bool new_is_24hr);
    
    /**
     * Fired when {@link zone} changes.
     *
     * This generally indicates that the user has changed system time zone manually or that the
     * system detected the change through geolocation services.
     */
    public signal void zone_changed(OlsonZone old_zone, OlsonZone new_zone);
    
    /**
     * Fired when {@link local_timezone} changes due to system configuration changes.
     */
    public signal void timezone_changed(Timezone old_timezone, Timezone new_timezone);
    
    /**
     * Fired when {@link first_of_week} changes due to user configuration.
     */
    public signal void first_of_week_changed(FirstOfWeek old_fow, FirstOfWeek new_fow);
    
    private GLib.Settings system_clock_format_schema = new GLib.Settings(CLOCK_FORMAT_SCHEMA);
    private Scheduled scheduled_date_timer;
    
    private System() {
        zone = new OlsonZone(timedated_service.timezone);
        timezone = new Timezone(zone);
        debug("Local zone: %s", zone.to_string());
        
        // to be notified of changes as they occur
        timedated_properties.properties_changed.connect(on_timedated_properties_changed);
        
        // monitor 12/24-hr setting for changes and update
        is_24hr = system_clock_format_schema.get_string(CLOCK_FORMAT_KEY) == CLOCK_FORMAT_24H;
        system_clock_format_schema.changed[CLOCK_FORMAT_KEY].connect(() => {
            bool new_is_24hr = system_clock_format_schema.get_string(CLOCK_FORMAT_KEY) == CLOCK_FORMAT_24H;
            if (new_is_24hr != is_24hr) {
                is_24hr = new_is_24hr;
                is_24hr_changed(is_24hr);
            }
        });
        
        // timezone change can potentially update "today"; unless there's a system event we can
        // trap to indicate when the date has changed, use the event loop to check once every so
        // often, but also attempt to calculate time until midnight to change along with it ...
        // this may seem wasteful, but since the date can change for a lot of reasons (user
        // intervention, clock drift, NTP, etc.) this is a simple way to stay on top of things
        today = new Date.now(Timezone.local);
        scheduled_date_timer = new Scheduled.once_after_sec(next_check_today_interval_sec(),
            check_today_changed, CHECK_DATE_PRIORITY);
    }
    
    internal static void preinit() throws IOError {
        timedated_service = Bus.get_proxy_sync(BusType.SYSTEM, DBus.timedated.NAME,
            DBus.timedated.OBJECT_PATH);
        timedated_properties = Bus.get_proxy_sync(BusType.SYSTEM, DBus.Properties.NAME,
            DBus.timedated.OBJECT_PATH);
    }
    
    internal static void init() {
        instance = new System();
    }
    
    internal static void terminate() {
        instance = null;
        timedated_service = null;
        timedated_properties = null;
    }
    
    private void on_timedated_properties_changed(string interf,
        HashTable<string, Variant> changed_properties_values, string[] changed_properties) {
        if (changed_properties_values.contains(DBus.timedated.PROP_TIMEZONE)
            || DBus.timedated.PROP_TIMEZONE in changed_properties) {
            OlsonZone old_zone = zone;
            zone = new OlsonZone(timedated_service.timezone);
            debug("New local zone: %s", zone.to_string());
            
            Timezone old_timezone = timezone;
            timezone = new Timezone(zone);
            
            // fire signals last in case a subscriber monitoring zone thinks that local_timezone
            // has also changed
            zone_changed(old_zone, zone);
            timezone_changed(old_timezone, timezone);
            
            // update current date, if necessary
            update_today();
        }
    }
    
    private int next_check_today_interval_sec() {
        // get the amount of time until midnight, adding one back to account for the second needed
        // to cross into the next day, and another one because this isn't rocket science but a
        // best-effort kind of thing
        ExactTime last_sec_of_day = new ExactTime(Timezone.local, today, WallTime.latest);
        int64 sec_to_midnight = last_sec_of_day.difference(new ExactTime.now(Timezone.local)) + 2;
        
        // clamp values to (a) ensure zero is never passed to Timeout.add_seconds(), which could
        // cause brief racing around midnight if close (but not close enough) to the appointed hour,
        // and (b) not too far out in case the user changes the date and would like to see the
        // change in California at some reasonable interval
        return (int) sec_to_midnight.clamp(MIN_CHECK_DATE_INTERVAL_SEC, MAX_CHECK_DATE_INTERVAL_SEC);
    }
    
    // See note in constructor for logic behind this SourceFunc
    private void check_today_changed() {
        update_today();
        
        // reschedule w/ the next interval
        scheduled_date_timer = new Scheduled.once_after_sec(next_check_today_interval_sec(),
            check_today_changed, CHECK_DATE_PRIORITY);
    }
    
    private void update_today() {
        Date new_today = new Date.now(Timezone.local);
        if (new_today.equal_to(today))
            return;
        
        Date old_today = today;
        today = new_today;
        debug("Date changed: %s", new_today.to_string());
        
        today_changed(old_today, new_today);
    }
    
    public override string to_string() {
        return get_class().get_type().name();
    }
}

}


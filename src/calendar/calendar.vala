/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

/**
 * Calendar data modeling.
 *
 * Almost all of the classes here are immutable and defined as GObjects to make them easier to use
 * in Vala and with support libraries.  The "core" logic relies heavily on GLib's Date, Time, and
 * DateTime classes.
 *
 * {@link Calendar.init} should be invoked prior to using any class in this namespace.  Call
 * {@link Calendar.terminate} when the application is closing.
 */

namespace California.Calendar {

/**
 * An enumeration of various calendar units.
 *
 * @see Unit
 */

public enum DateUnit {
    DAY,
    WEEK,
    MONTH,
    YEAR
}

/**
 * An enumeration of various time units.
 *
 * @see WallTime
 */

public enum TimeUnit {
    SECOND,
    MINUTE,
    HOUR
}

private int init_count = 0;

private unowned string FMT_MONTH_YEAR_FULL;
private unowned string FMT_MONTH_YEAR_ABBREV;
private unowned string FMT_MONTH_FULL;
private unowned string FMT_MONTH_ABBREV;
private unowned string FMT_DAY_OF_WEEK_FULL;
private unowned string FMT_DAY_OF_WEEK_ABBREV;
private unowned string FMT_FULL_DATE;
private unowned string FMT_PRETTY_DATE;
private unowned string FMT_PRETTY_DATE_NO_YEAR;
private unowned string FMT_PRETTY_DATE_ABBREV;
private unowned string FMT_PRETTY_DATE_ABBREV_NO_YEAR;
private unowned string FMT_PRETTY_DATE_NO_DOW;
private unowned string FMT_PRETTY_DATE_ABBREV_NO_DOW;
private unowned string FMT_PRETTY_DATE_NO_DOW_NO_YEAR;
private unowned string FMT_PRETTY_DATE_ABBREV_NO_DOW_NO_YEAR;
private unowned string FMT_PRETTY_DATE_COMPACT;
private unowned string FMT_PRETTY_DATE_COMPACT_NO_YEAR;
private unowned string FMT_PRETTY_DATE_COMPACT_NO_DOW;
private unowned string FMT_PRETTY_DATE_COMPACT_NO_DOW_NO_YEAR;
private unowned string FMT_AM;
private unowned string FMT_BRIEF_AM;
private unowned string FMT_PM;
private unowned string FMT_BRIEF_PM;
private unowned string FMT_12HOUR_MIN_MERIDIEM;
private unowned string FMT_12HOUR_MIN_SEC_MERIDIEM;
private unowned string FMT_24HOUR_MIN;
private unowned string FMT_24HOUR_MIN_SEC;

private unowned string MIDNIGHT;
private unowned string NOON;

public void init() throws Error {
    if (!California.Unit.do_init(ref init_count))
        return;
    
    // Ripped from Shotwell proposed patch for localizing time (http://redmine.yorba.org/issues/2462)
    // courtesy Marcel Stimberg.  Another example may be found here:
    // http://bazaar.launchpad.net/~indicator-applet-developers/indicator-datetime/trunk.12.10/view/head:/src/utils.c
    
    // Because setlocale() is a process-wide setting, need to cache strings at startup, otherwise
    // risk problems with threading
    
    string? messages_locale = Intl.setlocale(LocaleCategory.MESSAGES, null);
    string? time_locale = Intl.setlocale(LocaleCategory.TIME, null);
    
    // LANGUAGE must be unset before changing locales, as it trumps all the LC_* variables
    string? language_env = Environment.get_variable("LANGUAGE");
    if (language_env != null)
        Environment.unset_variable("LANGUAGE");
    
    // Swap LC_TIME's setting into LC_MESSAGE's.  This allows performing lookups of time-based values
    // from a different translation file, useful in mixed-locale settings
    if (time_locale != null)
        Intl.setlocale(LocaleCategory.MESSAGES, time_locale);
    
    // These are not marked for translation because they involve no ordering of format specifiers
    // and strftime handles translating them to the locale
    FMT_MONTH_FULL = "%B";
    FMT_MONTH_ABBREV = "%b";
    FMT_DAY_OF_WEEK_FULL = "%A";
    FMT_DAY_OF_WEEK_ABBREV = "%a";
    FMT_FULL_DATE = "%x";
    FMT_PRETTY_DATE_COMPACT_NO_DOW = "%x";
    
    // The month and year according to locale preferences, i.e. "March 2014"
    // See http://www.cplusplus.com/reference/ctime/strftime/ for format reference
    FMT_MONTH_YEAR_FULL = _("%B %Y");
    
    // The abbreviated month and year according to locale preferences, i.e. "Mar 2014"
    // See http://www.cplusplus.com/reference/ctime/strftime/ for format reference
    FMT_MONTH_YEAR_ABBREV = _("%b %Y");
    
    // A "pretty" date according to locale preferences, i.e. "Monday, March 10, 2014"
    // See http://www.cplusplus.com/reference/ctime/strftime/ for format reference
    FMT_PRETTY_DATE = _("%A, %B %e, %Y");
    
    // A "pretty" date with no year according to locale preferences, i.e. "Monday, March 10"
    // See http://www.cplusplus.com/reference/ctime/strftime/ for format reference
    FMT_PRETTY_DATE_NO_YEAR = _("%A, %B %e");
    
    // A "pretty" date abbreviated according to locale preferences, i.e. "Mon, Mar 10, 2014"
    // See http://www.cplusplus.com/reference/ctime/strftime/ for format reference
    FMT_PRETTY_DATE_ABBREV = _("%a, %b %e, %Y");
    
    // A "pretty" date abbreviated and no year according to locale preferences, i.e.
    // "Mon, Mar 10"
    // See http://www.cplusplus.com/reference/ctime/strftime/ for format reference
    FMT_PRETTY_DATE_ABBREV_NO_YEAR = _("%a, %b %e");
    
    // A "pretty" date with no day of week according to locale preferences, i.e. "March 10, 2014"
    // See http://www.cplusplus.com/reference/ctime/strftime/ for format reference
    FMT_PRETTY_DATE_NO_DOW = _("%B %e, %Y");
    
    // A "pretty" date abbreviated with no day of week according to locale preferences,
    // i.e. "Mar 10, 2014"
    // See http://www.cplusplus.com/reference/ctime/strftime/ for format reference
    FMT_PRETTY_DATE_ABBREV_NO_DOW = _("%b %e, %Y");
    
    // A "pretty" date with no day of week or year according to locale preferences, i.e. "March 10"
    // See http://www.cplusplus.com/reference/ctime/strftime/ for format reference
    FMT_PRETTY_DATE_NO_DOW_NO_YEAR = _("%B %e");
    
    // A "pretty" date abbreviated with no day of week or year according to locale preferences,
    // i.e. "Mar 10"
    // See http://www.cplusplus.com/reference/ctime/strftime/ for format reference
    FMT_PRETTY_DATE_ABBREV_NO_DOW_NO_YEAR = _("%b %e");
    
    // A "pretty" date compacted according to locale preferences, i.e. "Mon 3/10/2014"
    // Leading zeroes will be stripped.
    // See http://www.cplusplus.com/reference/ctime/strftime/ for format reference
    FMT_PRETTY_DATE_COMPACT = _("%a %x");
    
    // A "pretty" date abbreviated and no year according to locale preferences, i.e. "Mon 3/10"
    // Leading zeroes will be stripped.
    // See http://www.cplusplus.com/reference/ctime/strftime/ for format reference
    /* xgettext:no-c-format */
    FMT_PRETTY_DATE_COMPACT_NO_YEAR = _("%a %m/%d");
    
    // A "pretty" date abbreviated with no day of week or year according to locale preferences,
    // i.e. "3/10"
    // Leading zeroes will be stripped.
    // See http://www.cplusplus.com/reference/ctime/strftime/ for format reference
    /* xgettext:no-c-format */
    FMT_PRETTY_DATE_COMPACT_NO_DOW_NO_YEAR = _("%m/%d");
    
    // Ante meridiem
    // (Please translate even if 24-hour clock used in your locale; this allows for GNOME time
    // format user settings to be honored)
    FMT_AM = _("am");
    
    // Brief ante meridiem, i.e. "am" -> "a"
    // (Please translate even if 24-hour clock used in your locale; this allows for GNOME time
    // format user settings to be honored)
    FMT_BRIEF_AM = _("a");
    
    // Post meridiem
    // (Please translate even if 24-hour clock used in your locale; this allows for GNOME time
    // format user settings to be honored)
    FMT_PM = _("pm");
    
    // Brief post meridiem, i.e. "pm" -> "p"
    // (Please translate even if 24-hour clock used in your locale; this allows for GNOME time
    // format user settings to be honored)
    FMT_BRIEF_PM = _("p");
    
    // The 12-hour time with minute and meridiem ("am" or "pm"), i.e. "5:06pm"
    // (Please translate even if 24-hour clock used in your locale; this allows for GNOME time
    // format user settings to be honored)
    FMT_12HOUR_MIN_MERIDIEM = _("%d:%02d%s");
    
    // The 12-hour time with minute, seconds, and meridiem ("am" or "pm"), i.e. "5:06:31pm"
    // (Please translate even if 24-hour clock used in your locale; this allows for GNOME time
    // format user settings to be honored)
    FMT_12HOUR_MIN_SEC_MERIDIEM = _("%d:%02d:%02d%s");
    
    // The 24-hour time with minutes, i.e. "17:06"
    FMT_24HOUR_MIN = _("%02d:%02d");
    
    // The 24-hour time with minutes and seconds, i.e. "17:06:31"
    FMT_24HOUR_MIN_SEC = _("%02d:%02d:%02d");
    
    // return LC_MESSAGES back to proper locale and return LANGUAGE environment variable
    if (messages_locale != null)
        Intl.setlocale(LocaleCategory.MESSAGES, messages_locale);
    if (language_env != null)
        Environment.set_variable("LANGUAGE", language_env, true);
    
    // Used by quick-add to indicate the user wants to create an event at midnight.
    // For more information see https://wiki.gnome.org/Apps/California/TranslatingQuickAdd
    MIDNIGHT = _("midnight");
    
    // Used by quick-add to indicate the user wants to create an event at noon.
    // For more information see https://wiki.gnome.org/Apps/California/TranslatingQuickAdd
    NOON = _("noon");
    
    // This init() throws an IOError, so perform before others to prevent unnecessary unwinding
    System.preinit();
    
    // internal initialization
    Collection.init();
    OlsonZone.init();
    DayOfWeek.init();
    DayOfMonth.init();
    Month.init();
    WallTime.init();
    System.init();
    Timezone.init();
}

public void terminate() {
    if (!California.Unit.do_terminate(ref init_count))
        return;
    
    Timezone.terminate();
    System.terminate();
    WallTime.terminate();
    Month.terminate();
    DayOfMonth.terminate();
    DayOfWeek.terminate();
    OlsonZone.terminate();
    Collection.terminate();
}

}

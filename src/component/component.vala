/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

/**
 * A simplified data model of the iCalendar component scheme.
 *
 * This model is intended to limit the exposure of libical to the rest of the application, while
 * also GObject-ifying it and making its information available in a Vala-friendly manner.
 *
 * See [[https://tools.ietf.org/html/rfc5545]]
 */

namespace California.Component {

private int init_count = 0;

private string TODAY;
private string TOMORROW;
private string YESTERDAY;
private string DAILY;
private string WEEKLY;
private string YEARLY;
private string[] UNIT_WEEKDAYS;
private string[] UNIT_WEEKENDS;
private string[] UNIT_YEARS;
private string[] UNIT_MONTHS;
private string[] UNIT_WEEKS;
private string[] UNIT_DAYS;
private string[] UNIT_HOURS;
private string[] UNIT_MINS;
private string[] COMMON_PREPOSITIONS;
private string[] TIME_PREPOSITIONS;
private string[] LOCATION_PREPOSITIONS;
private string[] DURATION_PREPOSITIONS;
private string[] DELAY_PREPOSITIONS;
private string[] RECURRING_PREPOSITIONS;
private string[] ORDINAL_SUFFIXES;

public void init() throws Error {
    if (!Unit.do_init(ref init_count))
        return;
    
    // external unit init
    Collection.init();
    Calendar.init();
    
    // Used by quick-add to indicate the user wants to create an event for today.
    // For more information see https://wiki.gnome.org/Apps/California/TranslatingQuickAdd
    TODAY = _("today").casefold();
    
    // Used by quick-add to indicate the user wants to create an event for tomorrow.
    // For more information see https://wiki.gnome.org/Apps/California/TranslatingQuickAdd
    TOMORROW = _("tomorrow").casefold();
    
    // Used by quick-add to indicate the user wants to create an event for yesterday.
    // For more information see https://wiki.gnome.org/Apps/California/TranslatingQuickAdd
    YESTERDAY = _("yesterday").casefold();
    
    // Used by quick-add to indicate the user wants to create a daily recurring event
    // For more information see https://wiki.gnome.org/Apps/California/TranslatingQuickAdd
    DAILY = _("daily").casefold();
    
    // Used by quick-add to indicate the user wants to create a weekly recurring event
    // For more information see https://wiki.gnome.org/Apps/California/TranslatingQuickAdd
    WEEKLY = _("weekly").casefold();
    
    // Used by quick-add to indicate the user wants to create a yearly recurring event
    // For more information see https://wiki.gnome.org/Apps/California/TranslatingQuickAdd
    YEARLY = _("yearly").casefold();
    
    // Used by quick-add to indicate the user wants to create an event for every weekday
    // (in most Western countries, this means Monday through Friday, i.e. the work week)
    // Common abbreviations (without punctuation) should be included.  Each word must be separated
    // by semi-colons.
    // For more information see https://wiki.gnome.org/Apps/California/TranslatingQuickAdd
    UNIT_WEEKDAYS = _("weekday;weekdays;").casefold().split(";");
    
    // Used by quick-add to indicate the user wants to create an event for every weekend
    // (in most Western countries, this means Saturday and Sunday, i.e. non-work days)
    // Common abbreviations (without punctuation) should be included.  Each word must be separated
    // by semi-colons.
    // For more information see https://wiki.gnome.org/Apps/California/TranslatingQuickAdd
    UNIT_WEEKENDS = _("weekend;weekends;").casefold().split(";");
    
    // Used by quick-add to convert a user's years unit into an internal value.  Common abbreviations
    // (without punctuation) should be included.  Each word must be separated by semi-colons.
    // For more information see https://wiki.gnome.org/Apps/California/TranslatingQuickAdd
    UNIT_YEARS = _("year;years;yr;yrs;").casefold().split(";");
    
    // Used by quick-add to convert a user's month unit into an internal value.  Common abbreviations
    // (without punctuation) should be included.  Each word must be separated by semi-colons.
    // For more information see https://wiki.gnome.org/Apps/California/TranslatingQuickAdd
    UNIT_MONTHS = _("month;months;mo;mos;").casefold().split(";");
    
    // Used by quick-add to convert a user's week unit into an internal value.  Common abbreviations
    // (without punctuation) should be included.  Each word must be separated by semi-colons.
    // For more information see https://wiki.gnome.org/Apps/California/TranslatingQuickAdd
    UNIT_WEEKS = _("week;weeks;wk;weeks;").casefold().split(";");
    
    // Used by quick-add to convert a user's day unit into an internal value.  Common abbreviations
    // (without punctuation) should be included.  Each word must be separated by semi-colons.
    // For more information see https://wiki.gnome.org/Apps/California/TranslatingQuickAdd
    UNIT_DAYS = _("day;days;").casefold().split(";");
    
    // Used by quick-add to convert a user's hours unit into an internal value.  Common abbreviations
    // (without punctuation) should be included.  Each word must be separated by semi-colons.
    // For more information see https://wiki.gnome.org/Apps/California/TranslatingQuickAdd
    UNIT_HOURS = _("hour;hours;hr;hrs").casefold().split(";");
    
    // Used by quick-add to convert a user's minute unit into an internal value.  Common abbreviations
    // (without punctuation) should be included.  Each word must be separated by semi-colons.
    // For more information see https://wiki.gnome.org/Apps/California/TranslatingQuickAdd
    UNIT_MINS = _("minute;minutes;min;mins").casefold().split(";");
    
    // Used by quick-add to determine if the word is a COMMON preposition (indicating linkage or a
    // connection).  Each word must be separate by semi-colons.
    // These words should not be duplicated in another other preposition list.
    // This list can be empty but that will limit the parser or cause unexpected results.
    // Examples: "wednesday and thursday", "monday or friday"
    // For more information see https://wiki.gnome.org/Apps/California/TranslatingQuickAdd
    COMMON_PREPOSITIONS = _("and;or;").casefold().split(";");
    
    // Used by quick-add to determine if the word is a TIME preposition (indicating a
    // specific time of day, not a duration).  Each word must be separated by semi-colons.
    // It's allowable for some or all of these words to
    // be duplicated in the location prepositions list (elsewhere) but not another time list.
    // The list can be empty, but that will limit the parser.
    // Examples: "at 9am", "from 10pm to 11:30pm", "on monday", "until June 3rd", "this Friday"
    // For more information see https://wiki.gnome.org/Apps/California/TranslatingQuickAdd
    TIME_PREPOSITIONS = _("at;from;to;on;until;this;").casefold().split(";");
    
    // Used by quick-add to determine if the word is a DURATION preposition (indicating a
    // a duration of time, not a specific time).  Each word must be separated by semi-colons.
    // It's allowable for some or all of these words to
    // be duplicated in the location prepositions list (elsewhere) but not another time list.
    // The list can be empty, but that will limit the parser.
    // Examples: "for 3 hours", "for 90 minutes"
    // For more information see https://wiki.gnome.org/Apps/California/TranslatingQuickAdd
    DURATION_PREPOSITIONS = _("for;").casefold().split(";");
    
    // Used by quick-add to determine if the word is a DELAY preposition (indicating a specific
    // time from the current moment).  Each word must be separated by semi-colons.
    // It's allowable for some or all of these words to
    // be duplicated in the location prepositions list (elsewhere) but not another time list.
    // The list can be empty, but that will limit the parser.
    // Example: "in 3 hours" (meaning 3 hours from now)
    // For more information see https://wiki.gnome.org/Apps/California/TranslatingQuickAdd
    DELAY_PREPOSITIONS = _("in;").casefold().split(";");
    
    // Used by quick-add to determine if the word is a RECURRING preposition (indicating a
    // regular occurrance in time).  Each word must be separated by semi-colons.
    // It's allowable for some or all of these words to be duplicated in the location
    // prepositions list (elsewhere) but not another time list.
    // The list can be empty, but that will limit the parser.
    // Example: "every 3 days", "every Friday"
    // For more information see https://wiki.gnome.org/Apps/California/TranslatingQuickAdd
    RECURRING_PREPOSITIONS = _("every;").casefold().split(";");
    
    // Used by quick-add to determine if the word is a LOCATION preposition (indicating a
    // specific place).  Each word must be separated by semi-colons.
    // It's allowable for some or all of these words to be duplicated in
    // the time prepositions list (elsewhere).  The list can be empty, but that will limit the
    // parser.
    // Example: "at supermarket", "at Eiffel Tower"
    // For more information see https://wiki.gnome.org/Apps/California/TranslatingQuickAdd
    LOCATION_PREPOSITIONS = _("at;").casefold().split(";");
    
    // Used by quick-add to strip date numbers of common ordinal suffices.  Each word must be
    // separated by semi-colons.
    // The list can be empty, but that will limit the parser if your language supports ordinal
    // suffixes.
    // Example: "1st", "2nd", "3rd", "4th"
    // For more information see https://wiki.gnome.org/Apps/California/TranslatingQuickAdd
    ORDINAL_SUFFIXES = _("st;nd;rd;th").casefold().split(";");
}

public void terminate() {
    if (!Unit.do_terminate(ref init_count))
        return;
    
    TIME_PREPOSITIONS = LOCATION_PREPOSITIONS = DURATION_PREPOSITIONS = ORDINAL_SUFFIXES = null;
    COMMON_PREPOSITIONS = DELAY_PREPOSITIONS = RECURRING_PREPOSITIONS = null;
    TODAY = TOMORROW = YESTERDAY = DAILY = WEEKLY = YEARLY = null;
    UNIT_WEEKDAYS = UNIT_WEEKENDS = UNIT_YEARS = UNIT_MONTHS = UNIT_WEEKS = UNIT_DAYS = UNIT_HOURS
        = UNIT_MINS = null;
    
    Calendar.terminate();
    Collection.terminate();
}

/**
 * Convenience method to convert a {@link Calendar.Date} to an iCal DATE.
 */
private void date_to_ical(Calendar.Date date, iCal.icaltimetype *ical_dt) {
    ical_dt->year = date.year.value;
    ical_dt->month = date.month.value;
    ical_dt->day = date.day_of_month.value;
    ical_dt->hour = 0;
    ical_dt->minute = 0;
    ical_dt->second = 0;
    ical_dt->is_utc = 0;
    ical_dt->is_date = 1;
    ical_dt->is_daylight = 0;
    ical_dt->zone = null;
}

/**
 * Convenience method to convert a {@link Calendar.ExactTime} to an iCal DATE-TIME.
 */
private void exact_time_to_ical(Calendar.ExactTime exact_time, iCal.icaltimetype *ical_dt) {
    ical_dt->year = exact_time.year.value;
    ical_dt->month = exact_time.month.value;
    ical_dt->day = exact_time.day_of_month.value;
    ical_dt->hour = exact_time.hour;
    ical_dt->minute = exact_time.minute;
    ical_dt->second = exact_time.second;
    ical_dt->is_utc = exact_time.tz.is_utc ? 1 : 0;
    ical_dt->is_date = 0;
    ical_dt->is_daylight = exact_time.is_dst ? 1 : 0;
    ical_dt->zone = iCal.icaltimezone.get_builtin_timezone(exact_time.tz.zone.value);
    if (ical_dt->zone == null)
        message("Unable to get builtin iCal timezone for %s", exact_time.tz.zone.to_string());
}

}


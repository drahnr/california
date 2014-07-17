/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Tests {

private class QuickAdd : UnitTest.Harness {
    public QuickAdd() {
        add_case("null-details", null_details);
        add_case("blank", blank);
        add_case("punct", punct);
        add_case("summary", summary);
        add_case("summary-with-blanks", summary_with_blanks);
        add_case("summary-with-punct", summary_with_punct);
        add_case("summary-location", summary_location);
        add_case("valid-no-summary", valid_no_summary);
        add_case("with-12hr-time", with_12hr_time);
        add_case("with-24hr-time", with_24hr_time);
        add_case("with-day-of-week", with_day_of_week);
        add_case("with-delay", with_delay);
        add_case("with-duration", with_duration);
        add_case("with-delay-and-duration", with_delay_and_duration);
        add_case("indeterminate-time", indeterminate_time);
        add_case("dialog-example", dialog_example);
        add_case("noon", noon);
        add_case("midnight", midnight);
        add_case("pm1230", pm1230);
        add_case("bogus-time", bogus_time);
        add_case("zero-hour", zero_hour);
        add_case("oh-twenty-four-hours", oh_twenty_four_hours);
        add_case("midnight-to-one", midnight_to_one);
        add_case("separate-am", separate_am);
        add_case("separate-pm", separate_pm);
        add_case("start-date-ordinal", start_date_ordinal);
        add_case("end-date-ordinal", end_date_ordinal);
        add_case("simple-and", simple_and);
        add_case("this-weekend", this_weekend);
    }
    
    protected override void setup() throws Error {
        Component.init();
        Calendar.init();
    }
    
    protected override void teardown() {
        Component.terminate();
        Calendar.terminate();
    }
    
    private bool null_details() throws Error {
        Component.DetailsParser parser = new Component.DetailsParser(null, null);
        
        return !parser.event.is_valid(false);
    }
    
    private bool blank() throws Error {
        Component.DetailsParser parser = new Component.DetailsParser(" ", null);
        
        return !parser.event.is_valid(false);
    }
    
    private bool punct() throws Error {
        Component.DetailsParser parser = new Component.DetailsParser("&", null);
        
        return !parser.event.is_valid(false)
            && parser.event.summary == "&";
    }
    
    private bool summary() throws Error {
        Component.DetailsParser parser = new Component.DetailsParser("meet with Alice", null);
        
        return parser.event.summary == "meet with Alice"
            && parser.event.location == null
            && parser.event.exact_time_span == null
            && parser.event.date_span == null;
    }
    
    private bool summary_with_blanks() throws Error {
        Component.DetailsParser parser = new Component.DetailsParser("   meet  with   Alice    ", null);
        
        return parser.event.summary == "meet with Alice"
            && parser.event.location == null
            && parser.event.exact_time_span == null
            && parser.event.date_span == null;
    }
    
    private bool summary_with_punct() throws Error {
        Component.DetailsParser parser = new Component.DetailsParser("meet with Alice & Bob", null);
        
        return parser.event.summary == "meet with Alice & Bob"
            && parser.event.location == null
            && parser.event.exact_time_span == null
            && parser.event.date_span == null;
    }
    
    private bool summary_location() throws Error {
        Component.DetailsParser parser = new Component.DetailsParser("meet with Alice at Bob's", null);
        
        return parser.event.summary == "meet with Alice at Bob's"
            && parser.event.location == "Bob's"
            && parser.event.exact_time_span == null
            && parser.event.date_span == null;
    }
    
    private bool valid_no_summary(out string? dump) throws Error {
        Component.DetailsParser parser = new Component.DetailsParser("7pm to 9pm", null);
        
        dump = parser.event.source;
        
        // valid but not "useful"
        return parser.event.is_valid(false)
            && !parser.event.is_valid(true)
            && California.String.is_empty(parser.event.summary)
            && parser.event.exact_time_span != null;
    }
    
    private bool with_12hr_time() throws Error {
        return with_time(new Component.DetailsParser("dinner at 7pm with Alice", null));
    }
    
    private bool with_24hr_time() throws Error {
        return with_time(new Component.DetailsParser("dinner at 1900 with Alice", null));
    }
    
    private bool with_time(Component.DetailsParser parser) {
        Calendar.ExactTime time = new Calendar.ExactTime(
            Calendar.System.timezone,
            Calendar.System.today,
            new Calendar.WallTime(19, 0, 0)
        );
        
        return parser.event.summary == "dinner with Alice"
            && parser.event.location == null
            && parser.event.exact_time_span.start_exact_time.equal_to(time)
            && parser.event.exact_time_span.end_exact_time.equal_to(time.adjust_time(1, Calendar.TimeUnit.HOUR));
    }
    
    private bool with_day_of_week() throws Error {
        Component.DetailsParser parser = new Component.DetailsParser("dinner Monday at Bob's with Alice", null);
        
        return parser.event.summary == "dinner at Bob's with Alice"
            && parser.event.location == "Bob's with Alice"
            && parser.event.date_span.start_date.day_of_week == Calendar.DayOfWeek.MON;
    }
    
    private bool with_delay() throws Error {
        Component.DetailsParser parser = new Component.DetailsParser("meet Alice in 3 hours", null);
        
        Calendar.WallTime start = Calendar.System.now.to_wall_time().adjust(3, Calendar.TimeUnit.HOUR, null);
        Calendar.WallTime end = start.adjust(1, Calendar.TimeUnit.HOUR, null);
        
        assert(parser.event.summary == "meet Alice");
        assert(parser.event.exact_time_span.start_exact_time.to_wall_time().equal_to(start));
        assert(parser.event.exact_time_span.start_exact_time.to_wall_time().adjust(1, Calendar.TimeUnit.HOUR, null).equal_to(end));
        
        return true;
    }
    
    private bool with_duration() throws Error {
        Component.DetailsParser parser = new Component.DetailsParser("meet Alice for 2 hrs", null);
        
        Calendar.WallTime start = Calendar.System.now.to_wall_time();
        Calendar.WallTime end = start.adjust(2, Calendar.TimeUnit.HOUR, null);
        
        return parser.event.summary == "meet Alice"
            && parser.event.exact_time_span.start_exact_time.to_wall_time().equal_to(start)
            && parser.event.exact_time_span.end_exact_time.to_wall_time().equal_to(end);
    }
    
    private bool with_delay_and_duration() throws Error {
        Component.DetailsParser parser = new Component.DetailsParser("meet Alice in 3 hours for 30 min", null);
        
        Calendar.WallTime start = Calendar.System.now.adjust_time(3, Calendar.TimeUnit.HOUR).to_wall_time();
        Calendar.WallTime end = start.adjust(30, Calendar.TimeUnit.MINUTE, null);
        
        return parser.event.summary == "meet Alice"
            && parser.event.exact_time_span.start_exact_time.to_wall_time().equal_to(start)
            && parser.event.exact_time_span.end_exact_time.to_wall_time().equal_to(end);
    }
    
    private bool indeterminate_time() throws Error {
        Component.DetailsParser parser = new Component.DetailsParser("meet Alice 4", null);
        
        return parser.event.summary == "meet Alice 4"
            && parser.event.exact_time_span == null
            && parser.event.date_span == null;
    }
    
    private bool dialog_example() throws Error {
        Component.DetailsParser parser = new Component.DetailsParser(
            "Dinner at Tadich Grill 7:30pm tomorrow", null);
        
        Calendar.ExactTime time = new Calendar.ExactTime(
            Calendar.System.timezone,
            Calendar.System.today.next(),
            new Calendar.WallTime(19, 30, 0)
        );
        
        return parser.event.summary == "Dinner at Tadich Grill"
            && parser.event.location == "Tadich Grill"
            && parser.event.exact_time_span.start_exact_time.equal_to(time)
            && parser.event.exact_time_span.end_exact_time.equal_to(time.adjust_time(1, Calendar.TimeUnit.HOUR));
    }
    
    private bool noon() throws Error {
        Component.DetailsParser parser = new Component.DetailsParser(
            "Lunch noon to 1:30pm", null);
        
        Calendar.ExactTime start = new Calendar.ExactTime(Calendar.Timezone.local, Calendar.System.today,
            new Calendar.WallTime(12, 0, 0));
        Calendar.ExactTime end = new Calendar.ExactTime(Calendar.Timezone.local, Calendar.System.today,
            new Calendar.WallTime(13, 30, 0));
        
        return parser.event.summary == "Lunch"
            && parser.event.exact_time_span.start_exact_time.equal_to(start)
            && parser.event.exact_time_span.end_exact_time.equal_to(end);
    }
    
    private bool midnight() throws Error {
        Component.DetailsParser parser = new Component.DetailsParser(
            "Dinner 11pm to midnight", null);
        
        Calendar.ExactTime start = new Calendar.ExactTime(Calendar.Timezone.local, Calendar.System.today,
            new Calendar.WallTime(23, 0, 0));
        Calendar.ExactTime end = new Calendar.ExactTime(Calendar.Timezone.local, Calendar.System.today.next(),
            new Calendar.WallTime(0, 0, 0));
        
        return parser.event.summary == "Dinner"
            && parser.event.exact_time_span.start_exact_time.equal_to(start)
            && parser.event.exact_time_span.end_exact_time.equal_to(end);
    }
    
    private bool pm1230() throws Error {
        Component.DetailsParser parser = new Component.DetailsParser(
            "12:30pm Friday Lunch with Eric and Charles", null);
        
        Calendar.Date friday = Calendar.System.today.upcoming(true,
            date => date.day_of_week.equal_to(Calendar.DayOfWeek.FRI));
        
        Calendar.ExactTime start = new Calendar.ExactTime(Calendar.Timezone.local, friday,
            new Calendar.WallTime(12, 30, 0));
        Calendar.ExactTime end = new Calendar.ExactTime(Calendar.Timezone.local, friday,
            new Calendar.WallTime(13, 30, 0));
        
        return parser.event.summary == "Lunch with Eric and Charles"
            && parser.event.exact_time_span.start_exact_time.equal_to(start)
            && parser.event.exact_time_span.end_exact_time.equal_to(end);
    }
    
    private bool bogus_time() throws Error {
        Component.DetailsParser parser = new Component.DetailsParser(
            "Dinner 25:00", null);
        
        return parser.event.summary == "Dinner 25:00"
            && parser.event.exact_time_span == null
            && parser.event.date_span == null;
    }
    
    private bool zero_hour() throws Error {
        Component.DetailsParser parser = new Component.DetailsParser(
            "Dinner 00:00", null);
        
        Calendar.ExactTime start = new Calendar.ExactTime(Calendar.Timezone.local, Calendar.System.today.next(),
            new Calendar.WallTime(0, 0, 0));
        Calendar.ExactTime end = new Calendar.ExactTime(Calendar.Timezone.local, Calendar.System.today.next(),
            new Calendar.WallTime(1, 0, 0));
        
        return parser.event.summary == "Dinner"
            && parser.event.exact_time_span.start_exact_time.equal_to(start)
            && parser.event.exact_time_span.end_exact_time.equal_to(end);
    }
    
    private bool oh_twenty_four_hours() throws Error {
        Component.DetailsParser parser = new Component.DetailsParser(
            "Dinner 24:00", null);
        
        Calendar.ExactTime start = new Calendar.ExactTime(Calendar.Timezone.local, Calendar.System.today.next(),
            new Calendar.WallTime(0, 0, 0));
        Calendar.ExactTime end = new Calendar.ExactTime(Calendar.Timezone.local, Calendar.System.today.next(),
            new Calendar.WallTime(1, 0, 0));
        
        return parser.event.summary == "Dinner"
            && parser.event.exact_time_span.start_exact_time.equal_to(start)
            && parser.event.exact_time_span.end_exact_time.equal_to(end);
    }
    
    private bool midnight_to_one() throws Error {
        Component.DetailsParser parser = new Component.DetailsParser(
            "Dinner midnight to 1am", null);
        
        Calendar.ExactTime start = new Calendar.ExactTime(Calendar.Timezone.local, Calendar.System.today.next(),
            new Calendar.WallTime(0, 0, 0));
        Calendar.ExactTime end = new Calendar.ExactTime(Calendar.Timezone.local, Calendar.System.today.next(),
            new Calendar.WallTime(1, 0, 0));
        
        return parser.event.summary == "Dinner"
            && parser.event.exact_time_span.start_exact_time.equal_to(start)
            && parser.event.exact_time_span.end_exact_time.equal_to(end);
    }
    
    private bool separate_am() throws Error {
        Component.DetailsParser parser = new Component.DetailsParser(
            "Dinner at 1 pm with Denny", null);
        
        Calendar.ExactTime start = new Calendar.ExactTime(Calendar.Timezone.local, Calendar.System.today,
            new Calendar.WallTime(13, 0, 0));
        
        return parser.event.summary == "Dinner with Denny"
            && parser.event.exact_time_span.start_exact_time.equal_to(start);
    }
    
    private bool separate_pm() throws Error {
        Component.DetailsParser parser = new Component.DetailsParser(
            "Dinner at 11 am", null);
        
        Calendar.ExactTime start = new Calendar.ExactTime(Calendar.Timezone.local, Calendar.System.today,
            new Calendar.WallTime(11, 0, 0));
        
        return parser.event.summary == "Dinner"
            && parser.event.exact_time_span.start_exact_time.equal_to(start);
    }
    
    private bool start_date_ordinal() throws Error {
        Component.DetailsParser parser = new Component.DetailsParser(
            "Dinner May 1st", null);
        
        Calendar.Date start = new Calendar.Date(Calendar.DayOfMonth.for(1), Calendar.Month.MAY,
            Calendar.System.today.year);
        
        return parser.event.summary == "Dinner"
            && parser.event.date_span.start_date.equal_to(start);
    }
    
    private bool end_date_ordinal(out string? dump) throws Error {
        Component.DetailsParser parser = new Component.DetailsParser(
            "Off-site May 1st to May 2nd", null);
        
        dump = parser.event.source;
        
        Calendar.Date start = new Calendar.Date(Calendar.DayOfMonth.for(1), Calendar.Month.MAY,
            Calendar.System.today.year);
        Calendar.Date end = new Calendar.Date(Calendar.DayOfMonth.for(2), Calendar.Month.MAY,
            Calendar.System.today.year);
        
        return parser.event.summary == "Off-site"
            && parser.event.date_span.start_date.equal_to(start)
            && parser.event.date_span.end_date.equal_to(end);
    }
    
    private bool simple_and(out string? dump) throws Error {
        Component.DetailsParser parser = new Component.DetailsParser(
            "Manga & Anime Festival Saturday and Sunday at Airport Hyatt, Shelbyville", null);
        
        dump = parser.event.source;
        
        return parser.event.summary == "Manga & Anime Festival at Airport Hyatt, Shelbyville"
            && parser.event.location == "Airport Hyatt, Shelbyville"
            && parser.event.is_all_day
            && parser.event.date_span.start_date.day_of_week == Calendar.DayOfWeek.SAT
            && parser.event.date_span.end_date.day_of_week == Calendar.DayOfWeek.SUN;
    }
    
    private bool this_weekend(out string? dump) throws Error {
        Component.DetailsParser parser = new Component.DetailsParser(
            "Manga & Anime Festival this weekend at Airport Hyatt, Shelbyville", null);
        
        dump = parser.event.source;
        
        return parser.event.summary == "Manga & Anime Festival at Airport Hyatt, Shelbyville"
            && parser.event.location == "Airport Hyatt, Shelbyville"
            && parser.event.is_all_day
            && parser.event.date_span.start_date.day_of_week == Calendar.DayOfWeek.SAT
            && parser.event.date_span.end_date.day_of_week == Calendar.DayOfWeek.SUN;
    }
}

}


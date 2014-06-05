/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Tests {

private class QuickAdd : UnitTest.Harness {
    public QuickAdd() {
        add_case("summary", summary);
        add_case("summary-location", summary_location);
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
    }
    
    protected override void setup() throws Error {
        Component.init();
        Calendar.init();
    }
    
    protected override void teardown() {
        Component.terminate();
        Calendar.terminate();
    }
    
    private bool summary() throws Error {
        Component.DetailsParser parser = new Component.DetailsParser("meet with Alice", null);
        
        return parser.event.summary == "meet with Alice"
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
        
        Calendar.Date friday = Calendar.System.today.upcoming(Calendar.DayOfWeek.FRI, true);
        
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
}

}


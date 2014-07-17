/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Tests {

/**
 * Note that some tests are repeated with different days of the week to avoid false positives when
 * the current day of the week (at time of execution) matches quick-add details.
 */

private class QuickAddRecurring : UnitTest.Harness {
    public QuickAddRecurring() {
        // ByRule.DAY encoding/decoding tests
        add_case("encode-decode-day-every-week", encode_decode_day_every_week);
        add_case("encode-decode-day-every-month", encode_decode_day_every_month);
        add_case("encode-decode-days-every-week", encode_decode_days_every_week);
        add_case("encode-decode-days-every-month", encode_decode_days_every_month);
        add_case("encode-decode-all", encode_decode_all);
        add_case("encode-decode-all_negative", encode_decode_all_negative);
        
        // DAILY tests
        add_case("every-day", every_day);
        add_case("all-day", all_day);
        add_case("daily", daily);
        add_case("every-day-10-days", every_day_10_days);
        add_case("every-2-days", every_2_days);
        add_case("every-3rd-day", every_3rd_day);
        add_case("every-2-days-for-10-days", every_2_days_for_10_days);
        add_case("every-2-days-until", every_2_days_until);
        
        // WEEKLY
        add_case("every-tuesday", every_tuesday);
        add_case("every-friday", every_friday);
        add_case("every-saturday-until", every_saturday_until);
        add_case("all-day-saturday-until", all_day_saturday_until);
        add_case("weekly-meeting-monday", weekly_meeting_monday);
        add_case("weekly-meeting-tuesday", weekly_meeting_tuesday);
        add_case("tuesday_weekly", tuesday_weekly);
        add_case("thursday-weekly", thursday_weekly);
        add_case("weekdays_to_1pm", weekdays_to_1pm);
        add_case("weekends", weekends);
        add_case("every_weekend", every_weekend);
        add_case("every-tuesday-thursday", every_tuesday_thursday);
        add_case("every-tuesday-and-thursday", every_tuesday_and_thursday);
        add_case("every-tuesday-and-thursday-for-3-weeks", every_tuesday_and_thursday_for_3_weeks);
        
        // MONTHLY
        add_case("every-first-tuesday", every_first_tuesday);
        add_case("every-first-tuesday-for-3-weeks", every_first_tuesday_for_3_weeks);
        add_case("every-second-sunday-until", every_second_sunday_until);
        add_case("every-sixth-tuesday", every_sixth_tuesday);
        
        // YEARLY
        add_case("every-july-4th", every_july_4th);
        add_case("every-july-15th", every_july_15th);
        add_case("every-4th-july", every_4th_july);
        add_case("every-15th-july", every_15th_july);
        add_case("july-4th-yearly", july_4th_yearly);
        add_case("july-15th-yearly", july_15th_yearly);
        add_case("yearly-july-4th", yearly_july_4th);
        add_case("yearly-july-15th", yearly_july_15th);
        add_case("yearly-meeting-july-4th", yearly_meeting_july_4th);
        add_case("yearly-meeting-july-15th", yearly_meeting_july_15th);
        add_case("meeting-every-july-4th-15th", meeting_every_july_4th_15th);
        add_case("every-july-4th-3-years", every_july_4th_3_years);
        add_case("every-aug-1st-until", every_aug_1st_until);
    }
    
    protected override void setup() throws Error {
        Component.init();
        Calendar.init();
    }
    
    protected override void teardown() {
        Component.terminate();
        Calendar.terminate();
    }
    
    private bool encode_decode_day_every_week(out string? dump) throws Error {
        int value = Component.RecurrenceRule.encode_day(Calendar.DayOfWeek.THU, 0);
        
        dump = "THU 0 -> %d".printf(value);
        
        Calendar.DayOfWeek? dow;
        int position;
        return Component.RecurrenceRule.decode_day(value, out dow, out position)
            && dow != null
            && dow.equal_to(Calendar.DayOfWeek.THU)
            && position == 0;
    }
    
    private bool encode_decode_day_every_month(out string? dump) throws Error {
        int value = Component.RecurrenceRule.encode_day(Calendar.DayOfWeek.MON, 3);
        
        dump = "MON 3 -> %d".printf(value);
        
        Calendar.DayOfWeek? dow;
        int position;
        return Component.RecurrenceRule.decode_day(value, out dow, out position)
            && dow != null
            && dow.equal_to(Calendar.DayOfWeek.MON)
            && position == 3;
    }
    
    private bool encode_decode_days_every_week(out string? dump) throws Error {
        Gee.Collection<int> values = Component.RecurrenceRule.encode_days(
            iterate<Calendar.DayOfWeek?>(Calendar.DayOfWeek.TUE, Calendar.DayOfWeek.THU).to_hash_map_as_keys<int>(dow => 0));
        Gee.Map<Calendar.DayOfWeek?, int> dows = Component.RecurrenceRule.decode_days(values);
        
        dump = "values.size=%d size=%d".printf(values.size, dows.size);
        
        return dows.size == 2
            && dows.contains(Calendar.DayOfWeek.TUE)
            && dows.contains(Calendar.DayOfWeek.THU)
            && dows[Calendar.DayOfWeek.TUE] == 0
            && dows[Calendar.DayOfWeek.THU] == 0;
    }
    
    private bool encode_decode_days_every_month(out string? dump) throws Error {
        int iter = 1;
        Gee.Collection<int> values = Component.RecurrenceRule.encode_days(
            iterate<Calendar.DayOfWeek?>(Calendar.DayOfWeek.MON, Calendar.DayOfWeek.WED).to_hash_map_as_keys<int>(dow => iter++));
        Gee.Map<Calendar.DayOfWeek?, int> dows = Component.RecurrenceRule.decode_days(values);
        
        dump = "values.size=%d size=%d".printf(values.size, dows.size);
        
        return dows.size == 2
            && dows.contains(Calendar.DayOfWeek.MON)
            && dows.contains(Calendar.DayOfWeek.WED)
            && dows[Calendar.DayOfWeek.MON] == 1
            && dows[Calendar.DayOfWeek.WED] == 2;
    }
    
    private bool encode_decode_all() throws Error {
        Gee.Collection<Calendar.DayOfWeek> all =
            from_array<Calendar.DayOfWeek?>(Calendar.DayOfWeek.all(Calendar.FirstOfWeek.SUNDAY)).to_array_list();
        
        int iter = 0;
        Gee.Collection<int> values = Component.RecurrenceRule.encode_days(
            traverse<Calendar.DayOfWeek>(all).to_hash_map_as_keys<int>(dow => iter++));
        Gee.Map<Calendar.DayOfWeek?, int> dows = Component.RecurrenceRule.decode_days(values);
        
        return dows.size == 7
            && dows.has_key(Calendar.DayOfWeek.SUN)
            && dows[Calendar.DayOfWeek.SUN] == 0
            && dows[Calendar.DayOfWeek.MON] == 1
            && dows[Calendar.DayOfWeek.TUE] == 2
            && dows[Calendar.DayOfWeek.WED] == 3
            && dows[Calendar.DayOfWeek.THU] == 4
            && dows[Calendar.DayOfWeek.FRI] == 5
            && dows[Calendar.DayOfWeek.SAT] == 6;
    }
    
    private bool encode_decode_all_negative() throws Error {
        Gee.Collection<Calendar.DayOfWeek> all =
            from_array<Calendar.DayOfWeek?>(Calendar.DayOfWeek.all(Calendar.FirstOfWeek.SUNDAY)).to_array_list();
        
        int iter = -1;
        Gee.Collection<int> values = Component.RecurrenceRule.encode_days(
            traverse<Calendar.DayOfWeek>(all).to_hash_map_as_keys<int>(dow => iter--));
        Gee.Map<Calendar.DayOfWeek?, int> dows = Component.RecurrenceRule.decode_days(values);
        
        return dows.size == 7
            && dows.has_key(Calendar.DayOfWeek.SUN)
            && dows[Calendar.DayOfWeek.SUN] == -1
            && dows[Calendar.DayOfWeek.MON] == -2
            && dows[Calendar.DayOfWeek.TUE] == -3
            && dows[Calendar.DayOfWeek.WED] == -4
            && dows[Calendar.DayOfWeek.THU] == -5
            && dows[Calendar.DayOfWeek.FRI] == -6
            && dows[Calendar.DayOfWeek.SAT] == -7;
    }
    
    // Checks that an RRULE was generated,
    // the summary is       meeting at work
    // the location is      work
    // the start time is    10am
    private bool basic(string details, out Component.Event event, out string? dump) {
        Component.DetailsParser parser = new Component.DetailsParser(details, null);
        event = parser.event;
        
        dump = "%s\n%s".printf(details, event.source);
        
        return event.rrule != null
            && event.summary == "meeting at work"
            && event.location == "work"
            && !event.is_all_day
            && event.exact_time_span.start_exact_time.to_wall_time().equal_to(new Calendar.WallTime(10, 0, 0));
    }
    
    // Checks that an RRULE was generated,
    // the summary is       meeting at work
    // the location is      work
    // is all day
    private bool multiday(string details, out Component.Event event, out string? dump) {
        Component.DetailsParser parser = new Component.DetailsParser(details, null);
        event = parser.event;
        
        dump = "%s\n%s".printf(details, event.source);
        
        return event.rrule != null
            && event.summary == "meeting at work"
            && event.location == "work"
            && event.is_all_day;
    }
    
    //
    // DAILY
    //
    
    private bool every_day(out string? dump) throws Error {
        Component.Event event;
        return basic("meeting at work every day at 10am", out event, out dump)
            && event.rrule.is_daily
            && event.rrule.interval == 1
            && !event.rrule.has_duration;
    }
    
    private bool all_day(out string? dump) throws Error {
        Component.Event event;
        return multiday("meeting at work every day", out event, out dump)
            && event.rrule.is_daily
            && event.rrule.interval == 1
            && !event.rrule.has_duration;
    }
    
    private bool daily(out string? dump) throws Error {
        Component.Event event;
        return basic("meeting at work daily at 10am", out event, out dump)
            && event.rrule.is_daily
            && event.rrule.interval == 1
            && !event.rrule.has_duration;
    }
    
    private bool every_day_10_days(out string? dump) throws Error {
        Component.Event event;
        return basic("meeting at work every day at 10am for 10 days", out event, out dump)
            && event.rrule.is_daily
            && event.rrule.interval == 1
            && event.rrule.count == 10;
    }
    
    private bool every_2_days(out string? dump) throws Error {
        Component.Event event;
        return basic("meeting at 10am every 2 days at work", out event, out dump)
            && event.rrule.is_daily
            && event.rrule.interval == 2
            && !event.rrule.has_duration;
    }
    
    private bool every_3rd_day(out string? dump) throws Error {
        Component.Event event;
        return basic("meeting at 10am every 3rd day at work", out event, out dump)
            && event.rrule.is_daily
            && event.rrule.interval == 3
            && !event.rrule.has_duration;
    }
    
    private bool every_2_days_for_10_days(out string? dump) throws Error {
        Component.Event event;
        return basic("meeting at work every 2 days for 10 days at 10am", out event, out dump)
            && event.rrule.is_daily
            && event.rrule.interval == 2
            && event.rrule.count == 10;
    }
    
    private bool every_2_days_until(out string? dump) throws Error {
        Calendar.Date end = new Calendar.Date(Calendar.DayOfMonth.for(31), Calendar.Month.DEC,
            Calendar.System.today.year);
        
        Component.Event event;
        return basic("meeting at work at 10am every 2 days until December 31", out event, out dump)
            && event.rrule.is_daily
            && event.rrule.interval == 2
            && event.rrule.until_date != null
            && event.rrule.until_date.equal_to(end);
    }
    
    //
    // WEEKLY
    //
    
    private bool check_byrule_day(Component.Event event, Gee.Map<Calendar.DayOfWeek?, int> by_days) {
        Gee.SortedSet<int> values = event.rrule.get_by_rule(Component.RecurrenceRule.ByRule.DAY);
        if (values.size != by_days.size)
            return false;
        
        foreach (int value in values) {
            Calendar.DayOfWeek? dow;
            int position;
            if (!Component.RecurrenceRule.decode_day(value, out dow, out position))
                return false;
            
            if (!by_days.has_key(dow) || by_days.get(dow) != position)
                return false;
        }
        
        return true;
    }
    
    private bool every_tuesday(out string? dump) throws Error {
        Gee.Map<Calendar.DayOfWeek?, int> by_days = iterate<Calendar.DayOfWeek?>(
            Calendar.DayOfWeek.TUE).to_hash_map_as_keys<int>(dow => 0);
        
        Component.Event event;
        return basic("meeting at work at 10am every tuesday", out event, out dump)
            && event.rrule.is_weekly
            && event.rrule.interval == 1
            && !event.rrule.has_duration
            && event.exact_time_span.start_date.day_of_week.equal_to(Calendar.DayOfWeek.TUE)
            && check_byrule_day(event, by_days);
    }
    
    private bool every_friday(out string? dump) throws Error {
        Gee.Map<Calendar.DayOfWeek?, int> by_days = iterate<Calendar.DayOfWeek?>(
            Calendar.DayOfWeek.FRI).to_hash_map_as_keys<int>(dow => 0);
        
        Component.Event event;
        return basic("meeting at work at 10am every friday", out event, out dump)
            && event.rrule.is_weekly
            && event.rrule.interval == 1
            && !event.rrule.has_duration
            && event.exact_time_span.start_date.day_of_week.equal_to(Calendar.DayOfWeek.FRI)
            && check_byrule_day(event, by_days);
    }
    
    private bool every_saturday_until(out string? dump) throws Error {
        Gee.Map<Calendar.DayOfWeek?, int> by_days = iterate<Calendar.DayOfWeek?>(
            Calendar.DayOfWeek.SAT).to_hash_map_as_keys<int>(dow => 0);
        
        Component.Event event;
        return basic("meeting at work at 10am every saturday until dec 31", out event, out dump)
            && event.rrule.is_weekly
            && event.rrule.interval == 1
            && event.rrule.until_date != null
            && event.rrule.until_date.equal_to(new Calendar.Date(Calendar.DayOfMonth.for(31),
                Calendar.Month.DEC, Calendar.System.today.year))
            && event.exact_time_span.start_date.day_of_week.equal_to(Calendar.DayOfWeek.SAT)
            && check_byrule_day(event, by_days)
            && event.exact_time_span.end_date.equal_to(event.exact_time_span.start_date);
    }
    
    private bool all_day_saturday_until(out string? dump) throws Error {
        Gee.Map<Calendar.DayOfWeek?, int> by_days = iterate<Calendar.DayOfWeek?>(
            Calendar.DayOfWeek.SAT).to_hash_map_as_keys<int>(dow => 0);
        
        Component.Event event;
        return multiday("meeting at work every saturday until dec 31", out event, out dump)
            && event.rrule.is_weekly
            && event.rrule.interval == 1
            && event.rrule.until_date != null
            && event.rrule.until_date.equal_to(new Calendar.Date(Calendar.DayOfMonth.for(31),
                Calendar.Month.DEC, Calendar.System.today.year))
            && event.date_span.start_date.day_of_week.equal_to(Calendar.DayOfWeek.SAT)
            && check_byrule_day(event, by_days)
            && event.date_span.end_date.equal_to(event.date_span.start_date);
    }
    
    private bool weekly_meeting_monday(out string? dump) throws Error {
        Gee.Map<Calendar.DayOfWeek?, int> by_days = iterate<Calendar.DayOfWeek?>(
            Calendar.DayOfWeek.MON).to_hash_map_as_keys<int>(dow => 0);
        
        Component.Event event;
        return basic("weekly meeting at work monday at 10am", out event, out dump)
            && event.rrule.is_weekly
            && event.rrule.interval == 1
            && !event.rrule.has_duration
            && event.exact_time_span.start_date.day_of_week.equal_to(Calendar.DayOfWeek.MON)
            && check_byrule_day(event, by_days);
    }
    
    private bool weekly_meeting_tuesday(out string? dump) throws Error {
        Gee.Map<Calendar.DayOfWeek?, int> by_days = iterate<Calendar.DayOfWeek?>(
            Calendar.DayOfWeek.TUE).to_hash_map_as_keys<int>(dow => 0);
        
        Component.Event event;
        return basic("weekly meeting at work tuesday at 10am", out event, out dump)
            && event.rrule.is_weekly
            && event.rrule.interval == 1
            && !event.rrule.has_duration
            && event.exact_time_span.start_date.day_of_week.equal_to(Calendar.DayOfWeek.TUE)
            && check_byrule_day(event, by_days);
    }
    
    private bool tuesday_weekly(out string? dump) throws Error {
        Gee.Map<Calendar.DayOfWeek?, int> by_days = iterate<Calendar.DayOfWeek?>(
            Calendar.DayOfWeek.TUE).to_hash_map_as_keys<int>(dow => 0);
        
        Component.Event event;
        return basic("meeting at work tuesday at 10am weekly", out event, out dump)
            && event.rrule.is_weekly
            && event.rrule.interval == 1
            && !event.rrule.has_duration
            && event.exact_time_span.start_date.day_of_week.equal_to(Calendar.DayOfWeek.TUE)
            && check_byrule_day(event, by_days);
    }
    
    private bool thursday_weekly(out string? dump) throws Error {
        Gee.Map<Calendar.DayOfWeek?, int> by_days = iterate<Calendar.DayOfWeek?>(
            Calendar.DayOfWeek.THU).to_hash_map_as_keys<int>(dow => 0);
        
        Component.Event event;
        return basic("meeting at work thursday at 10am weekly", out event, out dump)
            && event.rrule.is_weekly
            && event.rrule.interval == 1
            && !event.rrule.has_duration
            && event.exact_time_span.start_date.day_of_week.equal_to(Calendar.DayOfWeek.THU)
            && check_byrule_day(event, by_days);
    }
    
    private bool weekdays_to_1pm(out string? dump) throws Error {
        Gee.Map<Calendar.DayOfWeek?, int> by_days = from_array<Calendar.DayOfWeek?>(
            Calendar.DayOfWeek.weekdays).to_hash_map_as_keys<int>(dow => 0);
        
        Component.Event event;
        return basic("meeting at work weekdays from 10am to 1pm", out event, out dump)
            && event.rrule.is_weekly
            && event.rrule.interval == 1
            && !event.rrule.has_duration
            && by_days.keys.contains(event.exact_time_span.start_date.day_of_week)
            && event.exact_time_span.end_exact_time.to_wall_time().equal_to(new Calendar.WallTime(13, 0, 0))
            && check_byrule_day(event, by_days);
    }
    
    private bool weekends(out string? dump) throws Error {
        Gee.Map<Calendar.DayOfWeek?, int> by_days = from_array<Calendar.DayOfWeek?>(
            Calendar.DayOfWeek.weekend_days).to_hash_map_as_keys<int>(dow => 0);
        
        Component.Event event;
        return basic("meeting weekends at work at 10am", out event, out dump)
            && event.rrule.is_weekly
            && event.rrule.interval == 1
            && !event.rrule.has_duration
            && by_days.keys.contains(event.exact_time_span.start_date.day_of_week)
            && check_byrule_day(event, by_days);
    }
    
    private bool every_weekend(out string? dump) throws Error {
        Gee.Map<Calendar.DayOfWeek?, int> by_days = from_array<Calendar.DayOfWeek?>(
            Calendar.DayOfWeek.weekend_days).to_hash_map_as_keys<int>(dow => 0);
        
        Component.Event event;
        return basic("meeting at work every weekend at 10am", out event, out dump)
            && event.rrule.is_weekly
            && event.rrule.interval == 1
            && !event.rrule.has_duration
            && by_days.keys.contains(event.exact_time_span.start_date.day_of_week)
            && check_byrule_day(event, by_days);
    }
    
    private bool every_tuesday_thursday(out string? dump) throws Error {
        Gee.Map<Calendar.DayOfWeek?, int> by_days = iterate<Calendar.DayOfWeek?>(
            Calendar.DayOfWeek.TUE, Calendar.DayOfWeek.THU).to_hash_map_as_keys<int>(dow => 0);
        
        Component.Event event;
        return basic("meeting at work at 10am every tuesday, thursday", out event, out dump)
            && event.rrule.is_weekly
            && event.rrule.interval == 1
            && !event.rrule.has_duration
            && (event.exact_time_span.start_date.day_of_week.equal_to(Calendar.DayOfWeek.TUE)
                || event.exact_time_span.start_date.day_of_week.equal_to(Calendar.DayOfWeek.THU))
            && check_byrule_day(event, by_days);
    }
    
    private bool every_tuesday_and_thursday(out string? dump) throws Error {
        Gee.Map<Calendar.DayOfWeek?, int> by_days = iterate<Calendar.DayOfWeek?>(
            Calendar.DayOfWeek.TUE, Calendar.DayOfWeek.THU).to_hash_map_as_keys<int>(dow => 0);
        
        Component.Event event;
        return basic("meeting at work at 10am every tuesday and thursday", out event, out dump)
            && event.rrule.is_weekly
            && event.rrule.interval == 1
            && !event.rrule.has_duration
            && (event.exact_time_span.start_date.day_of_week.equal_to(Calendar.DayOfWeek.TUE)
                || event.exact_time_span.start_date.day_of_week.equal_to(Calendar.DayOfWeek.THU))
            && check_byrule_day(event, by_days);
    }
    
    private bool every_tuesday_and_thursday_for_3_weeks(out string? dump) throws Error {
        Gee.Map<Calendar.DayOfWeek?, int> by_days = iterate<Calendar.DayOfWeek?>(
            Calendar.DayOfWeek.TUE, Calendar.DayOfWeek.THU).to_hash_map_as_keys<int>(dow => 0);
        
        Component.Event event;
        return basic("meeting at work at 10am every tuesday and thursday for 3 weeks", out event, out dump)
            && event.rrule.is_weekly
            && event.rrule.interval == 1
            && (event.exact_time_span.start_date.day_of_week.equal_to(Calendar.DayOfWeek.TUE)
                || event.exact_time_span.start_date.day_of_week.equal_to(Calendar.DayOfWeek.THU))
            && check_byrule_day(event, by_days)
            && event.rrule.count == 3;
    }
    
    //
    // MONTHLY
    //
    
    private bool every_first_tuesday(out string? dump) throws Error {
        Gee.Map<Calendar.DayOfWeek?, int> by_days = iterate<Calendar.DayOfWeek?>(
            Calendar.DayOfWeek.TUE).to_hash_map_as_keys<int>(dow => 1);
        
        Component.Event event;
        return basic("meeting at work at 10am every 1st tuesday", out event, out dump)
            && event.rrule.is_monthly
            && event.rrule.interval == 1
            && !event.rrule.has_duration
            && event.exact_time_span.start_date.day_of_week.equal_to(Calendar.DayOfWeek.TUE)
            && event.exact_time_span.start_date.day_of_month.value <= 7
            && check_byrule_day(event, by_days);
    }
    
    private bool every_first_tuesday_for_3_weeks(out string? dump) throws Error {
        Gee.Map<Calendar.DayOfWeek?, int> by_days = iterate<Calendar.DayOfWeek?>(
            Calendar.DayOfWeek.TUE).to_hash_map_as_keys<int>(dow => 1);
        
        Component.Event event;
        return basic("meeting at work at 10am every 1st tuesday for 3 months", out event, out dump)
            && event.rrule.is_monthly
            && event.rrule.interval == 1
            && event.rrule.count == 3
            && event.exact_time_span.start_date.day_of_week.equal_to(Calendar.DayOfWeek.TUE)
            && event.exact_time_span.start_date.day_of_month.value <= 7
            && check_byrule_day(event, by_days);
    }
    
    private bool every_second_sunday_until(out string? dump) throws Error {
        Gee.Map<Calendar.DayOfWeek?, int> by_days = iterate<Calendar.DayOfWeek?>(
            Calendar.DayOfWeek.SUN).to_hash_map_as_keys<int>(dow => 2);
        
        Component.Event event;
        return basic("meeting at work at 10am every 2nd sunday until august 1st", out event, out dump)
            && event.rrule.is_monthly
            && event.rrule.interval == 1
            && event.rrule.until_date != null
            && event.rrule.until_date.month == Calendar.Month.AUG
            && event.rrule.until_date.day_of_month.value == 1
            && event.rrule.until_date.year.compare_to(Calendar.System.today.year) >= 0
            && event.exact_time_span.start_date.day_of_week.equal_to(Calendar.DayOfWeek.SUN)
            && event.exact_time_span.start_date.day_of_month.value >= 7
            && event.exact_time_span.start_date.day_of_month.value <= 14
            && check_byrule_day(event, by_days);
    }
    
    // bad input
    private bool every_sixth_tuesday(out string? dump) throws Error {
        Component.DetailsParser parser = new Component.DetailsParser(
            "meeting at work at 10am every 6th tuesday", null);
        Component.Event event = parser.event;
        
        dump = event.source;
        
        return event.rrule == null
            && event.summary == "meeting at work every 6th";
    }
    
    //
    // YEARLY
    //
    
    private bool check_byrule_yearday(Component.Event event, Gee.Collection<int> by_yeardays) {
        Gee.SortedSet<int> values = event.rrule.get_by_rule(Component.RecurrenceRule.ByRule.YEAR_DAY);
        if (values.size != by_yeardays.size)
            return false;
        
        return traverse<int>(by_yeardays).all(yearday => values.contains(yearday));
    }
    
    private bool every_july_4th(out string? dump) throws Error {
        Component.Event event;
        return basic("meeting at work at 10am every july 4th", out event, out dump)
            && event.rrule.is_yearly
            && event.rrule.interval == 1
            && !event.rrule.has_duration
            && event.exact_time_span.start_date.month == Calendar.Month.JUL
            && event.exact_time_span.start_date.day_of_month.value == 4;
    }
    
    private bool every_july_15th(out string? dump) throws Error {
        Component.Event event;
        return basic("meeting at work at 10am every july 15th", out event, out dump)
            && event.rrule.is_yearly
            && event.rrule.interval == 1
            && !event.rrule.has_duration
            && event.exact_time_span.start_date.month == Calendar.Month.JUL
            && event.exact_time_span.start_date.day_of_month.value == 15;
    }
    
    private bool every_4th_july(out string? dump) throws Error {
        Component.Event event;
        return basic("meeting at work at 10am every 4th july", out event, out dump)
            && event.rrule.is_yearly
            && event.rrule.interval == 1
            && !event.rrule.has_duration
            && event.exact_time_span.start_date.month == Calendar.Month.JUL
            && event.exact_time_span.start_date.day_of_month.value == 4;
    }
    
    private bool every_15th_july(out string? dump) throws Error {
        Component.Event event;
        return basic("meeting at work at 10am every 15th july", out event, out dump)
            && event.rrule.is_yearly
            && event.rrule.interval == 1
            && !event.rrule.has_duration
            && event.exact_time_span.start_date.month == Calendar.Month.JUL
            && event.exact_time_span.start_date.day_of_month.value == 15;
    }
    
    private bool july_4th_yearly(out string? dump) throws Error {
        Component.Event event;
        return basic("meeting at work july 4th 10am yearly", out event, out dump)
            && event.rrule.is_yearly
            && event.rrule.interval == 1
            && !event.rrule.has_duration
            && event.exact_time_span.start_date.month == Calendar.Month.JUL
            && event.exact_time_span.start_date.day_of_month.value == 4;
    }
    
    private bool july_15th_yearly(out string? dump) throws Error {
        Component.Event event;
        return basic("meeting at work july 15th 10am yearly", out event, out dump)
            && event.rrule.is_yearly
            && event.rrule.interval == 1
            && !event.rrule.has_duration
            && event.exact_time_span.start_date.month == Calendar.Month.JUL
            && event.exact_time_span.start_date.day_of_month.value == 15;
    }
    
    private bool yearly_july_4th(out string? dump) throws Error {
        Component.Event event;
        return basic("meeting at work yearly july 4th 10am", out event, out dump)
            && event.rrule.is_yearly
            && event.rrule.interval == 1
            && !event.rrule.has_duration
            && event.exact_time_span.start_date.month == Calendar.Month.JUL
            && event.exact_time_span.start_date.day_of_month.value == 4;
    }
    
    private bool yearly_july_15th(out string? dump) throws Error {
        Component.Event event;
        return basic("meeting at work yearly july 15th 10am", out event, out dump)
            && event.rrule.is_yearly
            && event.rrule.interval == 1
            && !event.rrule.has_duration
            && event.exact_time_span.start_date.month == Calendar.Month.JUL
            && event.exact_time_span.start_date.day_of_month.value == 15;
    }
    
    private bool yearly_meeting_july_4th(out string? dump) throws Error {
        Component.Event event;
        return basic("yearly meeting at work july 4th 10am", out event, out dump)
            && event.rrule.is_yearly
            && event.rrule.interval == 1
            && !event.rrule.has_duration
            && event.exact_time_span.start_date.month == Calendar.Month.JUL
            && event.exact_time_span.start_date.day_of_month.value == 4;
    }
    
    private bool yearly_meeting_july_15th(out string? dump) throws Error {
        Component.Event event;
        return basic("yearly meeting at work july 15th 10am", out event, out dump)
            && event.rrule.is_yearly
            && event.rrule.interval == 1
            && !event.rrule.has_duration
            && event.exact_time_span.start_date.month == Calendar.Month.JUL
            && event.exact_time_span.start_date.day_of_month.value == 15;
    }
    
    private bool meeting_every_july_4th_15th(out string? dump) throws Error {
        Calendar.Date july4 = new Calendar.Date(Calendar.DayOfMonth.for(4), Calendar.Month.JUL,
            Calendar.System.today.year);
        Calendar.Date july15 = new Calendar.Date(Calendar.DayOfMonth.for(15), Calendar.Month.JUL,
            Calendar.System.today.year);
        
        Component.Event event;
        return basic("meeting every july 4th and july 15 10am at work", out event, out dump)
            && event.rrule.is_yearly
            && event.rrule.interval == 1
            && !event.rrule.has_duration
            && event.exact_time_span.start_date.month == Calendar.Month.JUL
            && (event.exact_time_span.start_date.day_of_month.value == 15
                || event.exact_time_span.start_date.day_of_month.value == 4)
            && event.exact_time_span.start_date.equal_to(event.exact_time_span.end_date)
            && check_byrule_yearday(event, iterate<Calendar.Date>(july4, july15).map<int>(d => d.day_of_year).to_array_list());
    }
    
    private bool every_july_4th_3_years(out string? dump) throws Error {
        Component.Event event;
        return basic("meeting at work at 10am every july 4th for 3 years", out event, out dump)
            && event.rrule.is_yearly
            && event.rrule.interval == 1
            && event.rrule.count == 3
            && event.exact_time_span.start_date.month == Calendar.Month.JUL
            && event.exact_time_span.start_date.day_of_month.value == 4;
    }
    
    private bool every_aug_1st_until(out string? dump) throws Error {
        Component.Event event;
        return multiday("meeting at work aug 15 yearly until sep 1", out event, out dump)
            && event.rrule.is_yearly
            && event.rrule.interval == 1
            && event.rrule.until_date != null
            && event.rrule.until_date.month == Calendar.Month.SEP
            && event.rrule.until_date.day_of_month.value == 1
            && event.rrule.until_date.year.compare_to(Calendar.System.today.year) >= 0
            && event.date_span.start_date.month == Calendar.Month.AUG
            && event.date_span.start_date.day_of_month.value == 15
            && event.date_span.start_date.year.compare_to(Calendar.System.today.year) >= 0
            && event.date_span.end_date.equal_to(event.date_span.start_date);
    }
}

}


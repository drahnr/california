/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Component {

/**
 * An immutable representation of an iCalendar RECURRENCE-ID.
 *
 * An {@link Component.Instance}'s RECURRENCE-ID, SEQUENCE, and UID can be used to specify a
 * particular instance of a recurring event.
 *
 * Although RECURRENCE-ID is technically a DATE or DATE-TIME value (optionally with a RANGE) which
 * is better represented as a {@link Component.DateTime}, in practice its utility is as a simple
 * string value, as the particulars of its DATE or DATE-TIME are not of interest when scheduling.
 * Also, some {@link Backings} (like EDS) will some times supply a RECURRENCE-ID as a string instead
 * of a date-time structure, and there's little need to go through the rigamarole of translating
 * it into a structure just to get hashing and equality comparison.
 *
 * See [[https://tools.ietf.org/html/rfc5545#section-3.8.4.4]].
 */

public class RID : BaseObject, Gee.Hashable<RID>, Gee.Comparable<RID> {
    public string value { get; private set; }
    
    public RID(string value) {
        this.value = value;
    }
    
    public RID.from_date_time(DateTime recurrence_id) {
        value = recurrence_id.value_as_ical_string;
    }
    
    public uint hash() {
        return value.hash();
    }
    
    public bool equal_to(RID other) {
        return compare_to(other) == 0;
    }
    
    public int compare_to(RID other) {
        return (this != other) ? strcmp(value, other.value) : 0;
    }
    
    public override string to_string() {
        return value;
    }
}

}


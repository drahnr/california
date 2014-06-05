/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Calendar {

/**
 * An immutable, discrete, well-recognized unit of calendar dates.
 *
 * This interface indicates the {@link Calendar.Span} represents a discrete unit of time (each of
 * which may not contain the same number of days, such as {@link Year}s, while some might, such as
 * {@link Week}s), in contrast to a {@link DateSpan}, which represents an ''arbitrary''
 * span of dates that may or may not correspond to a well-recognized unit of dates.
 *
 * Note that this different than a {@link UnitSpan} such as {@link MonthSpan} which is designed to
 * hold an arbitrary consecutive number of their date units (i.e. a span of months).  Unit
 * represents a single unit of time (a week or a month).
 *
 * If Vala supported constrained generics, a UnitSpan would be defined as requiring a generic type
 * of Unit.
 *
 * Unit is not designed to work with discrete {@link ExactTime} or {@link WallTime} units.
 *
 * @see Date
 * @see Week
 * @see MonthOfYear
 * @see Year
 */

public abstract class Unit<G> : Span, Collection.SimpleIterable<Date> {
    public const string PROP_DATE_UNIT = "date-unit";
    
    /**
     * Returns the {@link DateUnit} this {@link Unit} represents.
     */
    public DateUnit date_unit { get; private set; }
    
    protected Unit(DateUnit date_unit, Date start_date, Date end_date) {
        base (start_date, end_date);
        
        this.date_unit = date_unit;
    }
    
    /**
     * This is specifically for {@link Date}, which can't pass itself down to {@link Span} as that
     * will create a reference cycle, or for child classes which need to do more work before
     * providing a date span.
     *
     * If the latter, the child class should call {@link init_span} to complete initialization.
     */
    protected Unit.uninitialized(DateUnit date_unit) {
        base.uninitialized();
        
        this.date_unit = date_unit;
    }
    
    /**
     * The next chronological discrete unit of time.
     */
    public G next() {
        return adjust(1);
    }
    
    /**
     * The previous chronological discrete unit of time.
     */
    public G previous() {
        return adjust(-1);
    }
    
    /**
     * Returns the same type of {@link Unit} adjusted a quantity of units from this one.
     *
     * Subtraction (adjusting to a past date) is acheived by using a negative quantity.
     */
    public abstract G adjust(int quantity);
    
    /**
     * Returns the number of {@link Unit}s between the two.
     *
     * If the supplied Unit is earlier than this one, a negative value is returned.  (In other
     * words, future days are positive, past days are negative.)
     */
    public abstract int difference(G other);
    
    /**
     * True if the {@link Unit} contains the specified {@link Date}.
     *
     * This is named to conform to Vala's rule for automatic syntax support.  This allows for the
     * ''in'' operator to function on Units, but only for Dates (which is a common operation).
     */
    public bool contains(Date date) {
        return has_date(date);
    }
    
    /**
     * Returns a {@link Collection.SimpleIterator} of all the {@link Date}s in the
     * {@link Unit}'s span of time.
     *
     * This is named to conform to Vala's rule for automatic iterator support.  This allows for
     * the ''foreach'' operator to function on Units, but only for Dates (which is a common
     * operation).
     */
    public Collection.SimpleIterator<Date> iterator() {
        return date_iterator();
    }
}

}


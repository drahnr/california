/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.View.Week {

/**
 * All-day events that span a particular day are drawn in this container.
 *
 * @see DayPane
 */

internal class AllDayCell : Common.EventsCell {
    public const string PROP_OWNER = "owner";
    
    private const int LINES_SHOWN = 3;
    
    public Grid owner { get; private set; }
    
    public AllDayCell(Grid owner, Calendar.Date date) {
        base (owner.owner.palette, date, date.week_of(owner.owner.first_of_week).to_date_span());
        
        this.owner = owner;
        
        palette.palette_changed.connect(on_palette_changed);
        
        // use for initialization
        on_palette_changed();
    }
    
    ~AllDayCell() {
        palette.palette_changed.disconnect(on_palette_changed);
    }
    
    protected override Common.EventsCell? get_cell_for_date(Calendar.Date cell_date) {
        return owner.get_all_day_cell_for_date(cell_date);
    }
    
    private void on_palette_changed() {
        // set fixed size for cell, as it won't grow with the toplevel window
        set_size_request(-1, (palette.small_font_height_px + Palette.LINE_PADDING_PX) * LINES_SHOWN);
    }
    
    protected override void draw_borders(Cairo.Context ctx) {
        int width = get_allocated_width();
        int height = get_allocated_height();
        
        // draw border lines (creates grid effect)
        Palette.prepare_hairline(ctx, palette.border);
        
        // draw right border, unless last one in row, in which case spacer deals with that
        if (date.equal_to(neighbors.end_date)) {
            ctx.move_to(width, height);
        } else {
            ctx.move_to(width, 0);
            ctx.line_to(width, height);
        }
        
        // draw bottom border
        ctx.line_to(0, height);
        
        ctx.stroke();
    }
}

}


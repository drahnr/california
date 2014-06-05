/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

/**
 * User views of the calendar data.
 *
 * The {@link Host.MainWindow} hosts all views and offers an interface to switch between them.
 */

namespace California.View {

private int init_count = 0;

public void init() throws Error {
    if (!Unit.do_init(ref init_count))
        return;
    
    // subunit initialization
    View.Common.init();
    View.Month.init();
    View.Week.init();
}

public void terminate() {
    if (!Unit.do_terminate(ref init_count))
        return;
    
    View.Week.terminate();
    View.Month.terminate();
    View.Common.terminate();
}

}


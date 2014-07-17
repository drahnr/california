/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace E.Util {

[CCode (cheader_filename="libecal/libecal.h", cname="e_cal_util_component_has_recurrences")]
public bool component_has_recurrences(iCal.icalcomponent ical_component);

[CCode (cheader_filename="libecal/libecal.h", cname="e_cal_util_component_is_instance")]
public bool component_is_instance(iCal.icalcomponent ical_component);

[CCode (cheader_filename="libecal/libecal.h", cname="e_cal_util_remove_instances")]
public bool remove_instances(iCal.icalcomponent ical_component, iCal.icaltimetype rid, E.CalObjModType mod);

}

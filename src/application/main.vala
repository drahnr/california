/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

int main(string[] args) {
    return args[1] != "--tests" ? California.Application.instance.run(args) : California.Tests.run(args);
}


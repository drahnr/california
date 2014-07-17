/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace California.Tests {

private class Iterable : UnitTest.Harness {
    public Iterable() {
        add_case("one-zero", one_zero);
        add_case("one-one", one_one);
        add_case("one_many", one_many);
    }
    
    protected override void setup() throws Error {
        Collection.init();
    }
    
    protected override void teardown() {
        Collection.terminate();
    }
    
    private bool one_zero() throws Error {
        return traverse<int?>(new Gee.ArrayList<int?>()).one() == null;
    }
    
    private bool one_one() throws Error {
        Gee.ArrayList<int?> list = new Gee.ArrayList<int?>();
        list.add(1);
        
        return traverse<int?>(list).one() == 1;
    }
    
    private bool one_many() throws Error {
        Gee.ArrayList<int?> list = new Gee.ArrayList<int?>();
        list.add(1);
        list.add(2);
        
        return traverse<int?>(list).one() == null;
    }
}

}


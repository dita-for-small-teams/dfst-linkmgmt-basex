(:============================================
 : DITA for Small Teams DITA Utils Test Driver
 :
 : Provides tests and test utilities for exercising
 : the dita-utils.xqm functions.
 :
 : Copyright (c) 2015 DITA For Small Teams
 :
 : These tests depend on the files from the dfst-sample-project
 : project under the tests/ directory.
 :
 :)

module namespace dftest="http://dita-for-small-teams.org/xquery/modules/dita-utils-test";

import module namespace bxutil="http://dita-for-small-teams.org/xquery/modules/basex-utils";
import module namespace linkutil="http://dita-for-small-teams.org/xquery/modules/linkmgmt-utils";
import module namespace df="http://dita-for-small-teams.org/xquery/modules/dita-utils";
import module namespace relpath="http://dita-for-small-teams.org/xquery/modules/relpath-utils";


declare function dftest:testGetMapTree($repo as xs:string, $branchName as xs:string) as node()* {
  
   let $dbName := bxutil:getDbNameForRepoAndBranch($repo, $branchName)
   let $db := db:open($dbName)
   let $map := doc(concat($dbName, "/docs/tests/complex_map/complex_map.ditamap"))
   
   let $mapTree := df:getMapTree($map)
   return $mapTree
};

declare function dftest:testConstructKeySpaces($repo as xs:string, $branchName as xs:string) as node()* {
   let $dbName := bxutil:getDbNameForRepoAndBranch($repo, $branchName)
   let $db := db:open($dbName)
   let $map := doc(concat($dbName, "/docs/tests/complex_map/complex_map.ditamap"))
   
   let $mapTree := df:getMapTree($map)
   let $keySpaces := df:constructKeySpaces($map)
   return $keySpaces
};



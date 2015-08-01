(: =====================================================

   DITA Link Manager Controller
   
   Controller component of Model/View/Controller. Manages
   access to the link manager data models used to optimize
   link manager features (where-use, dependency tracking).
   
   This module serves mostly to delegate calls from the 
   UI to the underlying link management utilities, but
   it provides a level of indirection that might be
   useful and it maintains the M/V/C distinction, for
   what that's worth.
   
   Author: W. Eliot Kimber
   
   Copyright (c) 2015 DITA For Small Teams
   Licensed under Apache License 2
   

   ===================================================== :)

module namespace lmc="http://dita-for-small-teams.org/xquery/modules/linkmgr-controller";

import module namespace df="http://dita-for-small-teams.org/xquery/modules/dita-utils";
import module namespace bxutil="http://dita-for-small-teams.org/xquery/modules/basex-utils";
import module namespace lmutil="http://dita-for-small-teams.org/xquery/modules/linkmgmt-utils";
import module namespace lmm="http://dita-for-small-teams.org/xquery/modules/linkmgr-model";
import module namespace dfstcnst="http://dita-for-small-teams.org/xquery/modules/dfst-constants";

declare namespace dfst="http://dita-for-small-teams.org";

declare %updating function lmc:updateLinkManagementIndexes($contentDbName, $metadataDbName) {
  lmm:updateLinkManagementIndexes($contentDbName, $metadataDbName)
};

declare function lmc:getUses($doc as document-node(), $useParams as map(*)) {
   let $result := lmutil:getUses($doc/*, $useParams)
   return $result
};

declare function lmc:isRootMap($mapDoc as document-node()) as xs:boolean {
  let $result := lmutil:isRootMap($mapDoc/*)
  return $result
};

(:~
 : Given a content map element, return the corresponding keyspace document,
 : if any. It's possible that the keyspace won't have been constructed at
 : the time this request is made, although it should be under normal 
 : circumstances.
 :)
declare function lmc:getKeySpaceForMap($contentMap as document-node()) as element()? {
   let $result as element() := lmm:getKeySpaceForMap($contentMap/*)
   return $result

};
(: End of Module :)
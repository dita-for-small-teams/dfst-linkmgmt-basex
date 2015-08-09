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

(:~
 : Do stage one of link management index update: Find all direct
 : links and create where-used records for them. This information
 : is required to then create resolved maps and construct the
 : key spaces used to resolve indirect links.
 : 
 : @param contentDbName The name of the content database to index
 : @param metadataDbName The name of the metadata database to store
 : the index entries into.
 : @logID The ID of the log to write messages to.
 :)
declare %updating function lmc:updateLinkManagementIndexesStage1(
                 $contentDbName, 
                 $metadataDbName,
                 $logID) {
    let $directLinks := lmutil:findAllDirectLinks($contentDbName)

    return
      (db:delete($metadataDbName, $dfstcnst:where-used-dir),
       db:delete($metadataDbName, $dfstcnst:resolved-map-dir),
       db:delete($metadataDbName, $dfstcnst:keyspaces-dir),
       (: FIXME: Initialize the update log document :)
       (: Now create new resource use records for direct links :)
       
       lmm:createDirectLinkResourceRecords($metadataDbName, $directLinks, $logID)
      )
};

(:~
 : Do stage 2 of the link management index updating: Construct key
 : spaces using the resolved maps constructed in stage 1.
 :
 : @param contentDbName The name of the content database to index
 : @param metadataDbName The name of the metadata database to store
 : the index entries into.
 : @logID The ID of the log to write messages to.
 :)

declare %updating function lmc:updateLinkManagementIndexesStage2(
         $contentDbName as xs:string,
         $metadataDbName  as xs:string,
         $logID as xs:string) {
         
    lmm:constructKeySpaces($contentDbName, $metadataDbName, $logID)
};



(:~
 : Do stage 3 of the link management index updating: Find all indirect
 : links and create where-used records for all the addressed resources,
 : using the key spaces constructed in stage 2.
 :
 : @param contentDbName The name of the content database to index
 : @param metadataDbName The name of the metadata database to store
 : the index entries into.
 : @logID The ID of the log to write messages to.
 :)
declare %updating function lmc:updateLinkManagementIndexesStage3(
                 $contentDbName, 
                 $metadataDbName,
                 $logID) {
      let $indirectLinks as map(*)* := lmutil:findAllIndirectLinks($contentDbName)
      
      return 
      lmm:createIndirectLinkResourceRecords(
                  $metadataDbName, 
                  $indirectLinks, 
                  $logID)                  

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

(:~
 : Get links, direct and indirect, as indicated by the
 : flags.
 : 
 : @param contentDbName Content database name to get the links for
 : @param linkTypes List, possibly empty, of link types to include. If list
 :                  is empty, include all link types.
 : @param includeDirect If true, include direct links
 : @param includeIndirect If true, include indirect links
 :)
 declare function lmc:getLinks($contentDbName as xs:string,
                               $linkTypes as xs:string*,
                               $includeDirect as xs:boolean,
                               $includeIndirect as xs:boolean) as map(*)* {
   let $directLinks as map(*)* := 
       if ($includeDirect)
          then lmutil:findAllDirectLinks($contentDbName)
          else ()
   let $indirectLinks as map(*)* := 
       if ($includeDirect)
          then lmutil:findAllIndirectLinks($contentDbName)
          else ()
   let $result := ($directLinks, $indirectLinks)
   return $result
};
 
(: End of Module :)
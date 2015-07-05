(: =====================================================

   DITA Link Manager Model
   
   Model component of Model/View/Controller. Maintains
   the link management data.
   
   Provides queries to create and update resource use records,
   dependency indexes, etc.
   
   These queries are called whenever new content is added to 
   given database.
   
   Author: W. Eliot Kimber
   
   Copyright (c) 2015 DITA For Small Teams
   Licensed under Apache License 2
   

   ===================================================== :)

module namespace lmm="http://dita-for-small-teams.org/xquery/modules/linkmgr-model";

import module namespace df="http://dita-for-small-teams.org/xquery/modules/dita-utils";
import module namespace bxutil="http://dita-for-small-teams.org/xquery/modules/basex-utils";
import module namespace lmutil="http://dita-for-small-teams.org/xquery/modules/linkmgmt-utils";



(: Given an element with an @id value, construct the unique resource key for it. 
   For a given element the resource ID is guaranteed to be unique within
   a snapshot (git commit).

   @param elem Element to get resource ID for. Must specify @id attribute.
   @returns Resource key string. 

   The resource key is a combination of the absolute URI of the containing
   document, the element's @id attribute value, and other details TBD.
   
   Note that because DITA can only address elements with IDs this function
   only works for elements with @id attribute values.
 :)
declare function lmm:constructResourceKeyForElement($elem as element()) as xs:string {
  'bogusresourcekey'
};

(: Create or update the link management indexes for the specified repository

   Returns a report of the update process.

:)
declare function lmm:updateLinkManagementIndexes($dbName as xs:string) as element() {
   (: Query the database to find all links and for each link, record a resource use
      record in the database.
      
      Every addressible element has a "resource key" which combines the URI of 
      the containing document and the element's @id value (only elements with
      @id attributes are addressible.
      
    :)
    
    (: Need to handle both context-free links (direct URI references) and
       context-specific links (key references).
       
       For context-specific links have to process all the maps and construct
       resolved maps to serve as the resolution context. This could also
       be modeled as updating the key spaces but I think it makes more
       sense to have the maps be the focus, from which key spaces are derived,
       rather than making the key spaces the primary focus.
       
     :)
    
    let $directLinks := lmutil:findAllDirectLinks($dbName)
    let $logEntries := (
                         <info>Found {count($directLinks)} links</info>,
                         for $link in $directLinks
                             return lmm:createOrUpdateResourceUseRecord($dbName, $link)
                       )
    let $status := if ($logEntries/error) then 'error'
                      else if ($logEntries/warn) then 'warn'
                      else 'success'
    let $log :=   <log>{
         $logEntries
    }</log>
    return <result status="{$status}">{$log}</result>
};

(: Attempts to resolve the link and, if successful, creates use
   record for the resource addressed.
   
   This form of the method is for context-free (direct URI-reference)
   links.
   
   Returns log entries with details of the attempt.
   
 :)
declare function lmm:createOrUpdateResourceUseRecord($dbName, $link) as element()* {
   let $resolveResult as map(*) := lmutil:resolveDirectLink($dbName, $link)
   let $targets := $resolveResult('target')
   let $updateLogEntries :=
       for $target in $targets
           return lmm:createOrUpdateResourceUseRecordForLinkTarget($link, $target)
   
   return ($resolveResult('log'), $updateLogEntries)        
};

declare function lmm:createOrUpdateResourceUseRecordForLinkTarget($link, $target) as element()* {
   <error>createOrUpdateResourceUseRecordForLinkTarget() not implemented</error>
};

(: End of Module :)
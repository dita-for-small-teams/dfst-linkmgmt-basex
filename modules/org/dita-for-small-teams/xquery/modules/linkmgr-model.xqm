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

declare namespace dfst="http://dita-for-small-teams.org";

import module namespace df="http://dita-for-small-teams.org/xquery/modules/dita-utils";
import module namespace bxutil="http://dita-for-small-teams.org/xquery/modules/basex-utils";
import module namespace lmutil="http://dita-for-small-teams.org/xquery/modules/linkmgmt-utils";
import module namespace dfstcnst="http://dita-for-small-teams.org/xquery/modules/dfst-constants";
import module namespace relpath="http://dita-for-small-teams.org/xquery/modules/relpath-utils";


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
declare %updating function lmm:updateLinkManagementIndexes($dbName as xs:string) {
   (: Query the database to find all links and for each link, record a resource use
      record in the database.
      
      Every addressible element has a "resource key" which combines the URI of 
      the containing document and the element's @id value (only elements with
      @id attributes are addressible.
      
      The link management indexes are stored under the .dfst directory:
      
      .dfst/linkmgmt/where-used/
      
      For each document used there is a directory whose name is the hash
      of the document's URI (which will be unique within a branch.
      
      
      
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
    (: Updating functions can't return a result, so we can't
       capture the log records as we go.
     :)
       
     return (try {
        (db:delete($dbName, $dfstcnst:where-used-dir),
         db:output(<info>Where-used Index updated</info>))        
     } catch * {
        db:output(<error>Exception deleting where-used directory "{$dfstcnst:where-used-dir}": {$err:description}</error>)
     },
    
    (: Now create new resource use records :)
    
    for $link in $directLinks
       let $resolveResult as map(*) := lmutil:resolveDirectLink($dbName, $link)
       return lmm:createOrUpdateResourceUseRecord($dbName, $link, $resolveResult)
    )
};

(: Attempts to resolve the link and, if successful, creates use
   record for the resource addressed.
   
   This form of the method is for context-free (direct URI-reference)
   links.
   
   Returns log entries with details of the attempt.
   
 :)
declare %updating function lmm:createOrUpdateResourceUseRecord($dbName, $link, $resolveResult as map(*)) {
   let $targets := $resolveResult('target')
   for $target in $targets
       return lmm:createOrUpdateResourceUseRecordForLinkTarget($dbName, $link, $target)
};

(:
 : Creates a use record reflecting the use of the target element by the document
 : that contains the link.
 :
 : The use records are organized into directories, one directory per used document,
 : where the directory name is the MD5 hash of the document URI (just to make a 
 : shorter name that won't have any problematic characters).
 :
 : Each use record document's filename is the MD5 hash of the linking document's
 : URI plus the MD5 hash of the linking element.
 :
 : Potential problem: the same element could, in theory, link to the same target in 
 : two different ways: as a link and as a conref, although this case is extremely
 : unlikely. Really need a way to distinguish each abstract link represented by
 : a given DITA link-establishing element but the current implementation doesn't 
 : provide that abstraction. It could through a refactor. Keeping it simple for now.
 :)
declare %updating function lmm:createOrUpdateResourceUseRecordForLinkTarget($dbName, $link, $target) {
   let $targetDoc := root($target)
   let $targetDocHash := hash:md5(document-uri($targetDoc))
   let $containingDir := concat($dfstcnst:where-used-dir, '/', $targetDocHash, '/')
   let $recordFilename := concat('use-record_', hash:md5(document-uri(root($link))), '.xml')
   let $useRecord := 
     <dfst:useRecord targetDoc="{document-uri($targetDoc)}"
                     usingDoc="{document-uri(root($link))}"
                     linkType="{df:getLinkBaseType($link)}"
                     linkClass="{string($link/@class)}"
     />
    let $useRecordUri := relpath:newFile($containingDir, $recordFilename)
    return try {
       db:replace($dbName, 
                  $useRecordUri,
                  $useRecord),
       db:output(<info>Stored use record "{$useRecordUri}"</info>)
    } catch * {
       db:output(<error>Error storing use record to "{$useRecordUri}": {$err:description}</error>)
    }
};

(: End of Module :)
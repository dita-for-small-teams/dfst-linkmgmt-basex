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
  let $targetDocHash := hash:md5(document-uri(root($elem)))
  let $treepos := for $anc in ($elem/ancestor-or-self::*)
                      return string(count($anc | $anc/preceding-sibling::*))
  let $key := string-join($treepos, '.')
  return $targetDocHash || '^' || $key

};

(:~
 : Create or update the link management indexes for the specified repository
 :  
 :)
declare %updating function lmm:updateLinkManagementIndexes(
                               $contentDbName as xs:string,
                               $metadataDbName as xs:string) {
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
     
    let $logID := 'linkMgmtIndex' (: ID of the log to log messages to :)
     
    let $directLinks := lmutil:findAllDirectLinks($contentDbName)
       
    return (
      try {
          db:delete($metadataDbName, $dfstcnst:where-used-dir)        
      } catch * {
          (: FIXME: Log to log doc :)
          db:output(<error>Exception deleting where-used directory "{$dfstcnst:where-used-dir}": {$err:description}</error>)
      },
       
      (: Now create new resource use records for direct links :)
      
      lmm:createDirectLinkResourceRecords($metadataDbName, $directLinks, $logID),
      
      (: Now create resolved maps and key space documents for each of the root maps.
       :)
      lmm:constructKeySpaces(
         $contentDbName,
         $metadataDbName,
         $logID),
      
      (: Now create resource use records for all the indirect links: :)
      lmm:createIndirectLinkResourceRecords(
                  $metadataDbName, 
                  lmutil:findAllIndirectLinks($contentDbName), 
                  $logID)
    )
        
};

declare %updating function lmm:createDirectLinkResourceRecords(
        $metadataDbName as xs:string, 
        $directLinks as map(*)*,
        $logID as xs:string) {
    for $linkItem in $directLinks   
       let $resolveResult := lmutil:resolveDirectLink($linkItem)    
       return lmm:createOrUpdateResourceUseRecord(
                   $metadataDbName, 
                   $linkItem,
                   $resolveResult,
                   $logID)
    
};

declare %updating function lmm:createIndirectLinkResourceRecords(
                               $metadataDbName as xs:string,
                               $indirectLinks,
                               $logID as xs:string) {
    for $linkItem in $indirectLinks
        let $resolveResult as map(*) := lmutil:resolveIndirectLink($linkItem)
        return lmm:createOrUpdateResourceUseRecord(
                   $metadataDbName,
                   $linkItem,
                   $resolveResult,
                   $logID)
};

(: Given a link and the resolved result, creates a resource use record for each
   target the link resolved to.
   
 :)
declare %updating function lmm:createOrUpdateResourceUseRecord(
                              $metadataDbName, 
                              $linkItem as map(*), 
                              $resolveResult as map(*),
                              $logID as xs:string) {                              
   let $resolveResult as map(*) := lmutil:resolveDirectLink($linkItem)                              
   let $targets := $resolveResult('target')
   for $target in $targets
       return lmm:createOrUpdateResourceUseRecordForLinkTarget(
                    $metadataDbName, 
                    $linkItem, 
                    $target,
                    $logID)
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
declare %updating function lmm:createOrUpdateResourceUseRecordForLinkTarget(
           $metadataDbName as xs:string, 
           $linkItem as map(*), 
           $target as element(),
           $logID as xs:string) {
   let $targetDoc := root($target)
   let $link := $linkItem('link')
   let $containingDir := concat($dfstcnst:where-used-dir, '/', 
                                lmm:constructResourceKeyForElement($target), 
                                '/')
   let $reskey := lmm:constructResourceKeyForElement($link)
   let $recordFilename := concat('use-record_', $reskey, '.xml')
   let $format := if ($link/@format)
                     then string($link/@format)
                     else 'dita'
   let $scope := if ($link/@scope)
                     then string($link/@scope)
                     else 'local'
   (: df:getTitleForLinkElementContainer($link) :)                     
   let $useRecord := 
     <dfst:useRecord resourceKey="{$reskey}"
                     targetDoc="{document-uri($targetDoc)}"
                     usingDoc="{document-uri(root($link))}"
                     linkType="{df:getBaseLinkType($link)}"
                     linkClass="{string($link/@class)}"
                     format="{$format}"
                     scope="{$scope}"
     >
       <title>{if (df:class($link, 'map/topicref')) 
                  then string((root($link)/*/*[df:class(., 'topic/title')] |
                        root($link)/*/@title)[1])
                  else string($link/ancestor::*[df:class(., 'topic/topic')][1]/*[df:class(., 'topic/title')])}</title>
     </dfst:useRecord>
    let $useRecordUri := relpath:newFile($containingDir, $recordFilename)
    return try {
       (
       if (db:exists($metadataDbName, $useRecordUri)) 
          then db:delete($metadataDbName, $useRecordUri)
          else(),
       db:replace($metadataDbName, 
                  $useRecordUri,
                  $useRecord),
       (: FIXME: Write record to log doc :)
       db:output(<info>Stored use record "{$useRecordUri}"</info>)
       )
    } catch * {
       (: FIXME: Write record to log doc :)
       db:output(<error>Error storing use record to "{$useRecordUri}": {$err:description}</error>)
    }
};

(:~
 : Construct key spaces from root maps. 
 : 
 : @param contentDbName Name of datbase that contains the content to construct key spaces from
 : @param metadataDbName Name of metadata database to store construct key spaces in.
 :
 : Finds all the root maps (requires that all direct-link use records are up to date).
 :  
 : For each root map, constructs and stored the resolved map and then constructs 
 : and stores the keyspace document for that root map.
 :  
 :)
declare %updating function lmm:constructKeySpaces(
        $contentDbName as xs:string,
        $metadataDbName as xs:string,
        $logID) {
  (: FIXME: Implement this :)
  db:output("lmm:constructKeySpaces() not implemented")
};
(: End of Module :)
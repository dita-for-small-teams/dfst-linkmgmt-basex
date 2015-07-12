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

   @param elem Element to get resource ID for.
   @returns Resource key string. 

   The resource key is a combination of the absolute URI of the containing
   document and the element's tree position within the document, producing
   a unique key for any element in any document on a given snapshot (version
   in time). Resource keys are not reliably unique across snapshots as the position of
   the element within its containing document could change from version to 
   version. 
   
   The resource key is used to look up the element in where-used records, either
   as the element used or the element doing the use (links).
   
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
      
      The link management indexes are stored in a separate database from
      the content database: every branch-specific database has a corresponding
      metadata database that contains the where-used records, resolved maps,
      key space information, and any other metadata you might want to store.
      
      For each document used there is a directory whose name is the hash
      of the document's URI (which will be unique within a branch). Within
      that directory are the use records for elements within that document.
      This arrangement has the effect of providing a reference count for
      for each document, making it quick to determine if a given document
      is used by any links. It also allows for narrowing the scope of
      where-used queries to just the entries for the document.      
      
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
   let $linkContext := $linkItem('linkContext')                     
                     
   (: df:getTitleForLinkElementContainer($link) :)                     
   let $useRecord := 
     <dfst:useRecord resourceKey="{$reskey}"
                     targetDoc="{document-uri($targetDoc)}"
                     usingDoc="{document-uri(root($link))}"
                     linkType="{df:getBaseLinkType($link)}"
                     linkClass="{string($link/@class)}"
                     linkContext="{$linkContext}"
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
 : For each root map, constructs and stores the resolved map.
 :  
 :)
declare %updating function lmm:constructKeySpaces(
        $contentDbName as xs:string,
        $metadataDbName as xs:string,
        $logID as xs:string) {
        
  (: General process:
  
     1. Find all DITA maps
     
     2. For each map, construct a resolved map that preserves submap
        boundaries and original source map details.
        
     The resolved maps can then be used to determine the effective 
     binding for any key without the need to separately construct
     key spaces. This technique was pioneered and suggested by 
     Chris Nitchie, designer of the DITA 1.3 scoped keys mechanism.
     
     Note that there's no point in trying to determine if a given
     map is a "root map" as any map can, in theory, be used as a root
     map. Likewise, a map that happens to have no local-scope 
     topicrefs to it may not be intended to be the root of a publication.
     
     One alternative to this approach is to only consider maps that have
     peer-scope topicrefs to them to be root maps (per the DITA 1.3 
     meaning for peer-scope topicrefs to dita maps). In this case, there needs
     to be a "master map" that serves to simply identify the "top level 
     root maps", that is, the maps that are considered by the document
     authors to be The root maps, that is, the maps they consider to
     be the roots of publications. Given this master map the system can 
     then consider only peer-scope map references in order to determine
     the root maps and thus the maps for which key space construction
     is relevant.
     
   :)
   
   let $maps := collection($contentDbName)/*[df:class(., 'map/map')]
   return for $map in $maps
              return (db:output(<info>Resolving map {document-uri(root($map))}...</info>),
                      lmm:constructResolvedMap(
                                              $map, 
                                              $metadataDbName,
                                              $logID)
                     )
        
};

(:~
 : Construct a resolved map suiteable for doing key resolution. The map
 : is stored in the metadata database.
 :
 : @param map DITA map that is the root of the resolved map.
 : @param metadataDbName Name of the metadata database to store the
 :        resolved map in
 :)
declare %updating function lmm:constructResolvedMap(
                                    $map as element(), 
                                    $metadataDbName as xs:string,
                                    $logID as xs:string) {
  let $contentDbName := db:name($map)
  let $resolvedMap := lmm:resolveMap($map, $logID)
  let $resolvedMapURI := lmm:getResolvedMapURIForMap($map)
  return (db:replace($metadataDbName, $resolvedMapURI, $resolvedMap),
          db:output(<info>Stored resolved map "{$resolvedMapURI}"</info>))
                         
};


(:~
 : Takes a root map and returns the resolved version of the map.
 : 
 : The resolution process preserves the original structure and 
 : adds <topicgroup> elements to record submap boundaries.
 :
 : The resulting resolved map reflects all directly-referenced submaps.
 : Because the resolved map is used for constructing key spaces it is 
 : not useful or necessary to resolve key-based map references as those
 : maps cannot contribute to the final set of effective key spaces.
 :)
declare function lmm:resolveMap(
                     $map as element(),
                     $logID as xs:string) as element() {
                     
    
    (: Array of sequences of key scope names, ordered from
       highest to lowest.
       Each sequence is the set of key scope names defined
       on a given map or topicref, establishing a new set
       of key scopes.
       
       There is always the '#root' (anonymous) key scope
       bound to the root map. The root map can also
       establish additional scope names.
    :)
    let $keyScopes as array(xs:string+) := 
       [ ('#root',
          if ($map/@keyscope)
             then tokenize(string($map/@keyscope), ' ')
             else ()
         )
       ]  
    let $resolvedMap := 
          element {name($map)} 
            {
              attribute origMapURI { document-uri(root($map)) },
              attribute origMapDB { db:name($map) },
              attribute xml:base { document-uri(root($map)) },
              $map/@*,
              for $node in $map/node() 
                  return lmm:resolveMapHandleNode($node, $keyScopes, $logID)
            }
    return $resolvedMap
};

(:~
 : Simple identity transform dispatch handler for nodes of any type.
 :)
declare function lmm:resolveMapHandleNode(
                     $node as node(),
                     $keyScopes as array(xs:string+),
                     $logID as xs:string) as node()* {
  typeswitch ($node) 
    case element() return lmm:resolveMapHandleElement(
                              $node,
                              $keyScopes,
                              $logID)
    default return $node
};

(:~
 : Apply identity transform to elements of any type. 
 :)
declare function lmm:resolveMapHandleElement(
                       $elem as element(),
                       $keyScopes as array(xs:string+), 
                       $logID as xs:string) as element()* {
   let $result :=
     if (df:class($elem, 'map/topicref'))
        then lmm:resolveMapHandleTopicref($elem, $keyScopes, $logID)
        else lmm:resolveMapCopy($elem, $keyScopes, $logID)
   return $result
};

(:~
 : Copy an element as for xsl:copy instruction.
 :)
declare function lmm:resolveMapCopy(
                    $elem as element(),
                    $keyScopes as array(xs:string+), 
                    $logID as xs:string) as element()* {
   let $result :=
     element {name($elem)} {
        for $node in ($elem/@*, $elem/node())
            return lmm:resolveMapHandleNode($node, $keyScopes, $logID)           
     }
   return $result
};

(:~
 : Handle topicrefs. If the topicref is to local-scope map, then resolve the topicref
 : to the map and include the map in the resolved result, otherwise apply normal
 : copy processing.
 :)
declare function lmm:resolveMapHandleTopicref(
                      $elem as element(),
                      $keyScopes as array(xs:string+), 
                      $logID as xs:string) as element()* {
   let $result :=
     if ($elem/@format = ('ditamap') and df:getEffectiveScope($elem) = ('local'))
        then lmm:resolveMapHandleMapRef($elem, $keyScopes, $logID)
        else lmm:resolveMapCopy($elem, $keyScopes, $logID)
   return $result
};

(:~
 : Handle local-scope map references.
 :
 : Constructs a <dfst:submap> element that captures the details about the original
 : submap and then applies the identity tranform to the topicref and reltable
 : children of the submap.
 :
 : The dfst:submap element sets the xml:base attribute to the URI of the submap document
 : so that URI references copied from the included map will be correct.
 :
 :)
declare function lmm:resolveMapHandleMapRef(
                        $elem as element(),
                        $keyScopes as array(xs:string+), 
                        $logID as xs:string) as element()* {
  let $resolutionMap as map(*) := df:resolveTopicRef($elem)
  let $submap := $resolutionMap('target')
  (: FIXME: add resolution messages to log once we get logging infrastructure in place :)
  return 
    <dfst:submap 
      xml:base="{document-uri(root($submap))}"
      origMapURI="{document-uri(root($submap))}"
      origMapClass="{string($submap/@class)}"
      class="+ map/topicref dfst-d/submap "
    >      
      {lmm:constructMergedKeyscopeAtt($elem, $submap)},
      <topicmeta>
        <submap-meta>{
          comment {'submap metadata goes here '}
        }</submap-meta>
      </topicmeta>,
      {for $e in $submap/*[df:class(., 'map/topicref') or df:class(., 'map/reltable')]
          return lmm:resolveMapHandleElement($e, $keyScopes, $logID)
      }
    </dfst:submap>
};

(:~
 : Merge the key scope names from two elements that may both specify @keyscope
 :)
declare function lmm:constructMergedKeyscopeAtt(
                        $elem1 as element(), 
                        $elem2 as element()) as attribute()? {
   let $scopeNames as xs:string? := lmm:mergeKeyScopeNames($elem1, $elem2)
   let $result :=
       if ($scopeNames)
          then attribute keyscope {$scopeNames}
          else ()
   return $result
};

(:~
 : Merge the key scope names from two elements that may both specify @keyscope
 :)
declare function lmm:mergeKeyScopeNames($elem1 as element(), $elem2 as element()) as xs:string? {
  
  let $scopeNames := (tokenize($elem1/@keyscope), tokenize($elem2/@keyscope))
  let $result :=
      if (count($scopeNames) > 0)
         then string-join(distinct-values($scopeNames), " ")
         else ()
  return $result
};

declare function lmm:getResolvedMapURIForMap(
                        $map as element()) {
  let $mapDocHash := hash:md5(document-uri(root($map)))
  return $dfstcnst:resolved-map-dir ||
         "/" || $mapDocHash || ".ditamap"
};

(: End of Module :)
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
      
      (: Now create resolved maps for each of the root maps.
         The resolved maps serve to enable key resolution
         without creating separate data sets just for the key spaces.
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
                                lmutil:constructResourceKeyForElement($target), 
                                '/')
   let $reskey := lmutil:constructResourceKeyForElement($link)
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
     
     Key spaces are constructed from resolved maps and stored in the metadata
     database.
     
   :)
   
   let $contentMaps := collection($contentDbName)/*[df:class(., 'map/map')][lmutil:isRootMap(.)]
   (: Sequence of maps containing the things to be stored :)
   let $dataToStore as map(*)* := 
       for $ditaMap in $contentMaps 
          let $resolvedMap as map(*) := lmm:resolveMap($ditaMap)
          (: Sequence of maps containing the source map, resolved map,
             and sequence of key space documents to be stored.
           :)
          let $keySpaces as map(*) := 
                lmm:constructKeySpacesForResolvedMap(
                   $resolvedMap)
          let $dataMap := 
               map{ 
                    'resolvedMap' : $resolvedMap,
                    'keyspaces' : $keySpaces
                  }
          return $dataMap
    return
      for $obj in $dataToStore
            let $ditaMap := $obj('resolvedMap')('map')
            let $resolvedMap := $obj('resolvedMap')
            let $keySpaces as map(*) := $obj('keySpaces')
            return (db:output(<info>Resolving map {document-uri(root($ditaMap))}...</info>),
                    lmm:storeResolvedMap($resolvedMap, 
                                         $metadataDbName,
                                         $obj('log'),
                                         $logID),
                    for $keySpace in $keySpaces 
                        return lmm:storeKeySpace(
                                         $keySpace, 
                                         $metadataDbName,
                                         $logID)
                     )
};

(:~
 : Store a keyspace document in the metadata database.
 : 
 : @param keySpaceMap Map containing the source map and a key space
 :                    document constructed from the map.
 : @param metadataDbName Name of the metadata database to store the
 :        resolved map in
 : @logID ID of the log to write the messages to.
 :)
declare %updating function lmm:storeKeySpace(
                     $keySpaceMap as map(*),
                     $metadataDbName as xs:string,
                     $logID as xs:string) {
  let $map := $keySpaceMap('map')
  let $resolvedMap := $keySpaceMap('resolvedMap')
  let $keySpace := $keySpaceMap('keyspace')
  let $keySpaceURI := lmutil:getKeySpaceURIForKeySpace($keySpace)
  return (db:replace($metadataDbName, $keySpaceURI, $keySpace),
          db:output((<info>Stored key space "{$keySpaceURI}"</info>)))
};

(:~
 : Given a resolved map, construct one or more key space documents
 : reflecting the key spaces defined by the map, one for each
 : key scope defined in the map. At minimum there will be one
 : key space document with no key definitions.
 : 
 : @param map Source content map (returned in the result key)
 : @param resolvedMap Resolved map constructed from the source map
 : @return Map containing the members:
 :
 :   map : The content map 
 :   resolvedMap : The resolved map the key spaces were constructed from
 :   keySpaces : Sequence of one or more keyspace documents.
 :)
declare function lmm:constructKeySpacesForResolvedMap(
                       $dataMap as map(*)) as map(*) {
   let $ditaMap as element() := $dataMap('map')
   let $resolvedMap as element() := $dataMap('resolvedMap')
   let $keyspaces := lmm:constructKeySpace($resolvedMap)
   
   let $result := 
      map{ 'map' : $ditaMap,
           'resolvedMap' : $resolvedMap,
           'keySpaces' : $keyspaces
         }
   return $result
};

(:~
 : The identity of a key space is the element that defines it, either map
 : or a topicref. In order to resolve a key you must know the key space
 : hierarchy because you have to start with the root key space, see if 
 : the key-as-referenced is defined in that space, then if not, walk
 : down the ancestor tree until you either find a match for the key
 : name or run out of options. 
 :
 : Logically, an ancestor key space reflects in itself all the scope-qualified
 : names of the keys from its descentant key space that it does not
 : explicitly override, meaning that, starting from any descedant key space you 
 : can resolve any fully-qualified key name. 
 :
 : @param spaceDefiner Element, map or topicref, that defines a new key space.
 :
 : @return Keyspace element, which will contain any descendant keyspaces
 :)
declare function lmm:constructKeySpace($spaceDefiner as element()) as element() {
  let $keyspaceMaps := lmm:constructKeySpaceMap($spaceDefiner, ())
  (: FIXME: Replace this proper to-XML serialization logic :)
  let $result := bxutil:reportMapAsXML($keyspaceMaps)
  return $result
};

(:~
 : Construct map object that reflects the key space rooted at the specified
 : key space defining element. 
 :
 : The map is a map of key names to key definitions, where a given key name
 : may reflect multiple definitions. The key definitions are in precedence
 : order from highest to lowest.
 :
 : @param spaceDefiner Element, map or topicref, that defines a new key space.
 : @parentSpace The parent key space (enables walking up the key space ancestry)
 : @return map object with the following members:
 : 
 : 'scopeNames' : A sequence, possibly empty, of the scope names for the scope.
 :                (Only the root scope can have no name).
 : 'directKeys' : Keys defined directly within the space-defining element
 :                and not within any descendant scope. A map of key names
 :                sequences of key definitions.
 : 'inheritedKeys' : Keys inherited from descendant scopes. A map of key names
 :                   to sequences of key definitions.
 : 'childSpaces' : Sequence of maps objects representing the child key spaces
 :                 of this key space.
 : 'parentSpace' : The parent key space's map. The root space has no parent.
 :)
declare function lmm:constructKeySpaceMap($spaceDefiner as element(),
                                          $parentSpace as map(*)?
                                          ) as map(*) {
   let $result := map{ 'scopeNames' : (),
                       'directKeys' : map {},
                       'inheritedKeys' : map {}
                     }
   (: Determine the directly-declared keys and then call recursively to get
      the maps for any child key spaces. Then add the direct and
      inherited keys from those maps to the inherited keys of this key space.
    :)
   return $result
};

(:~
 : Store a resolved map in the metadata database.
 :
 : @param map DITA map that is the root of the resolved map.
 : @param resolvedMap The resolved map constructed from the content map
 : @param metadataDbName Name of the metadata database to store the
 :        resolved map in
 : @log Sequence, possibly empty, of log message elements.
 : @logID ID of the log to write the messages to.
 :)
declare %updating function lmm:storeResolvedMap(
                                    $dataMap as map(*),
                                    $metadataDbName as xs:string,
                                    $log as element()*,
                                    $logID as xs:string) {
  let $map := $dataMap('map')
  let $resolvedMap := $dataMap('resolvedMap')
  let $log := $dataMap('log')
  let $resolvedMapURI := lmutil:getResolvedMapURIForMap($map)
  return (db:replace($metadataDbName, $resolvedMapURI, $resolvedMap),
          db:output(($log, <info>Stored resolved map "{$resolvedMapURI}"</info>)))
                         
};


(:~
 : Takes a root map and returns the resolved map within a map
 : containing the original map, resolved map, and any log messages:
 : 
 : @param map Content map to be resolved.
 : 
 : @return Map with the following members:
 :
 : map : The input map
 : resolvedMap : The resolved map
 : log : Sequence, possibly empty, of log entry elements.
 :
 : The resolution process preserves the original structure and 
 : adds <topicgroup> elements to record submap boundaries.
 :
 : The resulting resolved map reflects all directly-referenced submaps.
 : Because the resolved map is used for constructing key spaces it is 
 : not useful or necessary to resolve key-based map references as those
 : maps cannot contribute to the final set of effective key spaces.
 :
 :)
declare function lmm:resolveMap(
                     $map as element()) as map(*) {
                     
    
    (: Array of sequences of key scope names, lowest to highest
       (e.g., as for ancestor:: axis)
       Each sequence is the set of key scope names defined
       on a given map or topicref, establishing a new set
       of key scopes.
       
       There is always the root (anonymous) key scope
       bound to the root map. The root map can also
       establish additional scope names.
    :)
    let $keyScopes as array(*) := 
       (if ($map/@keyscope)
             then [ tokenize(string($map/@keyscope), ' ') ]
             else [ ]
         )
       
    let $resolvedMap := 
          element {name($map)} 
            {
              attribute origMapURI { document-uri(root($map)) },
              attribute origMapDB { db:name($map) },
              attribute xml:base { encode-for-uri(document-uri(root($map))) },
              $map/@*,
              for $node in $map/node() 
                  return lmm:resolveMapHandleNode($node, $keyScopes)
            }
    let $result := 
       map{
           'map' : $map,
           'resolvedMap' : $resolvedMap,
           'log' : ()
          }
    return $result
};

(:~
 : Simple identity transform dispatch handler for nodes of any type.
 :)
declare function lmm:resolveMapHandleNode(
                     $node as node(),
                     $keyScopes as array(*)) as node()* {
  typeswitch ($node) 
    case element() return lmm:resolveMapHandleElement(
                              $node,
                              $keyScopes)
    case attribute(keys) return lmm:expandKeyNames(
                                    $node, 
                                    $keyScopes)
    default return $node
};

(:~
 : Apply identity transform to elements of any type. 
 :)
declare function lmm:resolveMapHandleElement(
                       $elem as element(),
                       $keyScopes as array(*)) as element()* {
   let $result :=
     if (df:class($elem, 'map/topicref'))
        then lmm:resolveMapHandleTopicref($elem, $keyScopes)
        else lmm:resolveMapCopy($elem, $keyScopes)
   return $result
};

(:~
 : Copy an element as for xsl:copy instruction.
 :)
declare function lmm:resolveMapCopy(
                    $elem as element(),
                    $keyScopes as array(*)) as element()* {
   let $result :=
     element {name($elem)} {
        for $node in ($elem/@*, $elem/node())
            return lmm:resolveMapHandleNode($node, $keyScopes)           
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
                      $keyScopes as array(*)) as element()* {
   let $result :=
     if ($elem/@format = ('ditamap') and df:getEffectiveScope($elem) = ('local'))
        then lmm:resolveMapHandleMapRef($elem, $keyScopes)
        else lmm:resolveMapCopy($elem, $keyScopes)
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
                        $keyScopes as array(*)) as element()* {
  let $resolutionMap as map(*) := df:resolveTopicRef($elem)
  let $submap := $resolutionMap('target')
  (: FIXME: add resolution messages to log once we get logging infrastructure in place :)
  return 
    <dfst:submap 
      xml:base="{document-uri(root($submap))}"
      origMapURI="{document-uri(root($submap))}"
      origMapClass="{string($submap/@class)}"
      class="+ map/topicref map-d/topicgroup dfst-d/submap "
    >      
      {lmm:constructMergedKeyscopeAtt($elem, $submap)}
     <topicmeta class="- map/topicmeta ">
       <navtitle class="- map/navtitle ">{($submap/*[df:class(., 'topic/title')], string($submap/@title))[1]}</navtitle>
     </topicmeta>
      {for $e in $submap/*[df:class(., 'map/topicref') or df:class(., 'map/reltable')]
          return lmm:resolveMapHandleElement($e, $keyScopes)
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

(:~
 : Expand the @keys value to add scope qualifications for all the scopes
 : @return keys attribute node with the expanded values.
 :)
declare function lmm:expandKeyNames($keysAtt as attribute(keys), 
                                    $keyScopes as array(*)) as attribute() {
  
  let $baseKeyNames as xs:string* := 
                    tokenize(string($keysAtt), " ") 
  let $expandedKeyNames := 
      for $keyName in $baseKeyNames
          return lmm:scopeQualifyKeyName(
                      $keyName, 
                      $keyScopes)
  let $result := attribute {name($keysAtt)} 
                {string-join($expandedKeyNames, ' ')}
  return $result
};  

(:~
 : Given a key name and an array of key scope sequences returns the
 : names reflecting the qualification of the base key name using the 
 : the scope hierarchy. 
 :
 : @param keyName The base key name to be qualified
 : @param keyScopes Array of sequences of scope names, where each array member
 :                  reflects one level in the scope hierarchy, ordered from
 :                  highest (root scope, array index 1), lowest (array index last()).
 : @return List of qualified key names.
 :)
declare function lmm:scopeQualifyKeyName(
                     $keyName as xs:string, 
                     $keyScopes as array(*)) as xs:string* {
  (: We process the key scopes from nearest (lowest) to 
     farthest (highest) but the scopes come in ordered from 
     highest to lowest. Reversing the scope array so that
     the called function can use array:head and array:tail
     on the array.
   :)
  let $result := ($keyName, 
                 lmm:applyScopesToNames(
                           ($keyName), 
                           array:reverse($keyScopes), 
                           ()))
  return $result
};

(:~
 : Apply key scopes to a set of base names to produce
 : a set of scope-qualified names.
 :
 : @param baseNames Sequence of base names to be qualified.
 : @param keyScopes Array of sequences of key scope names.
 : @param qualifiedNames Sequence of qualified names
 :
 : @return Qualified names.
 :)
declare function lmm:applyScopesToNames(
                     $keyNames as xs:string+,
                     $keyScopes as array(*),
                     $qualifiedNames as xs:string*) as xs:string* {
  let $result := 
      if (array:size($keyScopes) = 0) 
         then $qualifiedNames
         else 
           let $newNames := 
               for $name in $keyNames
                   return for $scopeName in $keyScopes(1)
                          return $scopeName || "." || $name
           return lmm:applyScopesToNames(
                      $newNames,
                      array:tail($keyScopes),
                      ($qualifiedNames, $newNames)
                  )
  return $result
};

 

(: End of Module :)
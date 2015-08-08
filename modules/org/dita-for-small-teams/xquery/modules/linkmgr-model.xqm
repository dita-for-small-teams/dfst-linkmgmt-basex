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
                               $indirectLinks as map(*)*,
                               $logID as xs:string) {
    for $linkItem in $indirectLinks
        let $resolveResult as map(*) := lmutil:resolveIndirectLink($metadataDbName, $linkItem)
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
                  $useRecord) (:,
       (: FIXME: Write record to log doc :)
       db:output(<info>Stored use record "{$useRecordUri}"</info>) :)
       )
    } catch * {
       (: FIXME: Write record to log doc :)
       error('LMI-UpdateUseRecord001', 
             concat('Error storing use record to "', $useRecordUri, '": ', $err:description))
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
   let $dataToStore as map(*)* := lmm:constructKeySpacesToBeStored($contentMaps)
   return
      for $obj in $dataToStore
            let $ditaMap := $obj('resolvedMapMap')('map')
            let $resolvedMapMap := $obj('resolvedMapMap')
            let $keySpace as element(keyspace) := $obj('keySpace')
            return ((: FIXME: Write to log. db:output(<info>Resolving map {document-uri(root($ditaMap))}...</info>), :)
                    lmm:storeResolvedMap($resolvedMapMap, 
                                         $metadataDbName,
                                         $obj('log'),
                                         $logID),
                    lmm:storeKeySpace(
                                         $keySpace, 
                                         $metadataDbName,
                                         $logID) 
                     )
};

(:~
 : Constructs the XML key space documents to be stored for each content map.
 : 
 : @param contentMaps Sequence of content (unresolved) map elements.
 : @return Sequence of maps with two items:
 :
 : 'resolvedMapMap' : The resolved map data map. Includes the content map
 :                    as an item.
 : 'keySpace' : The XML representation of the key space for the map
 :)
declare function lmm:constructKeySpacesToBeStored($contentMaps as element()*) as map(*)* {
  let $result := 
    for $ditaMap in $contentMaps 
        let $resolvedMapMap as map(*) := lmm:resolveMap($ditaMap)
        let $dataMap := lmm:constructKeySpaceForResolvedMap($resolvedMapMap)
        return $dataMap
  return $result
};

(:~
 : Store a keyspace document in the metadata database.
 : 
 : @param keySpace XML document representing the key space to be stored
 : @param metadataDbName Name of the metadata database to store the
 :        resolved map in
 : @logID ID of the log to write the messages to.
 :)
declare %updating function lmm:storeKeySpace(
                     $keySpace as element(keyspace),
                     $metadataDbName as xs:string,
                     $logID as xs:string) {
  let $keySpaceURI := lmutil:getKeySpaceURIForKeySpace($keySpace)
 (: FIXME: This is a hack. The map URI as stored and used for 
            resource IDs must include the database name, but
            for db:replace the path part must not include the
            database name.
            
            Probably better to capture the path and metadata
            name separately in the dataMap but that's a more
            involved refactor.
   :)
  let $uriPath := substring-after($keySpaceURI, $metadataDbName)
  return (db:replace($metadataDbName, $uriPath, $keySpace) (: ,
          FIXME: Write to log doc.
          db:output((<info>Stored key space "{$keySpaceURI}"</info>)):)
          )
};

(:~
 : Given a resolved DITA map, construct the key space map 
 : for it.
 : 
 : The key space map reflects the hierarchy of key spaces defined 
 : in the map. Every root map represents at least one, possibly 
 : empty, key space.
 : 
 : @param map Source content map (returned in the result map)
 : @param resolvedMap Resolved map constructed from the source map
 : @return Map containing the members:
 :
 :   map : The content map 
 :   resolvedMap : The resolved map the key spaces were constructed from
 :   keySpace : The key space document rooted at the resolved map.
 :)
declare function lmm:constructKeySpaceForResolvedMap(
                       $resolvedMapMap as map(*)) as map(*) {
   let $ditaMap as element() := $resolvedMapMap('map')
   let $keyspace as element(keyspace) := 
         lmm:constructKeySpace(
                 $resolvedMapMap, 
                 $resolvedMapMap('resolvedMap'))
   
   let $result :=
      map{ 'map' : $ditaMap,
           'resolvedMapMap' : $resolvedMapMap,
           'keySpace' : $keyspace
         }
   return $result
};

(:~
 : Given a content map element, return the corresponding keyspace document.
 : The key space must have already been constructed.
 :)
declare function lmm:getKeySpaceForMap($contentMap as element()) as element()? {
    let $resolvedMapURI := lmutil:getResolvedMapURIForMap($contentMap)
    let $metadataDbName as xs:string := bxutil:getMetadataDbNameForDoc(root($contentMap))
    
    let $keyspaceURI := lmutil:getKeySpaceURIForResolvedMapURI($resolvedMapURI)
    let $result := collection($keyspaceURI)/keyspace
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
 : @param resolvedMapMap Data map that represents the resolved map.
 : @param spaceDefiner Element, map or topicref, that defines a new key space.
 :
 : @return Keyspace element, which will contain any descendant keyspaces
 :)
declare function lmm:constructKeySpace(
                      $resolvedMapMap as map(*),
                      $spaceDefiner as element()) as element() {
  let $keyspaceMap := lmm:constructKeySpaceMap($resolvedMapMap, $spaceDefiner, ())
  let $result := lmm:keySpaceMapToXML($keyspaceMap)
  return $result
};

(:~
 : Given a key space map, return an XML serialization of it suitalbe for storing
 : in the XML metadata store
 :)
declare function lmm:keySpaceMapToXML($keyspaceMap as map(*)) as element(keyspace) {

let $definer as element() := $keyspaceMap('definer')
let $scopeNames as xs:string* := $keyspaceMap('scopeNames')
let $keydefs as map(*)? := $keyspaceMap('keydefs')
let $childScopes as map(*)* := $keyspaceMap('childScopes')
let $resolvedMapMap as map(*) := $keyspaceMap('resolvedMapMap')
let $ditaMap := $resolvedMapMap('map')
let $contentMapDocURI := document-uri(root($ditaMap))
let $resolvedMapURI := $resolvedMapMap?resolvedMapURI

(: NOTE: The definer ID has to be with respect to the resolve map,
         not the content map, as the same content element could
         occur multiple times in the resolved map, e.g., if the
         same submap is included multiple times or as a result
         of branch filtering.
         
   NOTE: Have to specify the resolved map URI explicitly here
         because the definer element hasn't actually been 
         writen to the repo so it doesn't have a document
         URI yet.
:)
let $definerID := lmutil:constructResourceKeyForElement($resolvedMapURI, $definer)

let $result :=
<keyspace
  resolvedMap="{$resolvedMapMap('resolvedMapURI')}"
  contentMap="{document-uri(root($ditaMap))}"
  spaceDefiner="{$definerID}"
>{
 <scopeNames>{
   for $name in $scopeNames
       return <scopeName>{$name}</scopeName>
 }</scopeNames>,
 <keys>{
 for $keyName in map:keys($keydefs) order by $keyName
     return <key name="{$keyName}">{
               for $keydef in $keydefs($keyName)
                   return element {name($keydef)} {
                     $keydef/@*,
                     $keydef/node()
                   }
             }</key>
 }</keys>,
 <childScopes>{
 for $childScope in $childScopes
     return lmm:keySpaceMapToXML($childScope)
 }</childScopes>
}</keyspace>

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
 : @param resolvedMapMap Data map representing the resolved map
 : @param spaceDefiner Element, map or topicref, that defines a new key space.
 : @parentSpace The parent key space (enables walking up the key space ancestry)
 : @return map object with the following members:
 : 
 : 'scopeNames' : A sequence, possibly empty, of the scope names for the scope.
 :                (Only the root scope can have no name).
 : 'keydefs'     : Sequence of key-to-definition maps for each of the keys
 :                 defined in the key space or its descendant key spaces.
 : 'childSpaces' : Sequence of maps objects representing the child key spaces
 :                 of this key space.
 : 'parentSpace' : The parent key space's map. The root space has no parent.
 : 'resolvedMapMap' : The resolved map data map.
 :)
declare function lmm:constructKeySpaceMap(
                         $resolvedMapMap as map(*),
                         $spaceDefiner as element(),
                         $parentSpace as map(*)?
                        ) as map(*) {

   (: Walk the element tree, collecting key definitions and child key 
      key spaces as we go. 
      
      Result is the key space map.
      :)
   let $initialKeySpaceMap :=
           map{'definer' : $spaceDefiner,
               'scopeNames' : if ($spaceDefiner/@keyscopes)
                                 then tokenize($spaceDefiner/@keyscopes, ' ')
                                 else (),
               'parentSpace' : $parentSpace,
               'keydefs' : map {},
               'resolvedMapMap' : $resolvedMapMap
              }
   let $thisScopeKeyDefs :=
       $spaceDefiner//descendant-or-self::*[df:class(., 'map/topicref')][@keys]
   
   
   let $result := lmm:addKeyDefs($initialKeySpaceMap, $thisScopeKeyDefs)
   return $result
};

(:~
 : Add a set of key definitions to a key space, returning the updated
 : key space map.
 : 
 : Calls itself recursively to process the list of elements.
 :
 : @param keySpace Key space map to add the key definitions to
 : @param elems Key-defining elements
 : @return New key space map with the key definitions added.
 :)
declare function lmm:addKeyDefs($keySpace, $elems as element()*) as map(*) {

let $result :=
    if (count($elems) = 0)
       then $keySpace
       else
         let $newKeySpace := lmm:addKeyDef($keySpace, $elems[1])
         return lmm:addKeyDefs($newKeySpace, tail($elems))
       
return $result
};

(:~
 : Adds a key-defining element's definition to the key space if
 : it actually defines a key (this function can be called on any
 : topicref)
 :
 : @param keySpace The key space to add the definition to
 : @param elem The key-defining element to add
 : @return Updated key space map.
 :) 
declare function lmm:addKeyDef($keySpace, $elem as element()) as map(*) {
  let $keyDefs := $keySpace('keydefs') (: Map of key name to sequence of key defs :)
  
  let $keyNames := tokenize($elem/@keys, ' ')
  let $newKeyDefs :=
     map:merge((
       $keyDefs,
       for $keyName in $keyNames
           let $existingDefsForKey := 
                if (exists($keyDefs))
                   then $keyDefs($keyName)
                   else ()

           return map{$keyName :
                      ($existingDefsForKey, $elem)
                     }))
  let $result := map:put($keySpace, 'keydefs', $newKeyDefs)
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
  let $resolvedMapURI := $dataMap('resolvedMapURI')
  (: FIXME: This is a hack. The map URI as stored and used for 
            resource IDs must include the database name, but
            for db:replace the path part must not include the
            database name.
            
            Probably better to capture the path and metadata
            name separately in the dataMap but that's a more
            involved refactor.
   :)
  let $uriPath := substring-after($resolvedMapURI, $metadataDbName)
  return (db:replace($metadataDbName, $uriPath, $resolvedMap) (:,
          FIXME: Write to log
          db:output(($log, <info>Stored resolved map "{$resolvedMapURI}"</info>)) :)
          )
                         
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
 : resolvedMapURI: The URI of the resolved map. This is the URI the map
 : will be stored at (but may not yet be stored at due to order of update
 : operations)
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
                     
    let $resolvedMapURI := lmutil:getResolvedMapURIForMap($map)          
    
    let $resolvedMap := 
          element {name($map)} 
            {
              attribute origMapURI { document-uri(root($map)) },
              attribute origMapDB { db:name($map) },
              attribute xml:base { encode-for-uri(document-uri(root($map))) },
              attribute resID {lmutil:constructResourceKeyForElement($resolvedMapURI, $map)},
              $map/@*,
              for $node in $map/node() 
                  return lmm:resolveMapHandleNode($node)
            }
    let $result := 
       map{
           'map' : $map,
           'resolvedMap' : $resolvedMap,
           'resolvedMapURI' : $resolvedMapURI,
           'log' : ()
          }
    return $result
};

(:~
 : Simple identity transform dispatch handler for nodes of any type.
 :)
declare function lmm:resolveMapHandleNode(
                     $node as node()) as node()* {
  typeswitch ($node) 
    case element() return lmm:resolveMapHandleElement(
                              $node)
    default return $node
};

(:~
 : Apply identity transform to elements of any type. 
 :)
declare function lmm:resolveMapHandleElement(
                       $elem as element()) as element()* {
   let $result :=
     if (df:class($elem, 'map/topicref'))
        then lmm:resolveMapHandleTopicref($elem)
        else lmm:resolveMapCopy($elem)
   return $result
};

(:~
 : Copy an element as for xsl:copy instruction.
 :)
declare function lmm:resolveMapCopy(
                    $elem as element()) as element()* {
   let $metadataDbName := bxutil:getMetadataDbNameForDoc(root($elem))
   let $result :=
     element {name($elem)} {
        if (df:class($elem, 'map/topicref'))
           then (attribute contentResID {lmutil:constructResourceKeyForElement($elem)},
                 attribute resID {lmutil:constructResourceKeyForElement($metadataDbName, $elem)})
           else (),
        for $node in ($elem/@*, $elem/node())
            return lmm:resolveMapHandleNode($node)           
     }
   return $result
};

(:~
 : Handle topicrefs. If the topicref is to a local-scope map, then resolve the topicref
 : to the map and include the map in the resolved result, otherwise apply normal
 : copy processing.
 :)
declare function lmm:resolveMapHandleTopicref(
                      $elem as element()) as element()* {
   let $result :=
     if ($elem/@format = ('ditamap') and df:getEffectiveScope($elem) = ('local'))
        then lmm:resolveMapHandleMapRef($elem)
        else lmm:resolveMapCopy($elem)
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
                        $elem as element()) as element()* {
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
          return lmm:resolveMapHandleElement($e)
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
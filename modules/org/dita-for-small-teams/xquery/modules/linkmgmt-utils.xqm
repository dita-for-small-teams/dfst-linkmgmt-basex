(: =====================================================

   DITA Link Management Utilities
   
   Utilities that support general DITA link management 
   actions.
   
   Author: W. Eliot Kimber
   
   Copyright (c) 2015 DITA For Small Teams
   Licensed under Apache License 2
   

   ===================================================== :)

module namespace lmutil="http://dita-for-small-teams.org/xquery/modules/linkmgmt-utils";

declare namespace dfst="http://dita-for-small-teams.org";

import module namespace df="http://dita-for-small-teams.org/xquery/modules/dita-utils";
import module namespace bxutil="http://dita-for-small-teams.org/xquery/modules/basex-utils";
import module namespace dfstcnst="http://dita-for-small-teams.org/xquery/modules/dfst-constants";
import module namespace relpath="http://dita-for-small-teams.org/xquery/modules/relpath-utils";


declare variable $lmutil:useMatchParamsLocalMaps := 
                               map{'linktype' :'topicref', 
                                   'format' : 'ditamap',
                                   'scope' : 'local'
                                  };
declare variable $lmutil:useMatchParamsPeerMaps := 
                               map{'linktype' :'topicref', 
                                   'format' : 'ditamap',
                                   'scope' : 'peer'
                                  };

(:~
 : Find all links that use direct URI references to their target resources.
 : Returns list of link item maps
 : 
 : Each link item map has the following items:
 : 
 : 'link' : The element that is the link
 : 'rootMap' : The root map document that defines the keyspace the link
 :             is resolved in.
 : 'resolvedMap' : The fully-resolved map that defines key space the key
 :                 reference is resolved in.
 : 'keySpace' : The constructed key space for the root map.
 : 'processingRole' : For topicrefs, the @processing-role value. For
 :                    other links, 'normal'.
 : 'linkContext': The relevant container type for the link, one of:
 :                - 'title' : Link occurs within a title element
 :                - 'prolog' : Link occurs with topicmeta (maps) or prolog (topics)
 :                - 'shortdesc' : Link occurs within a short description
 :                - 'abstract' : Link occurs within an abstract (but not within a
 :                               short description within an abstract)
 :                - 'body' : Link occurs within a topic body
 :                - 'reltable' : Link is a topicref within a relationship table.
 :                - 'navtree' : Link is a topicref with @processing-role of 'normal' and
 :                              is not within a relationship table
 :                - 'resources' : Link is a topicref with a processing role of "resource-only". 
 :  'isDirect' : - 'true' if link is a direct URI reference
 :               - 'false' if link uses a resolvable key reference
 : 
 : For direct links the link element is sufficient
 : to allow resolution as use context has no affect on how the link is resolved.
 : For "." ("this topic") fragment IDs, the context is always the containing topic.
 : 
 : @param dbName Name of the database that contains the documents to be processed.
 : @param logID ID of the log to put log messages in.
 :)
declare function lmutil:findAllDirectLinks($dbName) as map(*)* {
  let $db := db:open($dbName)
  (: First do direct URI references, which don't require any 
     context knowledge:
   :)
  let $links := collection($dbName)//*[df:isTopicRef(.) and not(@keyref)] |
                collection($dbName)//*[contains(@class, ' topic/xref ') and (@href and not(@keyref))] |
                collection($dbName)//*[contains(@class, ' topic/data-about ') and (@href and not(@keyref))] |
                collection($dbName)//*[contains(@class, ' topic/longdescref ') and (@href and not(@keyref))] |
                collection($dbName)//*[@conref]
   (: Construct a link item map for each link element :)
   for $link in $links
       return lmutil:constructLinkItemMap($link) 
};

(:~
 : Constructs a link item map for a direct link.
 :
 : @param link The link element
 : @return Link item map
 :)
declare function lmutil:constructLinkItemMap(
                        $link as element()) as map(*) {
  let $contentDocURI := document-uri(root($link))
  let $result := lmutil:constructLinkItemMap($link, $contentDocURI, ())
  return $result
};


(:~
 : Constructs a link item map
 :
 : @param link The link element
 : @param topicref For indirect links, the topicref that establishes 
 :                 the key resolution context for the link. Not set for direct URI links.
 :                 Note that this topicref element must be from the resolved map, not the
 :                 original source map.
 :)
declare function lmutil:constructLinkItemMap(
                        $link as element(),
                        $contentDocURI as xs:string,
                        $topicref as element()?) as map(*) {
   let $linkItem := 
      map{'link': $link, 
          'resolvedMap': if ($topicref) then root($topicref)/* else (), 
          'topicref' : $topicref,
          'contentDocURI' : $contentDocURI,
          'processingRole': 
             if (df:isTopicRef($link))
                then if ($link/@processing-role)
                        then string($link/@processing-role)
                        else 'normal' (: Default for topicref :)
                else 'normal', (: non-topicref links :)
          'linkContext': lmutil:getLinkContext($link)
         }
    return $linkItem
};
                          

(: Give a document, finds all references to that document that match the 
   type of uses as configured in the $useParams.
   
   @param doc Document to find uses of. 
   @param useParams Use filter parameters. Only uses that match the parameters 
                    will be reported.
   @return Zero or more use record elements. 
   
   The use parameters are:
   
   linktype: List of base type names (e.g., 'topicref, xref) or qualified
             class names (e.g., 'map-d/navref') of the types of links
             to report usage for. If unspecifed, all link types are reported.
             The keyword "#conref" indicates uses via @conref or @conkeyref
             
   format:   List of @format values by which the document is used, e.g. "dita", "ditamap",
             etc. If unspecified, uses are not filtered by @format value.
             
   scope:    List of @scope values to filter the uses by. If unspecified, uses are not
             filtered by @scope value.
             
   TBD: Need for direct/indirect filter, other filters.          
   
   FIXME: Need to rationalize the coding pattern for use parameters and
          their use by the useRecordMatcher() function. The code is a little
          confused right now as a result of some quick refactoring.
   
 :)
declare function lmutil:getUses($elem as element(), $useParams) as element()* {

   let $linktypes := if ($useParams('linktype')) 
                        then $useParams('linktype') 
                        else ('#any')
   let $formats   := if ($useParams('format')) 
                        then $useParams('format') 
                        else ('#any')
   let $scopes   := if ($useParams('scope')) 
                        then $useParams('scope') 
                        else ('#any')

   (: Note that all references are ultimately to elements,
      so resource keys are always for elements, not
      documents. Given an element we can always get its
      containing document.
      
      In DITA, except for <dita> documents, references to 
      documents with no fragment identifier are implicitly
      to the root elements of those documents (i.e., a map
      or topic element).
      
      The resource key here is used as the name of the 
      directory that contains the where-used records for
      this element.
    :)
   let $resKey := lmutil:constructResourceKeyForElement($elem)
   
   (: Now find all use records for the resource key that match the filter
      specification. 
        
      :)
    let $dbName := bxutil:getMetadataDbNameForDoc(root($elem))
    let $collection := $dbName || $dfstcnst:where-used-dir || '/' || $resKey
    let $records := collection($collection)
                       /dfst:useRecord[lmutil:useRecordMatcher(., $linktypes, $formats, $scopes)]
    return $records

};

(: Given an element, construct the unique resource key for it. 
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
   
   The resource key is used to look up the element in where-used records, keyspaces,
   and other link management metadata indexes, either
   as the element used or the element doing the use (links).
   
 :)
declare function lmutil:constructResourceKeyForElement($elem as element()) as xs:string {
   lmutil:constructResourceKeyForElement(document-uri(root($elem)), $elem)
};

(: Given an element, construct the unique resource key for it. 
   For a given element the resource ID is guaranteed to be unique within
   a snapshot (git commit).

   @param docURI URI of the document that contains the element.
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
declare function lmutil:constructResourceKeyForElement(
                                        $docURI as xs:string, 
                                        $elem as element()) as xs:string {
  let $targetDocHash := replace(string(hash:md5($docURI)), '/', '~')
  let $treepos := for $anc in ($elem/ancestor-or-self::*)
                      return string(count($anc | $anc/preceding-sibling::*))
  let $key := string-join($treepos, '.')
  return $targetDocHash || '^' || $key

};


(:~
 : Determines if a given where-used record matches the filter
 : specified parameters. 
 :
 : FIXME: Use a map to pass the filter parameters rather than
 : individual arguments.
 :)
declare function lmutil:useRecordMatcher($record as element(),
                                         $linktypes as xs:string*,
                                         $formats as xs:string*,
                                         $scopes as xs:string*) as xs:boolean {
   let $result := ((if ($linktypes = '#any')
                       then true()
                       else string($record/@linkType) = $linktypes) and
                   (if ($formats = '#any')
                       then true()
                       else string($record/@format) = $formats) and
                   (if ($scopes = '#any')
                       then true()
                       else string($record/@scope) = $scopes))
  return $result                       
};



(:~
 : Given a link element, determines the linkContext value for it.
 :)
declare function lmutil:getLinkContext($link as element()) as xs:string {
  if (df:class($link, 'map/topicref'))
     then if ($link/ancestor::*[df:class(., 'map/reltable')])
             then 'reltable'
          else if ($link/@processing-role = ('resource-only'))
               then 'resources'
          else 'navtree'
     else if ($link/ancestor::*[df:class(., 'topic/title')])
          then 'title'
     else if ($link/ancestor::*[df:class(., 'topic/shortdesc')])
          then 'shortdesc'
     else if ($link/ancestor::*[df:class(., 'topic/abstract')])
          then 'abstract'
     else if ($link/ancestor::*[df:class(., 'topic/prolog') or df:class(., 'map/topicmeta')])
          then 'prolog'
     else if ($link/ancestor::*[df:class(., 'topic/body')])
          then 'body'
     else 'unknown-context'
      
};

(:~ 
 : Given a link item map, attempts to resolve the link to an element (in DITA a given link
 : can address at most one element).
 :  
 : Returns a map with the following members:
 : 'target': A sequence of zero or more elements addressed
 :           by the link.
 : 'log':    A sequence of zero or more log entry elements 
 :           generated by the resolution attempt.
 :)
declare function lmutil:resolveDirectLink($linkItem as map(*)) as map(*) {
  
    
   let $link as element()? := $linkItem('link')
   return if ($link)
      then
       let $resultMap := if (df:class($link, 'map/topicref') and ($link/@href))
                            then df:resolveTopicRef($link)
                            else df:resolveNonTopicRefDirectLink($link)
                         
       let $targets := $resultMap('target')
       let $log := (<info>Link: {
                   concat('<', 
                          name($link), ' ',
                          lmutil:reportAtts($link, ('href', 'keyref', 'keys', 'conref', 'scope')), 
                          '>')} [class: "{string($link/@class)}"], doc: "{document-uri(root($link))}"</info>,
                  if ($targets)
                     then <info>  Link resolved</info>
                     else $resultMap('log')
                  )
       return map{'target' : $targets, 'log' : $log, 'link' : $linkItem}
     else 
       map{'target' : (), 
                 'log' : (), 
                 'link' : $linkItem 
                }
};

(: Given a link descriptor map and the database that contains it, attempts
   to resolve the link to an element (in DITA a given link
   can address at most one element).
   
   Returns a map with the following members:
   'target': A sequence of zero or more elements addressed
             by the link.
   'log':    A sequence of zero or more log entry elements 
             generated by the resolution attempt.
   'link':   The input link item.
 :)
declare function lmutil:resolveIndirectLink(
                        $metadataDbName as xs:string,
                        $linkItem as map(*)) as map(*) {
   
   let $topicref := $linkItem?topicref (: Topicref in resolved map :)
   let $link := $linkItem?link
   let $keyName := df:getKeyNameForKeyref($link)
   let $rootMap := $linkItem?rootMap
   let $contentMapURI := string(root($topicref)/*/@origMapURI)
   
   (: Given the key name, look it up in the topicref's map (which must be a 
      resolved map to find the key definition. The resolved map has had
      all key names expanded with their scope qualifications, so we can 
      look up scope-qualified keys directly. :)
   let $keydef := lmutil:findKeyDefinition($metadataDbName, $keyName, $contentMapURI, $topicref)
   let $targets := 
       if ($keydef)
          then lmutil:resolveTopicRefFromResolvedMap($keydef)
          else ()
              
   let $log := (if (not($keydef)) 
                   then <warn>No key definition found for key "{$keyName}"</warn>
                   else ()
               )
   return map{'target' : $targets, 
              'log' : $log , 
              'link' : $linkItem, 
              'keydef' : $keydef
             }
};

(:~
 : Given a key name and a topicref in a resolved map, find the applicable
 : key-defining topicref, if any.
 :
 : @param keyName The key name to look up.
 : @param topicref The topicref that establishes the map context (and thus
 :                 the starting key scope for the lookup)
 : @return The key-defining topicref or empty sequence if no key definition 
 :             is found.
 :)
declare function lmutil:findKeyDefinition(
                            $metadataDbName as xs:string,
                            $keyName as xs:string,
                            $contentMapURI as xs:string,
                            $topicref as element()) as element()? {
  (: Given a topicref, find the key space that it contributes to,
     then find the effective key binding for the key name within
     the key space hierarchy.
   :)
  let $topicrefID := lmutil:constructResourceKeyForElement($contentMapURI, $topicref)
  let $keyDefInKeySpace := collection($metadataDbName || 
    $dfstcnst:keyspaces-dir)//keyspace/keys/key[@name = $keyName]/*[@resID = $topicrefID]
  
  let $keys := for $keyspace in $keyDefInKeySpace/ancestor::keyspace
                   return $keyspace/keys/key[@name = $keyName]
  let $effectiveKeyDef := $keys[1]/*[1]                 
  
                            
  let $result := $effectiveKeyDef
  return $result
};

(:~
 : Given a database, finds all the indirect links. Returns a map
 : the the members.
 : @param dbName Name of the content database to find the links for
 : @return Map with two members:
 :
 : 'links' : A sequence of linkItem maps, where each map represents one link.
 : 'log' : A sequence of log entry elements.
 : 
 : 
 :)
declare function lmutil:findAllIndirectLinks($dbName) as map(*)* {
   (: 
   
1. Find all root maps (maps with no local-scope topicref references or
   maps with peer topicref references). This requires that the direct-reference
   use records are up to date. It also requires that the resolved map and key space
   documents have already been created.
   
2. For each root map, Walk the resolved map, creating link items for each key-based topicref.
   Resolve topicrefs to topics and process each topic to create link items for each key-based 
   link in each topic.   
   
   :)
   
   let $rootMaps as element()* := lmutil:getRootMaps($dbName)
   
   let $linksFromTopics := lmutil:getIndirectLinksFromTopics($rootMaps)
           
    let $linksFromMaps := () (: FIXME: Build this list as well :)
    let $links := ($linksFromTopics, $linksFromMaps)
   
   return $links
};

(:~
 : Get all the indirect links in topics referenced from the root maps
 : 
 : @para rootMaps list of root content maps.
 : 
 : @return Sequence, possibly empty, of link item maps.
 :)
declare function lmutil:getIndirectLinksFromTopics($rootMaps as element()*) as map(*)* {
  let $result :=
     for $map in $rootMaps
         let $resolvedMap as element()? := lmutil:getResolvedMapForMap($map)
         return if ($resolvedMap)
            then
               let $bos as map(*)* := lmutil:getMapBoundedObjectSet($resolvedMap, ('dita'))
               return for $member in $bos
                  return lmutil:getIndirectLinks($bos)
            else ()
  return $result
};

(:~
 : Takes a sequence of map BOS members and, for each member, 
 : finds the key-based links in the member and returns a of link
 : structures reflecting those links.
 :
 : @param bos Sequence of maps, one for each use of a topic from a
 : DITA map. Each map has two members, "topicref", and "resource"
 : @return A sequence, possibly empty, of link maps.
 :)
declare function lmutil:getIndirectLinks($bos as map(*)*) as map(*)* {
   let $result as map(*)* := 
       for $member in $bos
           return lmutil:getIndirectLinksForBOSMember($member)
   return $result
};

(:~
 : Given a BOS member map for a topic, finds all key-based links in the 
 : topic and returns a sequence of link items for the links.
 :
 : @param member BOS member map containing a topic BOS member.
 : @return A sequence, possibly empty, of link items.
 :)
declare function lmutil:getIndirectLinksForBOSMember($member as map(*)) as map(*)* {
   let $topicref := $member('topicref')
   let $topic := $member('resource')
   let $contentDocURI := "contentdocURI value"
   let $linkElems := $topic//*[@keyref]
   let $linkItems := 
       for $elem in $linkElems
           return lmutil:constructLinkItemMap($elem, $contentDocURI, $topicref)
   return $linkItems
};

(:~
 : Given a map resolves all the topicrefs to their local-scope resources
 : and returns the set of "BOS members", where each member is a map 
 : with the topicref that pointed to the topic and the resolved topic.
 : The topicref is required in order to have the map context, which is required
 : in order to determine the key space within which any key references within the 
 : topic are resolved. Note that a BOS member is a unique topicref/resource pair.
 : If the same resource is referenced multiple times in the map there will be one BOS member
 : for each reference.
 : 
 : @param map Map to process. Does not resolve submap references, so if
 : you want the resources for a map tree supply the resolved map.
 :
 : @param formats A list of one or more @format values to return in the set.
 : The special value '#non-dita' matches any @format value that is not 'dita'
 : or 'dita-map'. Specify ('dita') to return only topic members of 
 : the BOS. Non-DITA resources are represented by the topicrefs that point to
 : them. If not specified, all local-scope resources are returned.
 : @return Sequence of maps, one for each topicref/resource pair
 :)
declare function lmutil:getMapBoundedObjectSet(
                            $map as element(), 
                            $formats as xs:string*) as map(*)* {
  let $topicrefs := $map//*[df:isTopicRef(.)]
                           [df:isLocalScope(.)]
                           [not($formats) or 
                            df:getEffectiveFormat(.) = $formats]
  let $members := 
      for $topicref in $topicrefs
          let $resource := if (df:getEffectiveFormat($topicref) = ('dita'))
             then lmutil:resolveTopicRefFromResolvedMap($topicref)
             else $topicref
          return map { 'topicref' : $topicref,
                       'resource' : $resource }
  return $members
      
};

(:~
 : Resolves a topicref from a resolved map. Uses the additional metadata
 : in the resolved map to determine the target document that contains
 : the element.
 :)
declare function lmutil:resolveTopicRefFromResolvedMap($topicref as element()) 
                                                                    as element()? {
  let $baseURI := string(($topicref/ancestor::*[@origMapURI]/@origMapURI)[1])                          
  let $targetURI := string($topicref/@href)
  let $resolvedURI := relpath:resolveURI($targetURI, $baseURI)
  let $result := try {
    let $doc as document-node()? := doc($resolvedURI)
    let $elem := if ($doc) then $doc/* else()
    return $elem
  } catch * {
    (: Document not found :)
    ()
  }
  return $result
};

(:~
 : Find maps that either have no local-scope topicrefs to them or that have
 : any peer-scope topicrefs to them.
 : 
 : @param dbName Name of the content database that holds the map to examine.
 : @return List, possibly empty, of root maps.
 :)
declare function lmutil:getRootMaps($dbName as xs:string) as element()* {
  let $candMaps := collection($dbName)/*[df:class(., 'map/map')]
  let $result := 
      for $candMap in $candMaps
          return if (lmutil:isRootMap($candMap))
                   then $candMap
                   else ()
  return $result             
};

(:~
 : Returns true if the specified map element is a root map.
 :
 : Note that there are many ways that root mapness could be determined.
 : The logic used here is any map that has no direct map local-scope references
 : or any peer-scope references. This is based on the presumption that a root
 : map would not normally be useable as local-scope submap. DITA 1.3's new 
 : meaning for scope="peer" on topicrefs to maps explicitly means "the referenced
 : map is a root map". 
 :
 : Other options would be to have a master map that uses peer map references to
 : explicitly identify root maps and use only that to determine rootness, to
 : maintain some sort of metadata that indicates rootness, use a specific map
 : specialization or map specialization plus descendant element configuration
 : (e.g., bookmaps that have booktitle elements are root maps, all others are 
 : not).
 : 
 : @param map Map to check for rootness
 : @return true() if the map is a root map.
 :) 
declare function lmutil:isRootMap($map as element()) as xs:boolean {
  let $resolvedMap as element()? := lmutil:getResolvedMapForMap($map)
  let $result :=
      if (not($resolvedMap)) (: If no resolved map, link management database hasn't 
                                been initialized and have to assume all maps are root:)
         then true()
         else ((lmutil:getRefCount($map, $lmutil:useMatchParamsLocalMaps) = 0) or
               (lmutil:getRefCount($map, $lmutil:useMatchParamsPeerMaps) > 0))
  return $result
};

(:~
 : Gets the number of references to the specified element that match the specified 
 : match criteria.
 : 
 : @param elem Element to get reference count for.
 : @param matcher Use record matcher to use for selecting references
 : @return Number of matches
 :)
declare function lmutil:getRefCount($elem as element(), 
                                    $matchParams as map(*)) as xs:integer {
  let $uses := lmutil:getUses($elem, $matchParams)
  let $result := count($uses) 
  return $result
};

(: Construct a string report of the listed attributes :)
declare function lmutil:reportAtts($elem as element(), $attNames) as xs:string {
   let $result := for $att in $elem/@*
                      return if (name($att) = $attNames)
                                then concat(name($att), '="', string($att), '"')
                                else ()
   return string-join($result, ' ')
};

(:~
 : Report a link item map as XML
 :
 : @param linkItem
 : @return XML representation of the link
 :)
declare function lmutil:reportLinkItemMap($linkItem as map(*)) as element() {
(:
 : 'link' : The element that is the link
 : 'rootMap' : The root map document that defines the namespace the link
 :             is resolved in.
 : 'resolvedMap' : The fully-resolved map that defines key space the key
 :                 reference is resolved in.
 : 'keySpace' : The constructed key space for the root map.
 :)
  <linkItem>{
     bxutil:reportMapAsXML($linkItem)
}</linkItem>
};

(:~
 : Get the resolved map document for a map. The resolved map must have already
 : been constructed (XQuery doesn't let use do updating actions wherever we
 : want).
 :
 : @param map Content map to get the resolved map for.
 : @return the resolved map or an empty sequence if there is no resolved map
 : (for example, because the map is not a root map).
 :)
declare function lmutil:getResolvedMapForMap($map as element()) as element()? {
  let $resolvedMapURI as xs:string := lmutil:getResolvedMapURIForMap($map)
  let $metadataDbName as xs:string := bxutil:getMetadataDbNameForDoc(root($map))
  
  let $resolvedMap := collection($metadataDbName || $resolvedMapURI)
  return $resolvedMap/*
};

(:~
 : Construct the database URI to use for a resolved map.
 :
 : @param map DITA map element to get the URI for
 : @returns The URI of the resolved map as a string
 :)
declare function lmutil:getResolvedMapURIForMap(
                        $map as element()) as xs:string {
  let $mapDocHash := replace(string(hash:md5(document-uri(root($map)))), '/', '~')
  return $dfstcnst:resolved-map-dir ||
         "/" || $mapDocHash || ".ditamap"
};

(:~
 : Given a keyspace element return the document URI to use when
 : storing or finding the key space.
 : 
 : @param keyspace Element that is the key space.
 : @return The URI for the key space document.
 :)
declare function lmutil:getKeySpaceURIForKeySpace(
                            $keySpace as element()) as xs:string {
  let $resolvedMapURI as xs:string? := string($keySpace/@resolvedMap)
  let $result := lmutil:getKeySpaceURIForResolvedMapURI($resolvedMapURI)
  return $result
};

(:~
 : Given the URI of a resolved map, construct the URI for the corresponding key space document
 :
 :)
declare function lmutil:getKeySpaceURIForResolvedMapURI($resolvedMapURI as xs:string) as xs:string {
  let $filenameBase := relpath:getNamePart($resolvedMapURI)
  let $uri :=
            let $parentDir := relpath:getParent($resolvedMapURI)
            return relpath:newFile($parentDir, 
               concat($filenameBase, '.keyspace'))
  return $uri
};


(: End of Module :)
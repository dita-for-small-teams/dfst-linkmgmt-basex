(: =====================================================

   DITA Utilities
   
   Provides XQuery functions for working with DITA documents,
   including resolving keys and key references, hrefs,
   getting topic navigation titles, etc.
   
   Author: W. Eliot Kimber
   
   Copyright (c) 2014, 2015 DITA For Small Teams
   Licensed under Apache License 2
   

   ===================================================== :)
   

module namespace df="http://dita-for-small-teams.org/xquery/modules/dita-utils";

import module namespace relpath="http://dita-for-small-teams.org/xquery/modules/relpath-utils";
import module namespace bxutil="http://dita-for-small-teams.org/xquery/modules/basex-utils";


(: Returns true if the specified element is of the specified DITA class.

   Handles the case of a failure to include the trailing space in the @class
   value (this was a bug in MarkLogic 3 in that it did not preserve trailing
   space in #CDATA attributes, corrected in MarkLogic 4).
   
   elem      - The element to test the class of.
   classSpec - A module/tagname pair, without spaces, e.g. "topic/p"
   
:)
declare function df:class($elem as element(), $classSpec as xs:string) as xs:boolean {
  (: Refinement from Bob Thomas :)
  let $result := matches($elem/@class, concat(' ', normalize-space($classSpec), ' |\$'))
  return $result
};

(: Gets the base class name of the context element, e.g. "topic/p" :)
 declare function df:getBaseClass($context as element()) as xs:string {
    (: @class value is always "- foo/bar fred/baz " or "+ foo/bar fred/baz " :)
    let $result as xs:string :=
      normalize-space(tokenize($context/@class, ' ')[2])
    return $result
};

declare function df:getHtmlClass($context as element()) as xs:string {
  let $result := if ($context/@outputclass)
                    then string($context/@outputclass)
                    else name($context)
  return $result
};



(: Gets the navigation title for a topic. If there is a navtitle title alternative,
   returns it, otherwise returns the topic's title.
   
 :)
declare function df:getNavtitleForTopic($topic as element()) as node()* {
   let $navtitle := if ($topic/*[df:class(., 'topic/titlealts')]/*[df:class(., 'topic/navtitle')])
                       then $topic/*[df:class(., 'topic/titlealts')]/*[df:class(., 'topic/navtitle')]/node()
                       else $topic/*[df:class(., 'topic/title')]/node()
   return $navtitle
};

(: Get all the DITA maps in the specified collection :)
declare function df:getMaps($collectionSpec as xs:string) as document-node()* {
  for $doc in collection($collectionSpec) where $doc[contains(/*/@class, ' map/map ')] 
      return $doc
};

(: Get all the DITA topic documents in the specified collection, that is,
 : documents whose root element is of type topic/topic or <dita>
 :)
declare function df:getTopicDocs($collectionSpec as xs:string) as document-node()* {
  for $doc in collection($collectionSpec) where $doc[contains(/*/@class, ' topic/topic ') or /*/self::dita] 
      return $doc
};

(: Get the title text for the specified element where the element is expected to have topic/title direct child  
   Simply returns the text nodes of the title, filtering out elements that don't normally show up in output 
   (<data>, <indexterm>, etc.)
:)
declare function df:getTitleText($elem as element()) as xs:string {
   let $title := df:getTitleElement($elem)
   (: FIXME: Implement the filtering, which needs to be a general function :)
   return string($title)
};

(: Get the title element for the specified element where the element is expected to have topic/title direct child :)
declare function df:getTitleElement($elem as element()) as element()? {
   ($elem/*[df:class(., 'topic/title')])[1]
};

(:~
 : Gets the effective value of the attribute, applying DITA-defined default
 : value rules when the attribute does not have a value.
 :
 :)
declare function df:getEffectiveAttributeValue($elem as element(), $attName as xs:string) as xs:string {
   let $att := $elem/@*[name(.) = $attName]
   return 
     if ($att)
        then string($att)
        else (: Determined the implicit default, if any :)
         switch ($attName) 
          case 'scope' return 'local'
          case 'format' return 'dita'
          default return ''
         
};

(:~
 : Resolve a topicref to its target topic or map element.
 :
 : Topicref must be a peer or local-scope topicref to a topic
 : or map. 
 :
 : Returns the reference element or a <df:error> element if there
 : was some error. 
 :
 : Returns empty sequence if the @scope is not
 : peer or local or @format is not dita or ditamap.
 :)
declare function df:resolveTopicRef($topicref as element()) as element()? {
   let $map as document-node() := root($topicref)
   let $format  as xs:string?  := df:getEffectiveAttributeValue($topicref, 'format')
   let $href  as xs:string?    := string($topicref/@href)
   let $keyref as xs:string?   := string($topicref/@keyref)
   let $scope as xs:string?    := df:getEffectiveAttributeValue($topicref, 'scope') 
   
   return if (not(df:class($topicref, 'map/topicref')))
      then <df:error type="not-topicref" xmlns:df="http://dita-for-small-teams.org/xquery/modules/dita-utils">resolveTopicRef(): Element {name($topicref)} is not of class 'map/topicref', class is "{string($topicref/@class)}"</df:error>
      else (: It's a topicref, check the @format value:)
        if (not($format = ('dita', 'ditamap')) or 
            ($scope != '' and (not($scope = ('local', 'peer')))))
           then <df:warn>Not format of 'dita' or 'ditamap' or not local or peer scope </df:warn>
           else 
             let $targetUri as xs:string := df:getEffectiveTargetUri($topicref)
             let $targetFragId as xs:string := 
                 if (contains($topicref/@href, '#')) 
                    then substring-after($topicref/@href, '#') 
                    else ''
             return if ($targetUri = '' and $targetFragId = '')
                then ()
                else df:resolveTopicOrMapUri($topicref, $targetUri)
                  
};

declare function df:resolveTopicOrMapUri($topicref as element(), $targetUri as xs:string) 
   as element()? {
   let $targetResourcePart as xs:string := 
     if (contains($targetUri, '#')) 
        then substring-before($targetUri, '#') 
        else $targetUri
   let $topicFragId as xs:string :=
     if (contains($targetUri, '#')) 
        then substring-after($targetUri, '#') 
        else ''
   let $targetDoc := 
      if ($targetResourcePart != '')
         then
           let $baseUri := base-uri($topicref)
           let $resolvedUri :=
               if (not(starts-with($baseUri, '/')))
                  then (: Handle BaseX way of managing document URLs :)
                     let $parentUri := relpath:getParent($baseUri)
                     return relpath:newFile($parentUri, $targetResourcePart)
                  else resolve-uri($targetResourcePart, $baseUri)           
           return doc($resolvedUri)
         else root($topicref)
   return 
     if ($targetDoc/*[df:class(., 'topic/topic') or df:class(., 'topic/topic')] )
        then $targetDoc/*[1]
        else if ($targetDoc/*/*[df:class(., 'topic/topic')])
          then $targetDoc/*/*[df:class(., 'topic/topic')][1]
          else $targetDoc/*
 };

(: Give a topicref, return the effective URI of the ultimate target
 : of the topicref.
 :)
declare function df:getEffectiveTargetUri($refElem as element()) as xs:string {
  df:getEffectiveTargetUri(root($refElem)/*, $refElem)
};

(: Give a topicref, return the effective URI of the ultimate target
 : of the topicref.
 :)
declare function df:getEffectiveTargetUri($rootMap, $refElem as element()) as xs:string {
   let $effectiveUri := 
       if ($refElem/@keyref != '')
          then df:getEffectiveUriForKeyref($rootMap, $refElem)
          else string($refElem/@href)
   let $baseUri := relpath:getResourcePartOfUri($effectiveUri)
   let $fragId := relpath:getFragmentId($effectiveUri)
   let $resultBase := 
      if (string($refElem/@copy-to) != '' and not(df:inChunk($refElem))) 
         then (: Copy-to in effect, not in a chunk :)
            let $copyTo as xs:string := $refElem/@copy-to        
            let $fullUri as xs:string := string(resolve-uri($copyTo, base-uri($refElem)))
            return relpath:getRelativePath(relpath:getParent(base-uri($refElem)), $fullUri)
         else $baseUri
   return $resultBase

};

(:~ 
 : Given an element with a @keyref attribute, returns
 : the URI of the ultimate resource bound to the referenced
 : key, as defined in the specified root map (note, the map
 : needs to be a resolved map).
 :)
declare function df:getEffectiveUriForKeyref($rootMap, $refElem) as xs:string? {
   let $keyref as xs:string := string($refElem/@keyref)
   let $keyname as xs:string := if (contains($keyref, '/'))
        then tokenize($keyref, '/')[1]
        else $keyref
   (: At this point, need to look up the key reference in the
      the appropriate key space.
      
    :)
   return "key resolution not yet implemented"
};

(: 
 : Returns true if the topicref element points to something and
 : has a @format value of 'ditamap'
 :
 :)
declare function df:isMapRef($topicref as element()) as xs:boolean {
  df:isTopicRef($topicref) and $topicref/@format = 'ditamap' 
};

declare function df:isTopicRef($topicref as element()) as xs:boolean {
  df:class($topicref, 'map/topicref') and
      (($topicref/@href and $topicref/@href != '') or
       ($topicref/@keyref and $topicref/@keyref != ''))
};

(:~
 : Gets the map tree rooted at the input map. The result tree
 : always includes the specified map.
 : 
 : Returns a single <mapTree> element containing tree items
 : for the complete map tree.
 :)
declare function df:getMapTree($map as document-node()) as element(mapTree)* {
  (: The map Uri is the object ID of the map tree, meaning every map tree
     is identified by the map from which it is constructed.
     
   :)
  <mapTree 
     mapUri="{document-uri($map)}"
     timeStamp="{fn:current-dateTime()}"
  >
    { df:getMapTreeItem($map/*) }
  </mapTree>
};

(:~
 : Gets the map tree item for the input map. The result tree
 : always includes the specified map.
 : 
 : Returns a single <treeItem> element representing the input map
 : and containing any subordinate maps.
 :)
declare function df:getMapTreeItem($mapElem as element()) as element(treeItem)* {
   let $label := if ($mapElem) then df:getTitleText($mapElem) 
                           else "Failed to resolve reference to map "
   return <treeItem>
            <label>{$label}</label>
            <properties>
              <property name="maptype">{name($mapElem)}</property>
              <property name="uri">{bxutil:getPathForDoc(root($mapElem))}</property>
            </properties>
            <children>
              {df:getMapTreeItems($mapElem)}
            </children>
          </treeItem>
};


(:~
 : Get the tree of maps descending from a root map
 : 
 : The result is returned a sequence of treeItem elements. 
 :)
declare function df:getMapTreeItems($map as element()) as element(treeItem)* {
   let $maprefs := $map//*[df:isMapRef(.)]
   for $mapref in $maprefs
       let $mapElem := df:resolveTopicRef($mapref)
       return df:getMapTreeItem($mapElem)
};

(:~
 : Returns true if the context topicref is within
 : the context of a topicref that generates a new content
 : chunk (e.g., chunk="to-content select-branch").
 :)
 declare function df:inChunk($context) as xs:boolean {
   let $nearestChunkSpecifier as element()? := $context/ancestor::*[@chunk != ''][1]
   let $chunkSpec as xs:string := $nearestChunkSpecifier/@chunk
   let $result := 
       contains($chunkSpec, 'to-content') and
              (contains($chunkSpec, 'select-branch') or
               contains($chunkSpec, 'select-document'))
   return $result
}; 

declare function df:getMapDocForTreeItem($treeItem as element(treeItem)) as document-node()? {
   let $mapUri := string($treeItem/properties/property[@name = 'uri'])
   let $map := doc($mapUri)
   return $map
};

(:~
 : Constructs the key spaces root at the specified map document.
 : 
 : Returns a single <keySpaceSet> element containing the key
 : spaces defined by the map.
 :)
declare function df:constructKeySpaces($map as document-node()) as element(keySpaceSet) {
  (: The map Uri is the object ID of the key space, meaning every key space
     is identified by the map from which it is constructed and the fully-qualified
     key scope.
     
   :)
   let $mapTree := df:getMapTree($map)
   let $keySpaces := df:constructKeySpacesForMapTree($mapTree) 
   let $keySpaceSet := <keySpaceSet 
       mapUri="{document-uri($map)}" 
       timeStamp="{current-dateTime()}">
       {
         df:serializeKeySpacesMap($keySpaces)
       }
   </keySpaceSet>
   return $keySpaceSet
};

declare function df:serializeKeySpacesMap($keySpaces) as element(keySpace)* {
  (: The key spaces map is a map of scope names to key spaces.
     Each key space is a map of key names to key bindings.
     :)

  for $keyScopeName in map:keys($keySpaces)
      let $keySpace := map:get($keySpaces, $keyScopeName)
      return <keySpace scopeName="{$keyScopeName}">{
        for $keyName in map:keys($keySpace)
            return df:serializeKeyBindings($keyName, map:get($keySpace, $keyName))
            }</keySpace>
};

declare function df:serializeKeyBindings($keyName as xs:string, $keyBindings) as element()* {
  (:
     A key bindings is a sequence of key definitions,
     where each key definition is a map of property names to values:
     - key name: the key name 
     - resource URI: The URI of the resource the key is bound to (if any)
     - key-definition element: the topicref element
         that is the data source for the key definition.
  :)
  <keyBindings keyName="{$keyName}">{
    for $keyBinding in $keyBindings
        return df:serializeKeyBinding($keyBinding)
  }</keyBindings>
};

declare function df:serializeKeyBinding($keyBinding) as element()* {
  <keyBinding><stuff/></keyBinding>
};

(:~
 : Constructs the key spaces for a map tree
 :
 : Returns a key space, one for the root (anonymous) key space,
 : one for each key scope defined in the map.
 :)
declare function df:constructKeySpacesForMapTree($mapTree as element(mapTree)) {
  (: Walk the map tree, using a breadth-first traveral per the DITA key space construction
     rules. Build up the key spaces from each map. There is a always a root key space anchored
     at the root map.
     
   :)
  let $rootMapItem := $mapTree/* (: The root map of the tree :)
  let $map := df:getMapDocForTreeItem($rootMapItem)
  let $keySpaceSet := df:constructKeySpacesForMap(
                     $map, 
                     map { }, 
                     ('#root'))
  return $keySpaceSet
};

(:~
 : Constructs the key spaces for a single map
 :
 : 
 :)
declare function df:constructKeySpacesForMap(
                    $map as document-node(), 
                    $keySpaceSet,
                    $keyScopes as xs:string+) {
                    
   (: Find the key-scope-defining elements and 
      the key definitions and construct or add to the
      cooresponding key space maps. 
      
      This might be easiest to do by simply walking 
      the map element tree and accumulating scope
      context.
      :)
   
   let $keySpaces :=
       for $keyScope in $keyScopes
           return 
           map { $keyScope : 
                 map { $map : 
                       map { 'key01' : 
                              (map { 'keyName' : 'key01',
                                     'topicref' : <topicref keys="key01"/>,
                                     'resourceURI' : ''
                                   },
                               map { 'keyName' : 'key01',
                                     'topicref' : <topicref keys="key01 keyxxx"/>,
                                     'resourceURI' : 'foo/bar'
                                   }
                               ),
                               'key02' :
                               (map { 'keyName' : 'key02',
                                 'topicref' : <topicref keys="key02"/>,
                                 'resourceURI' : 'docs/topics/topic-01.dita'
                               })}}}
                           
              
   
   return $keySpaces
};

(: ============== End of Module =================== :)   
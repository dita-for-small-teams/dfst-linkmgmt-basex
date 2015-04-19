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

declare namespace ditaarch="http://dita.oasis-open.org/architecture/2005/";

(:~
 : Regular expression that matches @class attribute values
 :)
declare variable $df:classAttPattern := '^[\-+]\s\w+/\w+\s.*';


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
declare function df:getMapTree($map as document-node()) as element(mapTree) {
  (: The map Uri is the object ID of the map tree, meaning every map tree
     is identified by the map from which it is constructed.
     
   :)
  <mapTree 
     mapUri="{document-uri($map)}"
     timeStamp="{fn:current-dateTime()}"
     database="{tokenize(document-uri($map), '/')[1]}"
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
              <property name="uri">{document-uri(root($mapElem))}</property>
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
   return document { <map/> }
   (:
   let $map := doc($mapUri)
   return $map
   :)
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
     Each key bindings is a sequence of key definitions for a given
     key name.
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
(: Each key binding is:
     - key name: the key name 
     - resource URI: The URI of the resource the key is bound to (if any)
     - key-definition element: the topicref element
         that is the data source for the key definition.
     - Note that for resources of format "dita" and "ditamap"
       the resource will be a topic or map respectively.
       All other formats are non-DITA resources.
:)
  <keyBinding 
    keyName="{map:get($keyBinding, 'keyName')}"
    resourceURI="{map:get($keyBinding, 'resourceURI')}"
    format="{map:get($keyBinding, 'format')}"
  >
    <topicref>{map:get($keyBinding, 'topicref')}</topicref>
  </keyBinding>
};

(:~
 : Constructs the key spaces for a map tree
 :
 : The key spaces are an ordered sequence of key spaces.
 :  
 : The identity of a key space is the element that defines it and
 : all of its ancestor key spaces. Because the same map could be
 : used multiple times by a parent map, the space-defining element
 : itself is insufficient to identify the key space. In addition,
 : direct-URI conrefs could also result in the same scope-defining
 : element being used multiple times in different parent scopes.
 :
 : Returns a sequence of key spaces, where each key space is a map
 : of key names to an ordered sequence of key definitions
 :)
declare function df:constructKeySpacesForMapTree($mapTree as element(mapTree)) {
  (: Walk the map tree, using a breadth-first traveral per the DITA key space construction
     rules. Build up the key spaces from each map. There is a always a root key space anchored
     at the root map.
     
   :)
  let $rootMapItem := $mapTree/* (: The root map of the tree :)
  let $mapDoc := df:getMapDocForTreeItem($rootMapItem)
  
  (: There is always an anonymous root key space, represented
     by the scope name "#root" in this implementation.
     
     Thus every map tree has at least one, possibly empty,
     key space.
     
     Any key space may be empty: declaring a key scope on any
     map or topicref establishes the space independent of there
     being any keys defined within the scope.
     
     Within a given parent key scope, the identity of each subscope is
     the element that declares the key scope name. Key scope names do
     not need to be unique within a given parent key space. In that case,
     normal key definition precedence rules apply when resolving keys
     in the context of the parent key scope:                                    
      
      <topicgroup keyscope="one">
        <keydef keys="a" id="s1a"/>
        <topicref keyref="a"/> <!-- s1a -->
        <topicref keyref="b"/> <!-- undefined -->
      </topicgroup>
      <topicgroup keyscope="one">
        <keydef keys="a" id="s2a"/>
        <keydef keys="b" id="s2b"/>
        <topicref keyref="a"/> <!-- s2a -->
        <topicref keyref="b"/> <!-- s2b -->
      </topicgroup>
      <topicref keyref="one.a"/> <!-- s1a -->
      <topicref keyref="one.b"/> <!-- s2b -->
     
     Per the DITA spec, scope names are separated by "." (period)
     to construct qualified scope names.
     
     Note also that a key name may itself contain "." characters:
     there is no syntactic distinction between a scope-qualified
     key name and a key name that happens to include a ".". This
     allows higher-level key spaces to override scope-qualified 
     keys from descendant key scopes.
     :)
     
  (: FIXME: actually walk the map tree :)   
  let $keySpaces := df:constructKeySpacesForMap(
                     $mapDoc, 
                     (map { df:getKeySpaceID(($mapDoc/*), ()) : map {} }))
  return $keySpaces
};

declare function df:getKeySpaceID($spaceDefiningElem as element(),
                                  $ancestorKeySpaces) as xs:string {
   map:serialize(map {$spaceDefiningElem : ()})
};

(:~
 : Constructs the key spaces for a single map
 :
 : Returns the updated map of scope names to key spaces.
 :)
declare function df:constructKeySpacesForMap(
                      $mapDoc as document-node(), (: Map document to get key scopes and definitions from :)
                      $keySpaces (: A map of scope-defining elements (map or topicref) to key spaces.
                      
                                    Each key space in turn contains any descendant key spaces, reflecting
                                    the scope hierarchy of the map tree.
                                   
                                    The initial key space map always includes key key scope "#root",
                                    the root anonymous key space.
                                    :)
                    ) {
    let $currentKeySpaces := 
        if (string($mapDoc/*/@keyscope) = '') 
           then $keySpaces
           else map:merge((map {},
                           for $scopeName in tokenize($mapDoc/*/@keyscope, ' ')
                              return map:entry($mapDoc/*, map {})))
    
    return $keySpaces
    
};

(:~
 : Constructs the key spaces for a topicref.
 : 
 : A topicref can define zero more key scopes and zero or more key names bound to the 
 : topicref's resource or subelements (or both).
 :
 : topicRef    : A topicref
 : keySpaces   : A map of key-defining elements to key spaces.
 : keyScopes   : List of names of the currently-active key scopes of which the topicrefs are members.
 :
 : Returns : An updated keySpaces map reflecting the new key spaces and key definitions. 
 :)
declare function df:constructKeySpacesForTopicref(
             $topicRef as element(),
             $keySpaces) {
             
   let $newScopeNames := tokenize($topicRef/@keyscope, ' ')
   let $keyNames := tokenize($topicRef/@keys, ' ')
   let $currentKeySpaces := 
       if ($newScopeNames)
          then map:merge((map {}, 
                         for $scopeName in $newScopeNames
                             return map:entry($topicRef, map {})))
          else $keySpaces
   (: If there are any key names, construct the key bindings for them:
   
      A key binding is the mapping between a key name and the key definition
      and resource addressed by the key definition (if any).
      
      The DITA spec says that each ancestor key space of a given key space includes
      scope-qualified copies of each descendant space's key definitions. This copying
      is done either literally or abstractly later when the key space is stored
      in a way that optmizes key resolution or when the key space set is serialized
      for presentation to humans.
      
      Note that the key definitions will be added to each active key scope.
      
      A key definition is a map of a key name to a set of key bindings.
   :)
   let $keyDefinitions := df:constructKeyDefinitionsForTopicref($topicRef)
   (: Add these key definitions to the current keyspaces: :)
   let $updatedKeySpaces := 
       map:merge(($currentKeySpaces,
                  $keyDefinitions))
                        
   
                 
   return map { 'foo' : 'bar' }
  
};

(:~
 : Constructs the key definitions defined by the topicref, if any. 
 : 
 : Returns a map of key names to key definition maps.
 :)
declare function df:constructKeyDefinitionsForTopicref($topicRef as element()) as element(keyDef)* {
   let $keyNames := tokenize($topicRef/@keys)
   let $keyDefinitions :=
         for $keyName in $keyNames
             return  <keyDef keyname="{$keyName}">{df:constructKeyBinding($topicRef, $keyName)}</keyDef>
       
   return $keyDefinitions
};

(:~
 : Takes a key space and adds key definitions to it
 :
 : Returns a new key space map reflecting the added key definitions.
 :)
declare function df:addKeyDefinitionsToKeySpace(
           $keyDefinitions, (: Sequence of key definition maps :)
           $keySpace (: Key space map to add the key definitions to :)
        ) {
        $keySpace
};

(:~
 : Constructs a single key-name-to-topicref-and-resource binding map.
 :
 : map {
 :        "topicref": db:open-pre("dfst^dfst-sample-project^develop",33),
 :        "keyName": "topic-01",
 :        "scope": "local",
 :        "format": "dita",
 :        "resourceURI": "topics/topic-01.xml",
 :        "resolutionStatus": "resolved",
 :        "targetResource": db:open-pre("dfst^dfst-sample-project^develop",134)
 :     }
 :
 :)
declare function df:constructKeyBinding($topicRef as element(), $keyName as xs:string) as element(keyBinding) {
  
  let $format := df:getEffectiveAttributeValue($topicRef, 'format') 
  let $scope := df:getEffectiveAttributeValue($topicRef, 'scope')
  let $resourceURI := string($topicRef/@href)
  let $targetResource := 
      if (not($topicRef/@keyref))
         then df:resolveTopicRef($topicRef)
         else ()
  let $resolutionStatus := 
      if ($topicRef/@keyref)
         then 'pending'
         else if ($targetResource)
                 then 'resolved'
                 else 'failed: URI not resolved'
   return <keyBinding keyName="{$keyName}"
                 topicref="{$topicRef}"
                 resourceURI="{$resourceURI}"
                 format="{$format}"
                 scope="{$scope}"
                 resolutionStatus="{$resolutionStatus}"/>
             
};
    
(:~
 : Returns true of the document appears to be a DITA document.
 :
 : A DITA document has a @ditaarch:DITAArchVersion attribute,
 : a @class attribute with what looks like a DITA class spec,
 : and a @domains attribute.
 :)
declare function df:isDitaDoc($doc as document-node()) as xs:boolean {
  let $ditaArchAtt := $doc/*/@ditaarch:DITAArchVersion
  let $classAtt := $doc/*/@class
  let $domainsAtt := $doc/*/@domains
  return 
    if (matches($ditaArchAtt, '[12]\.[0-9]') and
        matches($classAtt, $df:classAttPattern) and
        $domainsAtt) 
       then true()
       else false()
  
};

(:~
 : Evaluates the document and returns the degree of confidence that
 : it is a DITA document:
 :
 : - certainty : 100% certainty that the document is a DITA document. Has
 :               a DITA document type signature (@ditaarch:DITAArchVersion, @class, @domains)
 : - propbably : 80% certainty that the document is a DITA document. Two of 3 DITA indicators
 : - maybe     : 50% certainty: Could be a DITA document, could be something else. Some
                 DITA indicators or seems to be a DITA map or topic.
 : - notdita   : 95% certainty document is not a DITA document: no recognizable
 :               DITA-indicating features.
 :)
declare function df:ditaDocConfidence($doc as document-node()) as xs:string {
  let $ditaArchAtt := $doc/*/@ditaarch:DITAArchVersion
  let $classAtt := $doc/*/@class
  let $domainsAtt := $doc/*/@domains
  return 
     if ($ditaArchAtt and
         $classAtt and
         $domainsAtt) then 'certainty'
     else if (($domainsAtt or $ditaArchAtt) or
              (@class and matches(@class, $df:classAttPattern))) then 'probably'
     else if (name($doc/*) = ('topic', 'concept', 'task', 'reference', 'glossentry',
                              'learningConcept', 'troubleshooting', 'map', 'bookmap',
                              'learningGroup', 'learningObject', 'learningObjectMap',
                              'learningGroupMap', 'pubmap')) then 'probably'
    else if ($doc/*/title) then 'maybe'
    else 'notdita'
};

(: ============== End of Module =================== :)   
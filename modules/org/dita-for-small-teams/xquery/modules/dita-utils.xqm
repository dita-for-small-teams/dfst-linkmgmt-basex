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
   let $format  as xs:string?  := string($topicref/@format)
   let $href  as xs:string?    := string($topicref/@href)
   let $keyref as xs:string?   := string($topicref/@keyref)
   let $scope as xs:string?    := string($topicref/@scope) 
   
   return if (not(df:class($topicref, 'map/topicref')))
      then <df:error type="not-topicref" xmlns:df="http://dita-for-small-teams.org/xquery/modules/dita-utils">resolveTopicRef(): Element {name($topicref)} is not of class 'map/topicref', class is "{string($topicref/@class)}"</df:error>
      else (: It's a topicref, check the @format value:)
        if (not($format = ('dita', 'ditamap')) or 
            not($scope = ('local', 'peer')))
           then ()
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
          else ()
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
 : Get the tree of maps descending from a root map
 : 
 : The result is returned a sequence of treeItem elements. 
 :)
declare function df:getMapTreeItems($map as document-node()) as element(treeItem)* {
   let $maprefs := $map/*/*[df:isMapRef(.)]
   for $mapref in $maprefs
       let $mapElem := df:resolveTopicRef($mapref)
       let $label := if ($mapElem) then df:getTitleText($mapElem) 
                               else "Failed to resolve reference to map "
       return <treeItem>
                <label>{$label}</label>
                <properties>
                  <property name="maptype">{name($mapElem)}</property>
                  <property name="url">{bxutil:getPathForDoc(root($mapElem))}</property>
                </properties>
                <children>
                  {df:getMapTreeItems($mapElem)}
                </children>
              </treeItem>
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


(: ============== End of Module =================== :)   